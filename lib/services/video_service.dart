import 'dart:io';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:unibuzz/services/auth_service.dart';

class VideoCommentsResponse {
  const VideoCommentsResponse({
    required this.comments,
    required this.commentsDisabled,
  });

  final List<dynamic> comments;
  final bool commentsDisabled;
}

class VideoService {
  static const String _defaultBaseUrl = 'https://unibuzz-api.onrender.com';
  static http.Client _httpClient = http.Client();
  static String? _baseUrlForTesting;
  static bool _refreshEndpointUnavailable = false;

  static String get _baseUrl => _baseUrlForTesting ?? _defaultBaseUrl;

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
    _refreshEndpointUnavailable = false;
  }

  static String _normalizeAccessToken(String rawToken) {
    String token = rawToken.trim();
    if (token.toLowerCase().startsWith('bearer ')) {
      token = token.substring(7).trim();
    }
    if (token.length >= 2 && token.startsWith('"') && token.endsWith('"')) {
      token = token.substring(1, token.length - 1).trim();
    }
    return token;
  }

  static Future<Map<String, String>> _buildAuthHeaders() async {
    final accessToken = await AuthService.getAccessToken();
    if (accessToken == null || accessToken.isEmpty) {
      throw Exception('Session expired. Please log in again.');
    }

    final normalizedToken = _normalizeAccessToken(accessToken);
    if (normalizedToken.isEmpty || !normalizedToken.contains('.')) {
      throw Exception('Session expired. Please log in again.');
    }

    return <String, String>{
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $normalizedToken',
    };
  }

  static Future<Map<String, String>> _buildHeadersWithOptionalAuth() async {
    final accessToken = await AuthService.getAccessToken();
    final baseHeaders = <String, String>{'Content-Type': 'application/json'};

    if (accessToken == null || accessToken.trim().isEmpty) {
      return baseHeaders;
    }

    final normalizedToken = _normalizeAccessToken(accessToken);
    if (normalizedToken.isEmpty || !normalizedToken.contains('.')) {
      return baseHeaders;
    }

    return <String, String>{
      ...baseHeaders,
      'Authorization': 'Bearer $normalizedToken',
    };
  }

  static dynamic _decodeBody(String body) {
    if (body.isEmpty) return null;
    try {
      return jsonDecode(body);
    } catch (_) {
      return body;
    }
  }

  static String _extractErrorMessage({
    required dynamic decoded,
    required int statusCode,
  }) {
    if (statusCode == 401) {
      return 'Session expired. Please log in again.';
    }

    if (decoded is Map<String, dynamic>) {
      final dynamic message =
          decoded['message'] ?? decoded['error'] ?? decoded['detail'];
      if (message != null && message.toString().trim().isNotEmpty) {
        return message.toString();
      }
      final dynamic errors = decoded['errors'];
      if (errors != null) {
        return errors.toString();
      }
    }
    if (decoded is String && decoded.trim().isNotEmpty) {
      return decoded;
    }
    return 'Request failed with status $statusCode';
  }

  static bool _isHttpUrl(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null || uri.host.isEmpty) {
      return false;
    }
    return uri.scheme == 'http' || uri.scheme == 'https';
  }

  static String? _extractFirstNonEmptyString(
    Map<dynamic, dynamic> map,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = map[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }
    return null;
  }

  static String? _extractSourceUrlFromPayload(dynamic payload) {
    if (payload is! Map) {
      return null;
    }

    const urlKeys = <String>[
      'input_url',
      'source_url',
      'secure_url',
      'video_url',
      'url',
      'media_url',
    ];

    final direct = _extractFirstNonEmptyString(payload, urlKeys);
    if (direct != null && _isHttpUrl(direct)) {
      return direct;
    }

    for (final nestedKey in <String>['data', 'result', 'upload']) {
      final nested = payload[nestedKey];
      if (nested is! Map) {
        continue;
      }

      final nestedUrl = _extractFirstNonEmptyString(nested, urlKeys);
      if (nestedUrl != null && _isHttpUrl(nestedUrl)) {
        return nestedUrl;
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

  /// Applies Cloudinary adaptive quality and format transforms to a video URL.
  /// Transforms: q_auto (adaptive quality), f_auto (best format), h_720,c_limit (720p max).
  static String _applyCloudinaryTransforms(String url) {
    if (!url.contains('cloudinary')) {
      return url;
    }
    // Insert transforms after /video/upload/
    return url.replaceFirst(
      '/video/upload/',
      '/video/upload/q_auto,f_auto,h_720,c_limit/',
    );
  }

  /// Post-processes video items to apply Cloudinary transforms and normalize URLs.
  static List<dynamic> _processVideoList(List<dynamic> videos) {
    return videos.map((dynamic item) {
      if (item is! Map<String, dynamic>) {
        return item;
      }
      final video = Map<String, dynamic>.from(item);
      if (video['video_url'] is String) {
        video['video_url'] = _applyCloudinaryTransforms(video['video_url']);
      }
      if (video['thumbnail_url'] is String) {
        video['thumbnail_url'] = _applyCloudinaryTransforms(video['thumbnail_url']);
      }
      return video;
    }).toList();
  }

  /// Applies Cloudinary transforms to video_url and thumbnail_url in a status response.
  static Map<String, dynamic> _processStatusResponse(Map<String, dynamic> response) {
    final processed = Map<String, dynamic>.from(response);
    if (processed['video_url'] is String) {
      processed['video_url'] = _applyCloudinaryTransforms(processed['video_url']);
    }
    if (processed['thumbnail_url'] is String) {
      processed['thumbnail_url'] = _applyCloudinaryTransforms(processed['thumbnail_url']);
    }
    return processed;
  }

  static VideoCommentsResponse _parseCommentsResponse(dynamic decoded) {
    if (decoded is List<dynamic>) {
      return VideoCommentsResponse(comments: decoded, commentsDisabled: false);
    }

    if (decoded is Map) {
      final normalized = Map<dynamic, dynamic>.from(decoded);

      final topLevelComments = normalized['comments'];
      if (topLevelComments is List<dynamic>) {
        return VideoCommentsResponse(
          comments: topLevelComments,
          commentsDisabled:
              _parseBool(normalized['comments_disabled']) ?? false,
        );
      }

      final data = normalized['data'];
      if (data is List<dynamic>) {
        return VideoCommentsResponse(comments: data, commentsDisabled: false);
      }

      if (data is Map) {
        final nested = Map<dynamic, dynamic>.from(data);
        final nestedComments = nested['comments'];
        if (nestedComments is List<dynamic>) {
          return VideoCommentsResponse(
            comments: nestedComments,
            commentsDisabled:
                _parseBool(nested['comments_disabled']) ??
                _parseBool(normalized['comments_disabled']) ??
                false,
          );
        }
      }
    }

    return const VideoCommentsResponse(
      comments: <dynamic>[],
      commentsDisabled: false,
    );
  }

  static Future<http.Response> _sendAuthenticated(
    Future<http.Response> Function(Map<String, String> headers) sender,
  ) async {
    Map<String, String> headers = await _buildAuthHeaders();
    http.Response response = await sender(headers);

    if (response.statusCode != 401) {
      return response;
    }

    // The deployed backend may not expose /auth/refresh; if unavailable,
    // clear stale tokens and force re-authentication.
    if (!_refreshEndpointUnavailable) {
      try {
        await AuthService.refreshAccessToken();
        headers = await _buildAuthHeaders();
        response = await sender(headers);
        if (response.statusCode != 401) {
          return response;
        }
      } catch (e) {
        if (e.toString().contains('404')) {
          _refreshEndpointUnavailable = true;
        }
      }
    }

    await AuthService.logout();
    throw Exception('Session expired. Please log in again.');
  }

  static Future<http.Response> _sendWithOptionalAuth(
    Future<http.Response> Function(Map<String, String> headers) sender,
  ) async {
    final unauthenticatedHeaders = <String, String>{
      'Content-Type': 'application/json',
    };

    Map<String, String> headers = await _buildHeadersWithOptionalAuth();
    final hadAuth = headers.containsKey('Authorization');

    http.Response response = await sender(headers);
    if (response.statusCode < 400) {
      return response;
    }

    if ((response.statusCode == 401 || response.statusCode == 403) && hadAuth) {
      try {
        await AuthService.refreshAccessToken();
        headers = await _buildHeadersWithOptionalAuth();
        if (headers.containsKey('Authorization')) {
          response = await sender(headers);
          if (response.statusCode < 400) {
            return response;
          }
        }
      } catch (_) {
        // Ignore refresh failure for optional-auth endpoints; try anonymous.
      }

      // Some deployed environments expose these read endpoints publicly.
      response = await sender(unauthenticatedHeaders);
    }

    return response;
  }

  static Map<String, dynamic> _processResponse(http.Response response) {
    final dynamic decoded = _decodeBody(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      return <String, dynamic>{'data': decoded};
    }
    final String message = _extractErrorMessage(
      decoded: decoded,
      statusCode: response.statusCode,
    );
    throw Exception(message);
  }

  /// GET /api/feed
  static Future<List<dynamic>> fetchFeed({String? before, int? limit}) async {
    final queryParameters = <String, String>{
      if (before != null && before.trim().isNotEmpty) 'before': before.trim(),
      if (limit != null && limit > 0) 'limit': limit.toString(),
    };

    final uri = Uri.parse('$_baseUrl/api/feed').replace(
      queryParameters: queryParameters.isEmpty ? null : queryParameters,
    );
    final response = await _sendAuthenticated(
      (headers) => _httpClient.get(uri, headers: headers),
    );
    final dynamic decoded = _decodeBody(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (decoded is List<dynamic>) {
        return _processVideoList(decoded);
      }
      return <dynamic>[];
    }
    throw Exception(
      _extractErrorMessage(decoded: decoded, statusCode: response.statusCode),
    );
  }

  /// GET /api/search
  static Future<List<dynamic>> searchVideos({
    String? tag,
    String? username,
  }) async {
    final queryParameters = <String, String>{};
    if (tag != null && tag.trim().isNotEmpty) {
      queryParameters['tag'] = tag.trim();
    }
    if (username != null && username.trim().isNotEmpty) {
      queryParameters['username'] = username.trim();
    }
    final uri = Uri.parse(
      '$_baseUrl/api/search',
    ).replace(queryParameters: queryParameters);
    final response = await _httpClient.get(uri);
    final dynamic decoded = response.body.isNotEmpty
        ? jsonDecode(response.body)
        : null;
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (decoded is List<dynamic>) {
        return _processVideoList(decoded);
      }
      return <dynamic>[];
    }
    if (decoded is Map<String, dynamic>) {
      throw Exception(decoded['message'] ?? 'Search failed');
    }
    throw Exception('Search failed');
  }

  /// POST /api/videos/upload
  static Future<Map<String, dynamic>> uploadVideo({
    required String inputUrl,
    String? caption,
    List<String>? tags,
  }) async {
    final queryParameters = <String, String>{
      'input_url': inputUrl,
      if (caption != null && caption.trim().isNotEmpty)
        'caption': caption.trim(),
      if (tags != null && tags.isNotEmpty) 'tags': tags.join(','),
    };
    final uri = Uri.parse(
      '$_baseUrl/api/videos/upload',
    ).replace(queryParameters: queryParameters);
    final response = await _sendAuthenticated(
      (headers) => _httpClient.post(uri, headers: headers),
    );
    final uploadResponse = _processResponse(response);
    return _processStatusResponse(uploadResponse);
  }

  /// Attempts authenticated source-file upload via backend proxy endpoint.
  ///
  /// The backend should return a publicly reachable URL for `input_url`.
  static Future<String> uploadSourceVideoFile({
    required String filePath,
  }) async {
    final normalizedPath = filePath.trim();
    if (normalizedPath.isEmpty) {
      throw Exception('A local video path is required.');
    }

    final localFile = File(normalizedPath);
    if (!localFile.existsSync()) {
      throw Exception('Selected video file no longer exists.');
    }

    final endpointCandidates = <String>[
      '/api/videos/upload-source',
      '/api/videos/source-upload',
    ];

    String? lastUnavailableMessage;

    for (final endpoint in endpointCandidates) {
      final uri = Uri.parse('$_baseUrl$endpoint');

      final response = await _sendAuthenticated((headers) async {
        final multipartHeaders = Map<String, String>.from(headers)
          ..removeWhere((key, _) => key.toLowerCase() == 'content-type');

        final request = http.MultipartRequest('POST', uri)
          ..headers.addAll(multipartHeaders)
          ..files.add(
            await http.MultipartFile.fromPath('file', normalizedPath),
          );

        final streamedResponse = await _httpClient.send(request);
        return http.Response.fromStream(streamedResponse);
      });

      final decoded = _decodeBody(response.body);

      if (response.statusCode == 404 || response.statusCode == 405) {
        lastUnavailableMessage = _extractErrorMessage(
          decoded: decoded,
          statusCode: response.statusCode,
        );
        continue;
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(
          _extractErrorMessage(
            decoded: decoded,
            statusCode: response.statusCode,
          ),
        );
      }

      final sourceUrl = _extractSourceUrlFromPayload(decoded);
      if (sourceUrl == null) {
        throw Exception(
          'Source upload succeeded, but no usable media URL was returned.',
        );
      }

      return sourceUrl;
    }

    final details =
        lastUnavailableMessage == null || lastUnavailableMessage.isEmpty
        ? ''
        : ' Last response: $lastUnavailableMessage';

    throw Exception('Backend source upload endpoint is not available.$details');
  }

  /// GET /api/videos/:video_id/status
  static Future<Map<String, dynamic>> getVideoStatus({
    required String videoId,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/videos/$videoId/status');
    final response = await _sendAuthenticated(
      (headers) => _httpClient.get(uri, headers: headers),
    );
    final statusResponse = _processResponse(response);
    return _processStatusResponse(statusResponse);
  }

  /// POST /api/videos/:video_id/comments
  static Future<Map<String, dynamic>> addComment({
    required String videoId,
    required String comment,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/videos/$videoId/comments');
    final response = await _sendAuthenticated(
      (headers) => _httpClient.post(
        uri,
        headers: headers,
        body: jsonEncode(<String, String>{'comment': comment}),
      ),
    );
    return _processResponse(response);
  }

  /// GET /api/videos/:video_id/comments
  static Future<VideoCommentsResponse> getCommentsResponse({
    required String videoId,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/videos/$videoId/comments');

    final response = await _sendWithOptionalAuth(
      (headers) => _httpClient.get(uri, headers: headers),
    );

    final dynamic decoded = _decodeBody(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return _parseCommentsResponse(decoded);
    }

    throw Exception(
      _extractErrorMessage(decoded: decoded, statusCode: response.statusCode),
    );
  }

  /// Backward-compatible comments accessor used by existing call sites.
  static Future<List<dynamic>> getComments({required String videoId}) async {
    final response = await getCommentsResponse(videoId: videoId);
    return response.comments;
  }

  /// PUT /api/comments/:comment_id
  static Future<Map<String, dynamic>> updateComment({
    required String commentId,
    required String comment,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/comments/$commentId');
    final response = await _sendAuthenticated(
      (headers) => _httpClient.put(
        uri,
        headers: headers,
        body: jsonEncode(<String, String>{'comment': comment}),
      ),
    );
    return _processResponse(response);
  }

  /// DELETE /api/comments/:comment_id
  static Future<Map<String, dynamic>> deleteComment({
    required String commentId,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/comments/$commentId');
    final response = await _sendAuthenticated(
      (headers) => _httpClient.delete(uri, headers: headers),
    );
    return _processResponse(response);
  }

  /// POST /api/videos/:video_id/vote
  static Future<Map<String, dynamic>> voteOnVideo({
    required String videoId,
    required int voteType,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/videos/$videoId/vote');
    final response = await _sendAuthenticated(
      (headers) => _httpClient.post(
        uri,
        headers: headers,
        body: jsonEncode(<String, int>{'vote_type': voteType}),
      ),
    );
    return _processResponse(response);
  }

  /// GET /api/videos/:video_id/votes
  static Future<Map<String, dynamic>> getVideoVotes({
    required String videoId,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/videos/$videoId/votes');

    final response = await _sendWithOptionalAuth(
      (headers) => _httpClient.get(uri, headers: headers),
    );
    return _processResponse(response);
  }

  /// POST /api/videos/:video_id/report
  static Future<Map<String, dynamic>> reportVideo({
    required String videoId,
    required String reason,
    String? customReason,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/videos/$videoId/report');
    final body = <String, String>{
      'reason': reason,
      if (customReason != null && customReason.trim().isNotEmpty)
        'custom_reason': customReason.trim(),
    };
    final response = await _sendAuthenticated(
      (headers) =>
          _httpClient.post(uri, headers: headers, body: jsonEncode(body)),
    );
    return _processResponse(response);
  }

  /// GET /api/me/comment-filters
  static Future<List<Map<String, dynamic>>> getCommentFilters() async {
    final uri = Uri.parse('$_baseUrl/api/me/comment-filters');
    final response = await _sendAuthenticated(
      (headers) => _httpClient.get(uri, headers: headers),
    );
    final dynamic decoded = _decodeBody(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (decoded is List) {
        return List<Map<String, dynamic>>.from(
          decoded.map((item) => Map<String, dynamic>.from(item as Map)),
        );
      }
      return <Map<String, dynamic>>[];
    }

    throw Exception(
      _extractErrorMessage(decoded: decoded, statusCode: response.statusCode),
    );
  }

  /// POST /api/me/comment-filters
  static Future<Map<String, dynamic>> addCommentFilter({
    required String keyword,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/me/comment-filters');
    final body = <String, String>{'keyword': keyword.trim()};
    final response = await _sendAuthenticated(
      (headers) =>
          _httpClient.post(uri, headers: headers, body: jsonEncode(body)),
    );
    return _processResponse(response);
  }

  /// DELETE /api/me/comment-filters/:filter_id
  static Future<Map<String, dynamic>> deleteCommentFilter({
    required String filterId,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/me/comment-filters/$filterId');
    final response = await _sendAuthenticated(
      (headers) => _httpClient.delete(uri, headers: headers),
    );
    return _processResponse(response);
  }
}
