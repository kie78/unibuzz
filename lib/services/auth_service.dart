// If you see an error for flutter_secure_storage, add it to pubspec.yaml:
// dependencies:
//   flutter_secure_storage: ^9.0.0
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class AuthService {
  static const String _defaultBaseUrl = 'https://unibuzz-api.onrender.com';
  static final FlutterSecureStorage _storage = FlutterSecureStorage();
  static http.Client _httpClient = http.Client();
  static String? _baseUrlForTesting;
  static const Duration _startupExpirySkew = Duration(seconds: 30);
  static const String _profileFullNameKey = 'profile_full_name';
  static const String _profileUsernameKey = 'profile_username';
  static const String _profileEmailKey = 'profile_email';
  static const String _profileUniversityNameKey = 'profile_university_name';
  static const String _profileCourseKey = 'profile_course';
  static const String _profileYearOfStudyKey = 'profile_year_of_study';
  static const String _profilePhotoUrlKey = 'profile_photo_url';
  static const String _profileEmailVerifiedKey = 'profile_is_email_verified';
  static const String _profileUserIdKey = 'profile_user_id';
  static const List<String> _profileCacheKeys = <String>[
    _profileFullNameKey,
    _profileUsernameKey,
    _profileEmailKey,
    _profileUniversityNameKey,
    _profileCourseKey,
    _profileYearOfStudyKey,
    _profilePhotoUrlKey,
    _profileEmailVerifiedKey,
    _profileUserIdKey,
  ];

  static String get _baseUrl => _baseUrlForTesting ?? _defaultBaseUrl;

  static Exception _mapTransportException(Object error) {
    final text = error.toString().toLowerCase();

    if (text.contains('failed host lookup') ||
        text.contains('no address associated with hostname') ||
        text.contains('name or service not known')) {
      return Exception(
        'Unable to reach UniBuzz servers. Check your internet connection and DNS, then try again.',
      );
    }

    if (text.contains('timed out') || text.contains('timeout')) {
      return Exception('Request timed out. Please try again.');
    }

    if (text.contains('connection refused') ||
        text.contains('network is unreachable')) {
      return Exception('Network unavailable. Please check your connection.');
    }

    return Exception('Network request failed. Please try again.');
  }

  static Future<http.Response> _safePost(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    try {
      return await _httpClient.post(uri, headers: headers, body: body);
    } on SocketException catch (error) {
      throw _mapTransportException(error);
    } on http.ClientException catch (error) {
      throw _mapTransportException(error);
    }
  }

  @visibleForTesting
  static void configureForTesting({http.Client? httpClient, String? baseUrl}) {
    if (httpClient != null) {
      _httpClient = httpClient;
    }
    _baseUrlForTesting = baseUrl;
  }

  @visibleForTesting
  static void resetForTesting() {
    _httpClient = http.Client();
    _baseUrlForTesting = null;
  }

  static dynamic _decodeBody(String body) {
    if (body.isEmpty) return <String, dynamic>{};
    try {
      return jsonDecode(body);
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  static String _normalizeToken(String rawToken) {
    String token = rawToken.trim();
    if (token.toLowerCase().startsWith('bearer ')) {
      token = token.substring(7).trim();
    }
    if (token.length >= 2 && token.startsWith('"') && token.endsWith('"')) {
      token = token.substring(1, token.length - 1).trim();
    }
    return token;
  }

  static Map<String, dynamic>? _decodeJwtPayload(String token) {
    final parts = token.split('.');
    if (parts.length < 2) return null;

    try {
      final payload = utf8.decode(
        base64Url.decode(base64Url.normalize(parts[1])),
      );
      final decoded = jsonDecode(payload);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {
      return null;
    }

    return null;
  }

  static int? _parseEpochSeconds(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  static bool _isTokenExpired(
    Map<String, dynamic> payload, {
    Duration skew = _startupExpirySkew,
  }) {
    final expSeconds = _parseEpochSeconds(payload['exp']);
    if (expSeconds == null) {
      // Some environments may issue tokens without exp; treat as valid.
      return false;
    }

    final expiresAtUtc = DateTime.fromMillisecondsSinceEpoch(
      expSeconds * 1000,
      isUtc: true,
    );
    final nowUtcWithSkew = DateTime.now().toUtc().add(skew);
    return !nowUtcWithSkew.isBefore(expiresAtUtc);
  }

  static Future<bool> hasValidAccessToken() async {
    final rawToken = await getAccessToken();
    if (rawToken == null || rawToken.trim().isEmpty) {
      return false;
    }

    final token = _normalizeToken(rawToken);
    if (token.isEmpty || !token.contains('.')) {
      await logout();
      return false;
    }

    final payload = _decodeJwtPayload(token);
    if (payload == null || _isTokenExpired(payload)) {
      await logout();
      return false;
    }

    return true;
  }

  static Future<String?> getCurrentUserId() async {
    final rawToken = await getAccessToken();
    if (rawToken == null || rawToken.trim().isEmpty) {
      return null;
    }

    final token = _normalizeToken(rawToken);
    if (token.isEmpty) {
      return null;
    }

    final payload = _decodeJwtPayload(token);
    if (payload == null) {
      return null;
    }

    final dynamic userId =
        payload['user_id'] ?? payload['sub'] ?? payload['id'];
    final value = userId?.toString().trim();
    if (value == null || value.isEmpty) {
      return null;
    }
    return value;
  }

  static Future<void> _writeOrDeleteProfileField(
    String key,
    String? value,
  ) async {
    final normalized = value?.trim() ?? '';
    if (normalized.isEmpty) {
      await _storage.delete(key: key);
      return;
    }

    await _storage.write(key: key, value: normalized);
  }

  static Future<void> _clearProfileCache() async {
    for (final key in _profileCacheKeys) {
      await _storage.delete(key: key);
    }
  }

  static Future<Map<String, dynamic>> _readProfileCache() async {
    final fullName = await _storage.read(key: _profileFullNameKey);
    final username = await _storage.read(key: _profileUsernameKey);
    final email = await _storage.read(key: _profileEmailKey);
    final universityName = await _storage.read(key: _profileUniversityNameKey);
    final course = await _storage.read(key: _profileCourseKey);
    final yearRaw = await _storage.read(key: _profileYearOfStudyKey);
    final profilePhotoUrl = await _storage.read(key: _profilePhotoUrlKey);
    final emailVerifiedRaw = await _storage.read(key: _profileEmailVerifiedKey);
    final userId = await _storage.read(key: _profileUserIdKey);

    final profile = <String, dynamic>{};

    if (fullName != null && fullName.trim().isNotEmpty) {
      profile['full_name'] = fullName.trim();
    }
    if (username != null && username.trim().isNotEmpty) {
      profile['username'] = username.trim();
    }
    if (email != null && email.trim().isNotEmpty) {
      profile['email'] = email.trim();
    }
    if (universityName != null && universityName.trim().isNotEmpty) {
      profile['university_name'] = universityName.trim();
    }
    if (course != null && course.trim().isNotEmpty) {
      profile['course'] = course.trim();
    }
    if (profilePhotoUrl != null && profilePhotoUrl.trim().isNotEmpty) {
      profile['profile_photo_url'] = profilePhotoUrl.trim();
    }
    if (userId != null && userId.trim().isNotEmpty) {
      profile['user_id'] = userId.trim();
    }

    final yearOfStudy = int.tryParse(yearRaw?.trim() ?? '');
    if (yearOfStudy != null) {
      profile['year_of_study'] = yearOfStudy;
    }

    final isEmailVerified = _parseBool(emailVerifiedRaw);
    if (isEmailVerified != null) {
      profile['is_email_verified'] = isEmailVerified;
    }

    return profile;
  }

  static Future<void> cacheProfileSnapshot(Map<String, dynamic> profile) async {
    final normalized = _normalizeProfilePayload(
      Map<dynamic, dynamic>.from(profile),
    );

    if (normalized.isEmpty) {
      return;
    }

    await _writeOrDeleteProfileField(
      _profileFullNameKey,
      normalized['full_name']?.toString(),
    );
    await _writeOrDeleteProfileField(
      _profileUsernameKey,
      normalized['username']?.toString(),
    );
    await _writeOrDeleteProfileField(
      _profileEmailKey,
      normalized['email']?.toString(),
    );
    await _writeOrDeleteProfileField(
      _profileUniversityNameKey,
      normalized['university_name']?.toString(),
    );
    await _writeOrDeleteProfileField(
      _profileCourseKey,
      normalized['course']?.toString(),
    );
    await _writeOrDeleteProfileField(
      _profilePhotoUrlKey,
      normalized['profile_photo_url']?.toString(),
    );
    await _writeOrDeleteProfileField(
      _profileUserIdKey,
      normalized['user_id']?.toString(),
    );

    final yearRaw = normalized['year_of_study'];
    final yearOfStudy = yearRaw is int
        ? yearRaw
        : int.tryParse(yearRaw?.toString() ?? '');
    await _writeOrDeleteProfileField(
      _profileYearOfStudyKey,
      yearOfStudy?.toString(),
    );

    final isEmailVerified = _parseBool(normalized['is_email_verified']);
    await _writeOrDeleteProfileField(
      _profileEmailVerifiedKey,
      isEmailVerified?.toString(),
    );
  }

  static dynamic _readValueForPath(Map<dynamic, dynamic> source, String path) {
    final segments = path.split('.');
    dynamic current = source;

    for (final segment in segments) {
      if (current is Map<String, dynamic>) {
        current = current[segment];
      } else if (current is Map) {
        current = current[segment];
      } else {
        return null;
      }
    }

    return current;
  }

  static String? _readFirstString(
    Map<dynamic, dynamic> source,
    List<String> paths,
  ) {
    for (final path in paths) {
      final value = _readValueForPath(source, path);
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
      if (value is num || value is bool) {
        final text = value.toString().trim();
        if (text.isNotEmpty) {
          return text;
        }
      }
    }
    return null;
  }

  static int? _readFirstInt(Map<dynamic, dynamic> source, List<String> paths) {
    for (final path in paths) {
      final value = _readValueForPath(source, path);
      if (value is int) {
        return value;
      }
      if (value is num) {
        return value.toInt();
      }
      final parsed = int.tryParse(value?.toString() ?? '');
      if (parsed != null) {
        return parsed;
      }
    }
    return null;
  }

  static bool? _parseBool(dynamic value) {
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

  static bool? _readFirstBool(
    Map<dynamic, dynamic> source,
    List<String> paths,
  ) {
    for (final path in paths) {
      final parsed = _parseBool(_readValueForPath(source, path));
      if (parsed != null) {
        return parsed;
      }
    }
    return null;
  }

  static Map<String, dynamic> _normalizeProfilePayload(
    Map<dynamic, dynamic> source, {
    Map<String, dynamic>? fallback,
  }) {
    final normalized = <String, dynamic>{if (fallback != null) ...fallback};

    final candidates = <Map<dynamic, dynamic>>[source];

    final dynamic data = source['data'];
    if (data is Map) {
      candidates.add(Map<dynamic, dynamic>.from(data));
    }

    final dynamic user = source['user'];
    if (user is Map) {
      candidates.add(Map<dynamic, dynamic>.from(user));
    }

    final dynamic profile = source['profile'];
    if (profile is Map) {
      candidates.add(Map<dynamic, dynamic>.from(profile));
    }

    final dynamic result = source['result'];
    if (result is Map) {
      candidates.add(Map<dynamic, dynamic>.from(result));
    }

    String? pickString(List<String> paths) {
      for (final candidate in candidates) {
        final value = _readFirstString(candidate, paths);
        if (value != null && value.isNotEmpty) {
          return value;
        }
      }
      return null;
    }

    int? pickInt(List<String> paths) {
      for (final candidate in candidates) {
        final value = _readFirstInt(candidate, paths);
        if (value != null) {
          return value;
        }
      }
      return null;
    }

    bool? pickBool(List<String> paths) {
      for (final candidate in candidates) {
        final value = _readFirstBool(candidate, paths);
        if (value != null) {
          return value;
        }
      }
      return null;
    }

    final fullName = pickString(<String>[
      'full_name',
      'name',
      'user.full_name',
      'profile.full_name',
    ]);
    final username = pickString(<String>[
      'username',
      'user_name',
      'handle',
      'user.username',
      'profile.username',
      'preferred_username',
    ]);
    final email = pickString(<String>['email', 'user.email', 'profile.email']);
    final universityName = pickString(<String>[
      'university_name',
      'university',
      'campus',
      'user.university_name',
      'profile.university_name',
    ]);
    final course = pickString(<String>[
      'course',
      'program',
      'major',
      'user.course',
      'profile.course',
    ]);
    final profilePhotoUrl = pickString(<String>[
      'profile_photo_url',
      'avatar_url',
      'photo_url',
      'image_url',
      'user.profile_photo_url',
      'profile.photo_url',
    ]);
    final yearOfStudy = pickInt(<String>[
      'year_of_study',
      'year',
      'yearOfStudy',
      'user.year_of_study',
      'profile.year_of_study',
    ]);
    final isEmailVerified = pickBool(<String>[
      'is_email_verified',
      'email_verified',
      'verified_email',
      'is_verified',
      'user.is_email_verified',
      'profile.is_email_verified',
    ]);
    final userId = pickString(<String>[
      'user_id',
      'id',
      'sub',
      'user.id',
      'profile.id',
    ]);

    if (fullName != null) {
      normalized['full_name'] = fullName;
    }
    if (username != null) {
      normalized['username'] = username;
    }
    if (email != null) {
      normalized['email'] = email;
    }
    if (universityName != null) {
      normalized['university_name'] = universityName;
    }
    if (course != null) {
      normalized['course'] = course;
    }
    if (profilePhotoUrl != null) {
      normalized['profile_photo_url'] = profilePhotoUrl;
    }
    if (yearOfStudy != null) {
      normalized['year_of_study'] = yearOfStudy;
    }
    if (isEmailVerified != null) {
      normalized['is_email_verified'] = isEmailVerified;
    }
    if (userId != null) {
      normalized['user_id'] = userId;
    }

    return normalized;
  }

  static Future<Map<String, dynamic>> getCurrentUserProfile() async {
    final rawToken = await getAccessToken();
    if (rawToken == null || rawToken.trim().isEmpty) {
      throw Exception('Session expired. Please log in again.');
    }

    final token = _normalizeToken(rawToken);
    if (token.isEmpty || !token.contains('.')) {
      await logout();
      throw Exception('Session expired. Please log in again.');
    }

    final cachedProfile = await _readProfileCache();
    final claims = _decodeJwtPayload(token) ?? <String, dynamic>{};
    final profileFromClaims = _normalizeProfilePayload(
      claims,
      fallback: cachedProfile,
    );

    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };

    const endpointCandidates = <String>[
      '/api/me',
      '/auth/me',
      '/api/users/me',
      '/api/profile',
      '/profile/me',
    ];

    String? lastErrorMessage;

    for (final endpoint in endpointCandidates) {
      try {
        final response = await _httpClient.get(
          Uri.parse('$_baseUrl$endpoint'),
          headers: headers,
        );

        final decoded = _decodeBody(response.body);

        if (response.statusCode >= 200 && response.statusCode < 300) {
          if (decoded is Map) {
            final normalized = _normalizeProfilePayload(
              Map<dynamic, dynamic>.from(decoded),
              fallback: profileFromClaims,
            );
            await cacheProfileSnapshot(normalized);
            return normalized;
          }
          if (profileFromClaims.isNotEmpty) {
            return profileFromClaims;
          }
          throw Exception('Profile response was empty.');
        }

        if (response.statusCode == 401) {
          await logout();
          throw Exception('Session expired. Please log in again.');
        }

        if (response.statusCode == 404 || response.statusCode == 405) {
          continue;
        }

        if (decoded is Map<String, dynamic>) {
          final message =
              decoded['message'] ?? decoded['error'] ?? decoded['detail'];
          if (message != null && message.toString().trim().isNotEmpty) {
            lastErrorMessage = message.toString().trim();
          }
        }
        break;
      } catch (error) {
        lastErrorMessage = error
            .toString()
            .replaceFirst('Exception: ', '')
            .trim();
        break;
      }
    }

    if (profileFromClaims.isNotEmpty) {
      return profileFromClaims;
    }

    throw Exception(lastErrorMessage ?? 'Unable to load profile.');
  }

  static Future<Map<String, dynamic>> updateCurrentUserProfile({
    String? fullName,
    String? username,
    String? universityName,
    String? course,
    int? yearOfStudy,
    String? profilePhotoUrl,
  }) async {
    final rawToken = await getAccessToken();
    if (rawToken == null || rawToken.trim().isEmpty) {
      throw Exception('Session expired. Please log in again.');
    }

    final token = _normalizeToken(rawToken);
    if (token.isEmpty || !token.contains('.')) {
      await logout();
      throw Exception('Session expired. Please log in again.');
    }

    final payload = <String, dynamic>{
      if (fullName != null && fullName.trim().isNotEmpty)
        'full_name': fullName.trim(),
      if (username != null && username.trim().isNotEmpty)
        'username': username.trim(),
      if (universityName != null && universityName.trim().isNotEmpty)
        'university_name': universityName.trim(),
      if (course != null && course.trim().isNotEmpty) 'course': course.trim(),
      if (yearOfStudy != null && yearOfStudy > 0) 'year_of_study': yearOfStudy,
      if (profilePhotoUrl != null && profilePhotoUrl.trim().isNotEmpty)
        'profile_photo_url': profilePhotoUrl.trim(),
    };

    if (payload.isEmpty) {
      throw Exception('No profile fields were provided for update.');
    }

    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };

    const endpointCandidates = <String>[
      '/api/me',
      '/auth/me',
      '/api/users/me',
      '/api/profile',
      '/profile/me',
    ];

    String? lastErrorMessage;

    for (final endpoint in endpointCandidates) {
      try {
        final response = await _httpClient.patch(
          Uri.parse('$_baseUrl$endpoint'),
          headers: headers,
          body: jsonEncode(payload),
        );

        final decoded = _decodeBody(response.body);

        if (response.statusCode >= 200 && response.statusCode < 300) {
          final existingProfile = await _readProfileCache();
          final mergedFallback = <String, dynamic>{
            ...existingProfile,
            ...payload,
          };

          final normalized = decoded is Map
              ? _normalizeProfilePayload(
                  Map<dynamic, dynamic>.from(decoded),
                  fallback: mergedFallback,
                )
              : mergedFallback;

          await cacheProfileSnapshot(normalized);
          return normalized;
        }

        if (response.statusCode == 401) {
          await logout();
          throw Exception('Session expired. Please log in again.');
        }

        if (response.statusCode == 404 || response.statusCode == 405) {
          continue;
        }

        if (decoded is Map<String, dynamic>) {
          final message =
              decoded['message'] ?? decoded['error'] ?? decoded['detail'];
          if (message != null && message.toString().trim().isNotEmpty) {
            lastErrorMessage = message.toString().trim();
          }
        }
        break;
      } catch (error) {
        lastErrorMessage = error
            .toString()
            .replaceFirst('Exception: ', '')
            .trim();
        break;
      }
    }

    throw Exception(lastErrorMessage ?? 'Unable to update profile.');
  }

  static Future<Map<String, dynamic>> register({
    required String fullName,
    required String username,
    required String email,
    required String password,
    required String universityName,
    required String course,
    required int yearOfStudy,
  }) async {
    final response = await _safePost(
      Uri.parse('$_baseUrl/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'full_name': fullName,
        'username': username,
        'email': email,
        'password': password,
        'university_name': universityName,
        'course': course,
        'year_of_study': yearOfStudy,
      }),
    );
    final data = _processResponse(response);

    final submittedProfile = <String, dynamic>{
      'full_name': fullName,
      'username': username,
      'email': email,
      'university_name': universityName,
      'course': course,
      'year_of_study': yearOfStudy,
      ...data,
    };
    await cacheProfileSnapshot(submittedProfile);

    return data;
  }

  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final response = await _safePost(
      Uri.parse('$_baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    final data = _processResponse(response);
    if (response.statusCode == 200) {
      final String accessToken = data['access_token']?.toString().trim() ?? '';
      final String refreshToken =
          data['refresh_token']?.toString().trim() ?? '';
      if (accessToken.isEmpty || refreshToken.isEmpty) {
        throw Exception('Missing authentication tokens in login response');
      }
      await _storage.write(key: 'access_token', value: accessToken);
      await _storage.write(key: 'refresh_token', value: refreshToken);
    }
    return data;
  }

  static Future<void> logout() async {
    await _storage.delete(key: 'access_token');
    await _storage.delete(key: 'refresh_token');
    await _clearProfileCache();
  }

  static Future<String?> getAccessToken() async {
    return await _storage.read(key: 'access_token');
  }

  static Future<String?> getRefreshToken() async {
    return await _storage.read(key: 'refresh_token');
  }

  static Future<void> setAccessToken(String token) async {
    await _storage.write(key: 'access_token', value: token);
  }

  static Future<Map<String, dynamic>> refreshAccessToken() async {
    final refreshToken = (await getRefreshToken())?.trim();
    if (refreshToken == null || refreshToken.isEmpty) {
      throw Exception('No refresh token found');
    }
    final response = await _safePost(
      Uri.parse('$_baseUrl/auth/refresh'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'refresh_token': refreshToken}),
    );
    final data = _processResponse(response);
    if (response.statusCode == 200) {
      final String accessToken = data['access_token']?.toString().trim() ?? '';
      if (accessToken.isEmpty) {
        throw Exception('Missing access token in refresh response');
      }
      await setAccessToken(accessToken);
    }
    return data;
  }

  static Map<String, dynamic> _processResponse(http.Response response) {
    final dynamic decoded = _decodeBody(response.body);
    final Map<String, dynamic> data = decoded is Map<String, dynamic>
        ? decoded
        : <String, dynamic>{};
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    } else {
      throw Exception(
        data['message']?.toString() ??
            data['error']?.toString() ??
            'Request failed with status ${response.statusCode}',
      );
    }
  }
}
