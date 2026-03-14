import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const String _avatarHeroTag = 'profile-avatar';
  static const String _defaultAvatarUrl = 'https://i.pravatar.cc/400?img=12';

  final ImagePicker _imagePicker = ImagePicker();
  final bool _isEmailVerified = true;

  String? _avatarPath;

  ImageProvider<Object> _avatarImageProvider() {
    if (_avatarPath != null) {
      return FileImage(File(_avatarPath!));
    }
    return const NetworkImage(_defaultAvatarUrl);
  }

  Future<void> _showAvatarSourcePicker() async {
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
    try {
      final XFile? pickedImage = await _imagePicker.pickImage(
        source: source,
        imageQuality: 90,
        maxWidth: 1600,
      );

      if (!mounted || pickedImage == null) {
        return;
      }

      setState(() {
        _avatarPath = pickedImage.path;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

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
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
          child: Column(
            children: [
              Stack(
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
                        onTap: _showAvatarSourcePicker,
                        child: const SizedBox(
                          width: 40,
                          height: 40,
                          child: Icon(
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
              const SizedBox(height: 20),
              Text(
                'James Okello',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
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
                      icon: Icons.school,
                      label: 'University',
                      value: 'Makerere University',
                    ),
                    _buildDivider(),
                    _buildReadOnlyRow(
                      context,
                      icon: Icons.menu_book,
                      label: 'Program',
                      value: 'BSc Computer Science',
                    ),
                    _buildDivider(),
                    _buildReadOnlyRow(
                      context,
                      icon: Icons.calendar_month,
                      label: 'Academic Year',
                      value: 'Year 3 - Semester 2',
                    ),
                    _buildDivider(),
                    _buildReadOnlyRow(
                      context,
                      icon: Icons.mail,
                      label: 'Student Email',
                      value: 'james.okello@students.unibuzz.edu',
                      trailing: _buildVerificationBadge(
                        isVerified: _isEmailVerified,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
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
