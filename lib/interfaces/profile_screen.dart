import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:unibuzz/services/auth_service.dart';
import 'package:unibuzz/services/error_helper.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const String _avatarHeroTag = 'profile-avatar';
  static const String _defaultAvatarUrl = 'https://i.pravatar.cc/400?img=12';

  final ImagePicker _imagePicker = ImagePicker();

  bool _isLoadingProfile = true;
  bool _isUpdatingAvatar = false;
  String? _profileError;

  String? _avatarPath;
  String? _remoteAvatarUrl;

  bool _isEmailVerified = false;
  String _username = '@student';
  String _fullName = 'Student';
  String _universityName = 'Not set';
  String _program = 'Not set';
  String _academicYear = 'Not set';
  String _studentEmail = 'Not set';

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  String _exceptionText(Object error) {
    return error.toString().replaceFirst('Exception: ', '').trim();
  }

  bool _isHttpUrl(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null || uri.host.isEmpty) {
      return false;
    }
    return uri.scheme == 'http' || uri.scheme == 'https';
  }

  Map<String, String> _resolveCloudinaryConfig() {
    final cloudName = dotenv.env['CLOUDINARY_CLOUD_NAME'] ?? '';
    final uploadPreset = dotenv.env['CLOUDINARY_UPLOAD_PRESET'] ?? '';
    final apiKey = dotenv.env['CLOUDINARY_API_KEY'] ?? '';
    final apiSecret = dotenv.env['CLOUDINARY_API_SECRET'] ?? '';

    if (cloudName.isEmpty) {
      throw Exception(
        'Profile photo upload is not configured in this app build.',
      );
    }

    if (uploadPreset.isNotEmpty) {
      return <String, String>{
        'cloud_name': cloudName,
        'upload_preset': uploadPreset,
        'upload_mode': 'unsigned',
      };
    }

    if (apiKey.isNotEmpty && apiSecret.isNotEmpty) {
      return <String, String>{
        'cloud_name': cloudName,
        'api_key': apiKey,
        'api_secret': apiSecret,
        'upload_mode': 'signed',
      };
    }

    throw Exception(
      'Profile photo upload is not configured. Provide CLOUDINARY_UPLOAD_PRESET (unsigned) or CLOUDINARY_API_KEY/CLOUDINARY_API_SECRET (signed).',
    );
  }

  String _buildCloudinarySignature({
    required int timestamp,
    required String apiSecret,
  }) {
    final payload = 'timestamp=$timestamp$apiSecret';
    return sha1.convert(utf8.encode(payload)).toString();
  }

  Future<String> _uploadAvatarToCloudinary(String imagePath) async {
    final localFile = File(imagePath);
    if (!localFile.existsSync()) {
      throw Exception('Selected image file no longer exists.');
    }

    final config = _resolveCloudinaryConfig();
    final cloudName = config['cloud_name']!;
    final uploadMode = config['upload_mode'] ?? 'unsigned';
    final uploadPreset = config['upload_preset'];
    final apiKey = config['api_key'];
    final apiSecret = config['api_secret'];

    const int maxAttempts = 3;
    Object? lastError;

    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        final cloudinaryDio = Dio(
          BaseOptions(validateStatus: (_) => true),
        );
        final fields = <String, dynamic>{};

        if (uploadMode == 'unsigned') {
          if (uploadPreset == null || uploadPreset.isEmpty) {
            throw Exception('Missing Cloudinary upload preset.');
          }
          fields['upload_preset'] = uploadPreset;
        } else {
          if (apiKey == null || apiKey.isEmpty) {
            throw Exception('Missing Cloudinary API key.');
          }
          if (apiSecret == null || apiSecret.isEmpty) {
            throw Exception('Missing Cloudinary API secret.');
          }

          final timestamp =
              DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
          fields['timestamp'] = timestamp.toString();
          fields['api_key'] = apiKey;
          fields['signature'] = _buildCloudinarySignature(
            timestamp: timestamp,
            apiSecret: apiSecret,
          );
        }

        fields['file'] = await MultipartFile.fromFile(imagePath);
        final formData = FormData.fromMap(fields);

        final response = await cloudinaryDio.post<dynamic>(
          'https://api.cloudinary.com/v1_1/$cloudName/image/upload',
          data: formData,
        );

        final dynamic decoded = response.data;
        final int statusCode = response.statusCode ?? 0;

        if (statusCode < 200 || statusCode >= 300) {
          String? cloudinaryMessage;
          if (decoded is Map && decoded['error'] is Map) {
            final dynamic message = decoded['error']['message'];
            if (message != null && message.toString().trim().isNotEmpty) {
              cloudinaryMessage = message.toString().trim();
            }
          }

          final nonRetryable =
              statusCode >= 400 &&
              statusCode < 500 &&
              statusCode != 408 &&
              statusCode != 429;

          final message =
              cloudinaryMessage ??
              'Cloud upload failed with status $statusCode.';

          if (nonRetryable) {
            throw Exception(message);
          }

          throw Exception('$message Retrying...');
        }

        if (decoded is! Map) {
          throw Exception('Cloud upload did not return a valid payload.');
        }

        final secureUrl = (decoded['secure_url'] ?? decoded['url'])
            ?.toString()
            .trim();
        if (secureUrl == null || secureUrl.isEmpty || !_isHttpUrl(secureUrl)) {
          throw Exception(
            'Cloud upload succeeded but no valid media URL was returned.',
          );
        }

        return secureUrl;
      } catch (error) {
        lastError = error;
        if (attempt == maxAttempts) {
          break;
        }
        await Future.delayed(Duration(seconds: attempt));
      }
    }

    throw Exception(
      'Could not upload profile photo: ${_exceptionText(lastError ?? 'unknown error')}',
    );
  }

  String? _readNonEmptyString(dynamic value) {
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    if (value is num || value is bool) {
      final text = value.toString().trim();
      if (text.isNotEmpty) {
        return text;
      }
    }
    return null;
  }

  bool? _parseBool(dynamic value) {
    if (value is bool) {
      return value;
    }

    final normalized = value?.toString().trim().toLowerCase();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }

    if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
      return true;
    }

    if (normalized == 'false' || normalized == '0' || normalized == 'no') {
      return false;
    }

    return null;
  }

  String _normalizeHandle({String? username, String? email}) {
    var candidate = (username ?? '').trim();

    if (candidate.isEmpty && email != null && email.contains('@')) {
      candidate = email.split('@').first.trim();
    }

    if (candidate.isEmpty) {
      candidate = 'student';
    }

    return candidate.startsWith('@') ? candidate : '@$candidate';
  }

  String _deriveFullName({String? fullName, String? username, String? email}) {
    final direct = fullName?.trim() ?? '';
    if (direct.isNotEmpty) {
      return direct;
    }

    final cleanUsername = (username ?? '').replaceFirst('@', '').trim();
    if (cleanUsername.isNotEmpty) {
      return cleanUsername;
    }

    if (email != null && email.contains('@')) {
      final localPart = email.split('@').first.trim();
      if (localPart.isNotEmpty) {
        return localPart;
      }
    }

    return 'Student';
  }

  String _formatAcademicYear(dynamic yearOfStudy) {
    final int? year = yearOfStudy is int
        ? yearOfStudy
        : int.tryParse(yearOfStudy?.toString() ?? '');

    if (year == null || year <= 0) {
      return 'Not set';
    }

    switch (year) {
      case 1:
        return '1st Year';
      case 2:
        return '2nd Year';
      case 3:
        return '3rd Year';
      case 4:
        return '4th Year';
      case 5:
        return 'Graduate';
      default:
        return 'Year $year';
    }
  }

  Future<void> _loadProfile({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        _isLoadingProfile = true;
        _profileError = null;
      });
    } else {
      setState(() {
        _profileError = null;
      });
    }

    try {
      final profile = await AuthService.getCurrentUserProfile();

      if (!mounted) {
        return;
      }

      final username = _readNonEmptyString(profile['username']);
      final email = _readNonEmptyString(profile['email']);
      final fullName = _readNonEmptyString(profile['full_name']);
      final universityName = _readNonEmptyString(profile['university_name']);
      final course = _readNonEmptyString(profile['course']);
      final profilePhotoUrl = _readNonEmptyString(profile['profile_photo_url']);
      final yearOfStudy = profile['year_of_study'];
      final isEmailVerified = _parseBool(profile['is_email_verified']) ?? false;

      setState(() {
        _username = _normalizeHandle(username: username, email: email);
        _fullName = _deriveFullName(
          fullName: fullName,
          username: username,
          email: email,
        );
        _universityName = universityName ?? 'Not set';
        _program = course ?? 'Not set';
        _academicYear = _formatAcademicYear(yearOfStudy);
        _studentEmail = email ?? 'Not set';
        _avatarPath = null;
        _remoteAvatarUrl = profilePhotoUrl;
        _isEmailVerified = isEmailVerified;
        _isLoadingProfile = false;
        _profileError = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoadingProfile = false;
        _profileError = friendlyError(error);
      });
    }
  }

  ImageProvider<Object> _avatarImageProvider() {
    if (_avatarPath != null) {
      return FileImage(File(_avatarPath!));
    }

    final remoteUrl = _remoteAvatarUrl;
    if (remoteUrl != null && remoteUrl.isNotEmpty) {
      return NetworkImage(remoteUrl);
    }

    return const NetworkImage(_defaultAvatarUrl);
  }

  Future<void> _showAvatarSourcePicker() async {
    if (_isUpdatingAvatar) {
      return;
    }

    final ImageSource? source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext bottomSheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(
                    Icons.photo_library,
                    color: Color(0xFF00B4D8),
                  ),
                  title: const Text(
                    'Choose from Gallery',
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () =>
                      Navigator.of(bottomSheetContext).pop(ImageSource.gallery),
                ),
                ListTile(
                  leading: const Icon(
                    Icons.photo_camera,
                    color: Color(0xFF00B4D8),
                  ),
                  title: const Text(
                    'Take a Photo',
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () =>
                      Navigator.of(bottomSheetContext).pop(ImageSource.camera),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (source == null) {
      return;
    }

    await _pickAvatar(source);
  }

  Future<void> _pickAvatar(ImageSource source) async {
    if (_isUpdatingAvatar) {
      return;
    }

    try {
      final XFile? pickedImage = await _imagePicker.pickImage(
        source: source,
        imageQuality: 90,
        maxWidth: 1600,
      );

      if (!mounted || pickedImage == null) {
        return;
      }

      final previousRemoteUrl = _remoteAvatarUrl;
      final previousAvatarPath = _avatarPath;

      setState(() {
        _avatarPath = pickedImage.path;
        _isUpdatingAvatar = true;
        _profileError = null;
      });

      try {
        final uploadedUrl = await _uploadAvatarToCloudinary(pickedImage.path);
        final updatedProfile = await AuthService.updateCurrentUserProfile(
          profilePhotoUrl: uploadedUrl,
        );

        if (!mounted) {
          return;
        }

        final persistedUrl =
            _readNonEmptyString(updatedProfile['profile_photo_url']) ??
            uploadedUrl;

        setState(() {
          _remoteAvatarUrl = persistedUrl;
          _avatarPath = null;
          _isUpdatingAvatar = false;
        });

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Profile photo updated.')));
      } catch (error) {
        if (!mounted) {
          return;
        }

        setState(() {
          _remoteAvatarUrl = previousRemoteUrl;
          _avatarPath = previousAvatarPath;
          _isUpdatingAvatar = false;
        });

        final message = friendlyError(error);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isUpdatingAvatar = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not update profile photo. Please try again.'),
        ),
      );
    }
  }

  void _openAvatarLightbox() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => _AvatarLightboxScreen(
          heroTag: _avatarHeroTag,
          imageProvider: _avatarImageProvider(),
        ),
      ),
    );
  }

  Widget _buildErrorBanner() {
    final message = _profileError;
    if (message == null || message.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF2B1717),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFF4D4D), width: 0.8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(
              Icons.error_outline,
              color: Color(0xFFFF4D4D),
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Color(0xFFFFC2C2), fontSize: 12),
            ),
          ),
          TextButton(
            onPressed: _loadProfile,
            child: const Text(
              'Retry',
              style: TextStyle(color: Color(0xFF00B4D8)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileContent() {
    return RefreshIndicator(
      onRefresh: () async {
        if (_isUpdatingAvatar) {
          return;
        }
        await _loadProfile(showLoading: false);
      },
      color: const Color(0xFF00B4D8),
      backgroundColor: const Color(0xFF1A1A1A),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
        children: [
          _buildErrorBanner(),
          Center(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                GestureDetector(
                  onTap: _openAvatarLightbox,
                  child: Container(
                    width: 138,
                    height: 138,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF00B4D8),
                        width: 3,
                      ),
                    ),
                    child: Hero(
                      tag: _avatarHeroTag,
                      child: ClipOval(
                        child: Image(
                          image: _avatarImageProvider(),
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) {
                            return const DecoratedBox(
                              decoration: BoxDecoration(
                                color: Color(0xFF151515),
                              ),
                              child: Center(
                                child: Icon(
                                  Icons.person,
                                  size: 64,
                                  color: Color(0xFF00B4D8),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: -4,
                  bottom: -2,
                  child: Material(
                    color: const Color(0xFF00B4D8),
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: _isUpdatingAvatar ? null : _showAvatarSourcePicker,
                      child: SizedBox(
                        width: 40,
                        height: 40,
                        child: _isUpdatingAvatar
                            ? const Padding(
                                padding: EdgeInsets.all(10),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.edit,
                                color: Colors.white,
                                size: 20,
                              ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            _username,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (_isUpdatingAvatar)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                'Saving profile photo...',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: const Color(0xFF8FC6D3)),
              ),
            ),
          const SizedBox(height: 28),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                _buildReadOnlyRow(
                  context,
                  icon: Icons.person,
                  label: 'Full Name',
                  value: _fullName,
                ),
                _buildDivider(),
                _buildReadOnlyRow(
                  context,
                  icon: Icons.school,
                  label: 'University',
                  value: _universityName,
                ),
                _buildDivider(),
                _buildReadOnlyRow(
                  context,
                  icon: Icons.menu_book,
                  label: 'Program',
                  value: _program,
                ),
                _buildDivider(),
                _buildReadOnlyRow(
                  context,
                  icon: Icons.calendar_month,
                  label: 'Academic Year',
                  value: _academicYear,
                ),
                _buildDivider(),
                _buildReadOnlyRow(
                  context,
                  icon: Icons.mail,
                  label: 'Student Email',
                  value: _studentEmail,
                  trailing: _buildVerificationBadge(
                    isVerified: _isEmailVerified,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B0B0B),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Profile',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: (_isLoadingProfile || _isUpdatingAvatar)
                ? null
                : _loadProfile,
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoadingProfile
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF00B4D8)),
              )
            : _buildProfileContent(),
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(
      color: Colors.white.withValues(alpha: 0.09),
      height: 1,
      indent: 16,
      endIndent: 16,
    );
  }

  Widget _buildVerificationBadge({required bool isVerified}) {
    if (isVerified) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF00B4D8).withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: const Color(0xFF00B4D8).withValues(alpha: 0.6),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.check_circle, size: 13, color: Color(0xFF00B4D8)),
            SizedBox(width: 4),
            Text(
              'Verified',
              style: TextStyle(
                color: Color(0xFF00B4D8),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return const Icon(
      Icons.check_circle_outline,
      color: Color(0xFF767676),
      size: 18,
    );
  }

  Widget _buildReadOnlyRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    Widget? trailing,
  }) {
    return InkWell(
      onTap: () => FocusScope.of(context).unfocus(),
      borderRadius: BorderRadius.circular(14),
      splashColor: Colors.white.withValues(alpha: 0.06),
      highlightColor: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(icon, color: const Color(0xFF00B4D8), size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: const Color(0xFFB8B8B8),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 10),
              Padding(padding: const EdgeInsets.only(top: 22), child: trailing),
            ],
          ],
        ),
      ),
    );
  }
}

class _AvatarLightboxScreen extends StatelessWidget {
  const _AvatarLightboxScreen({
    required this.heroTag,
    required this.imageProvider,
  });

  final String heroTag;
  final ImageProvider<Object> imageProvider;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Center(
        child: Hero(
          tag: heroTag,
          child: InteractiveViewer(
            minScale: 1,
            maxScale: 4,
            child: Image(
              image: imageProvider,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) {
                return const SizedBox(
                  width: 220,
                  height: 220,
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: Color(0xFF151515)),
                    child: Center(
                      child: Icon(
                        Icons.person,
                        size: 80,
                        color: Color(0xFF00B4D8),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
