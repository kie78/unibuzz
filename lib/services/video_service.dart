import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:unibuzz/services/api_client.dart';

class VideoCommentsResponse {
  const VideoCommentsResponse({
    required this.comments,
    required this.commentsDisabled,
  });

  final List<dynamic> comments;
  final bool commentsDisabled;
}

class VideoService {
  static Dio get _dio => ApiClient.instance.dio;

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

  static String? extractVideoId(dynamic payload) {
    if (payload is! Map) {
      if (payload is String) {
        final value = payload.trim();
        return value.isEmpty ? null : value;
      }
      return null;
    }

    for (final key in <String>['id', 'video_id']) {
      final value = payload[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }

    for (final nestedKey in <String>['data', 'video', 'result']) {
      final nested = payload[nestedKey];
      final nestedId = extractVideoId(nested);
      if (nestedId != null) {
        return nestedId;
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
  static String _applyCloudinaryTransforms(String url) {
    if (!url.contains('cloudinary')) {
      return url;
    }
    return url.replaceFirst(
      '/video/upload/',
      '/video/upload/q_auto,f_auto,h_720,c_limit/',
    );
  }

  static List<dynamic> _processVideoList(List<dynamic> videos) {
    return videos.map((dynamic item) {
      if (item is! Map<String, dynamic>) {
        return item;
      }
      final video = Map<String, dynamic>.from(item);
      final canonicalId = extractVideoId(video);
      if (canonicalId != null) {
        video['id'] = canonicalId;
      }
      if (video['video_url'] is String) {
        video['video_url'] = _applyCloudinaryTransforms(video['video_url']);
      }
      if (video['thumbnail_url'] is String) {
        video['thumbnail_url'] = _applyCloudinaryTransforms(
          video['thumbnail_url'],
        );
      }
      return video;
    }).toList();
  }

  static Map<String, dynamic> _processStatusResponse(
    Map<String, dynamic> response,
  ) {
    final processed = Map<String, dynamic>.from(response);
    final canonicalId = extractVideoId(processed);
    if (canonicalId != null) {
      processed['id'] = canonicalId;
    }
    if (processed['video_url'] is String) {
      processed['video_url'] = _applyCloudinaryTransforms(
        processed['video_url'],
      );
    }
    if (processed['thumbnail_url'] is String) {
      processed['thumbnail_url'] = _applyCloudinaryTransforms(
        processed['thumbnail_url'],
      );
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

  static Map<String, dynamic> _processResponse(Response<dynamic> response) {
    final dynamic data = response.data;
    final int statusCode = response.statusCode ?? 0;
    if (statusCode >= 200 && statusCode < 300) {
      if (data is Map<String, dynamic>) {
        return data;
      }
      return <String, dynamic>{'data': data};
    }
    throw Exception(
      _extractErrorMessage(decoded: data, statusCode: statusCode),
    );
  }

  /// GET /api/feed
  static Future<List<dynamic>> fetchFeed({String? before, int? limit}) async {
    final queryParameters = <String, String>{
      if (before != null && before.trim().isNotEmpty) 'before': before.trim(),
      if (limit != null && limit > 0) 'limit': limit.toString(),
    };

    final response = await _dio.get<dynamic>(
      '/api/feed',
      queryParameters: queryParameters.isEmpty ? null : queryParameters,
    );
    final dynamic data = response.data;
    final int statusCode = response.statusCode ?? 0;
    if (statusCode >= 200 && statusCode < 300) {
      if (data is List<dynamic>) {
        return _processVideoList(data);
      }
      return <dynamic>[];
    }
    throw Exception(
      _extractErrorMessage(decoded: data, statusCode: statusCode),
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

    final response = await _dio.get<dynamic>(
      '/api/search',
      queryParameters: queryParameters,
    );
    final dynamic data = response.data;
    final int statusCode = response.statusCode ?? 0;
    if (statusCode >= 200 && statusCode < 300) {
      if (data is List<dynamic>) {
        return _processVideoList(data);
      }
      return <dynamic>[];
    }
    if (data is Map<String, dynamic>) {
      throw Exception(data['message'] ?? 'Search failed');
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
    final response = await _dio.post<dynamic>(
      '/api/videos/upload',
      queryParameters: queryParameters,
    );
    final uploadResponse = _processResponse(response);
    return _processStatusResponse(uploadResponse);
  }

  /// Attempts authenticated source-file upload via backend proxy endpoint.
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
      final formData = FormData.fromMap(<String, dynamic>{
        'file': await MultipartFile.fromFile(normalizedPath),
      });

      final response = await _dio.post<dynamic>(endpoint, data: formData);
      final dynamic data = response.data;
      final int statusCode = response.statusCode ?? 0;

      if (statusCode == 404 || statusCode == 405) {
        lastUnavailableMessage = _extractErrorMessage(
          decoded: data,
          statusCode: statusCode,
        );
        continue;
      }

      if (statusCode < 200 || statusCode >= 300) {
        throw Exception(
          _extractErrorMessage(decoded: data, statusCode: statusCode),
        );
      }

      final sourceUrl = _extractSourceUrlFromPayload(data);
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
    final response = await _dio.get<dynamic>('/api/videos/$videoId/status');
    final statusResponse = _processResponse(response);
    return _processStatusResponse(statusResponse);
  }

  /// POST /api/videos/:video_id/comments
  static Future<Map<String, dynamic>> addComment({
    required String videoId,
    required String comment,
  }) async {
    final response = await _dio.post<dynamic>(
      '/api/videos/$videoId/comments',
      data: <String, String>{'comment': comment},
    );
    return _processResponse(response);
  }

  /// GET /api/videos/:video_id/comments
  static Future<VideoCommentsResponse> getCommentsResponse({
    required String videoId,
  }) async {
    final response = await _dio.get<dynamic>('/api/videos/$videoId/comments');
    final dynamic data = response.data;
    final int statusCode = response.statusCode ?? 0;
    if (statusCode >= 200 && statusCode < 300) {
      return _parseCommentsResponse(data);
    }
    throw Exception(
      _extractErrorMessage(decoded: data, statusCode: statusCode),
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
    final response = await _dio.put<dynamic>(
      '/api/comments/$commentId',
      data: <String, String>{'comment': comment},
    );
    return _processResponse(response);
  }

  /// DELETE /api/comments/:comment_id
  static Future<Map<String, dynamic>> deleteComment({
    required String commentId,
  }) async {
    final response = await _dio.delete<dynamic>('/api/comments/$commentId');
    return _processResponse(response);
  }

  /// POST /api/videos/:video_id/vote
  static Future<Map<String, dynamic>> voteOnVideo({
    required String videoId,
    required int voteType,
  }) async {
    final response = await _dio.post<dynamic>(
      '/api/videos/$videoId/vote',
      data: <String, int>{'vote_type': voteType},
    );
    return _processResponse(response);
  }

  /// GET /api/videos/:video_id/votes
  static Future<Map<String, dynamic>> getVideoVotes({
    required String videoId,
  }) async {
    final response = await _dio.get<dynamic>('/api/videos/$videoId/votes');
    return _processResponse(response);
  }

  /// POST /api/videos/:video_id/report
  static Future<Map<String, dynamic>> reportVideo({
    required String videoId,
    required String reason,
    String? customReason,
  }) async {
    final body = <String, String>{
      'reason': reason,
      if (customReason != null && customReason.trim().isNotEmpty)
        'custom_reason': customReason.trim(),
    };
    final response = await _dio.post<dynamic>(
      '/api/videos/$videoId/report',
      data: body,
    );
    return _processResponse(response);
  }

  /// GET /api/me/videos — returns all videos owned by the authenticated user,
  /// including pending ones, with inline upvotes, downvotes, and comment counts.
  static Future<List<dynamic>> getMyVideos() async {
    final response = await _dio.get<dynamic>('/api/me/videos');
    final dynamic data = response.data;
    final int statusCode = response.statusCode ?? 0;
    if (statusCode >= 200 && statusCode < 300) {
      if (data is List<dynamic>) {
        return _processVideoList(data);
      }
      return <dynamic>[];
    }
    throw Exception(
      _extractErrorMessage(decoded: data, statusCode: statusCode),
    );
  }

  /// GET /api/me/comment-filters
  static Future<List<Map<String, dynamic>>> getCommentFilters() async {
    final response = await _dio.get<dynamic>('/api/me/comment-filters');
    final dynamic data = response.data;
    final int statusCode = response.statusCode ?? 0;

    if (statusCode >= 200 && statusCode < 300) {
      if (data is List) {
        return List<Map<String, dynamic>>.from(
          data.map((item) => Map<String, dynamic>.from(item as Map)),
        );
      }
      return <Map<String, dynamic>>[];
    }

    throw Exception(
      _extractErrorMessage(decoded: data, statusCode: statusCode),
    );
  }

  /// POST /api/me/comment-filters
  static Future<Map<String, dynamic>> addCommentFilter({
    required String keyword,
  }) async {
    final response = await _dio.post<dynamic>(
      '/api/me/comment-filters',
      data: <String, String>{'keyword': keyword.trim()},
    );
    return _processResponse(response);
  }

  /// PATCH /api/videos/:video_id/comments/toggle
  static Future<Map<String, dynamic>> toggleComments({
    required String videoId,
  }) async {
    final response = await _dio.patch<dynamic>(
      '/api/videos/$videoId/comments/toggle',
    );
    return _processResponse(response);
  }

  /// DELETE /api/me/comment-filters/:filter_id
  static Future<Map<String, dynamic>> deleteCommentFilter({
    required String filterId,
  }) async {
    final response = await _dio.delete<dynamic>(
      '/api/me/comment-filters/$filterId',
    );
    return _processResponse(response);
  }

  @visibleForTesting
  static String applyCloudinaryTransformsForTesting(String url) =>
      _applyCloudinaryTransforms(url);
}
