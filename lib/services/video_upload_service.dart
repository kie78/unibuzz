import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:unibuzz/services/api_client.dart';

/// Result returned after a successful Cloudinary upload.
class CloudinaryUploadResult {
  const CloudinaryUploadResult({required this.secureUrl});
  final String secureUrl;
}

/// Result returned after queuing the video on the UniBuzz backend.
class BackendUploadResult {
  const BackendUploadResult({required this.videoId});
  final String videoId;
}

/// Encapsulates the three-step video upload pipeline:
///   1. Compress + upload local file → Cloudinary
///   2. Submit Cloudinary URL → UniBuzz backend
///   3. Poll processing status
class VideoUploadService {
  static const int _maxFileSizeBytes = 50 * 1024 * 1024; // 50 MB
  static const String _cloudinaryBaseUrl =
      'https://api.cloudinary.com/v1_1/df3lhzzy7/video/upload';

  // ─── STEP 1 helpers ──────────────────────────────────────────────────────

  /// Validates that the local file is ≤ 50 MB.
  /// Throws a user-friendly [Exception] when the constraint is violated.
  static void validateFileSize(String filePath) {
    final file = File(filePath);
    if (!file.existsSync()) {
      throw Exception('The selected video file no longer exists.');
    }
    final bytes = file.lengthSync();
    if (bytes > _maxFileSizeBytes) {
      throw Exception(
        'Video is too large (${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB). '
        'Please keep uploads under 50 MB.',
      );
    }
  }

  /// Uploads [filePath] to Cloudinary via multipart/form-data.
  /// Reports byte-level progress through [onProgress] (0.0 – 1.0).
  static Future<CloudinaryUploadResult> uploadToCloudinary({
    required String filePath,
    required void Function(double progress) onProgress,
  }) async {
    final uploadPreset = dotenv.env['CLOUDINARY_UPLOAD_PRESET'] ?? '';
    if (uploadPreset.isEmpty) {
      throw Exception(
        'Cloudinary upload preset is not configured. '
        'Set CLOUDINARY_UPLOAD_PRESET in .env.',
      );
    }

    final formData = FormData.fromMap(<String, dynamic>{
      'file': await MultipartFile.fromFile(filePath),
      'upload_preset': uploadPreset,
      'resource_type': 'video',
      'folder': 'unibuzz/videos',
    });

    final cloudinaryDio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(minutes: 10),
        validateStatus: (_) => true,
      ),
    );

    final response = await cloudinaryDio.post<dynamic>(
      _cloudinaryBaseUrl,
      data: formData,
      onSendProgress: (int sent, int total) {
        if (total > 0) {
          onProgress((sent / total).clamp(0.0, 1.0));
        }
      },
    );

    final dynamic decoded = response.data;
    final int statusCode = response.statusCode ?? 0;

    if (statusCode < 200 || statusCode >= 300) {
      String? message;
      if (decoded is Map && decoded['error'] is Map) {
        message = decoded['error']['message']?.toString().trim();
      }
      throw Exception(
        message ?? 'Cloudinary upload failed with status $statusCode.',
      );
    }

    if (decoded is! Map) {
      throw Exception('Cloudinary returned an unexpected response format.');
    }

    final secureUrl = (decoded['secure_url'] ?? decoded['url'])
        ?.toString()
        .trim();
    if (secureUrl == null || secureUrl.isEmpty) {
      throw Exception(
        'Cloudinary upload succeeded but no secure_url was returned.',
      );
    }

    return CloudinaryUploadResult(secureUrl: secureUrl);
  }

  // ─── STEP 2 ──────────────────────────────────────────────────────────────

  /// Posts the Cloudinary [secureUrl] to the UniBuzz backend.
  /// All parameters go as query parameters per the API contract.
  /// Returns the [BackendUploadResult] containing the video_id.
  static Future<BackendUploadResult> submitToBackend({
    required String secureUrl,
    String? caption,
    List<String>? tags,
  }) async {
    final tagString = tags != null && tags.isNotEmpty
        ? tags.take(10).map((t) => t.replaceAll('#', '')).join(',')
        : null;

    final queryParams = <String, String>{
      'input_url': secureUrl,
      if (caption != null && caption.trim().isNotEmpty)
        'caption': caption.trim(),
      if (tagString != null && tagString.isNotEmpty) 'tags': tagString,
    };

    final response = await ApiClient.instance.dio.post<dynamic>(
      '/api/videos/upload',
      queryParameters: queryParams,
    );

    final int statusCode = response.statusCode ?? 0;
    final dynamic data = response.data;

    // Accept 202 Accepted as well as 200/201.
    if (statusCode < 200 || statusCode >= 300) {
      String? message;
      if (data is Map<String, dynamic>) {
        message = (data['message'] ?? data['error'] ?? data['detail'])
            ?.toString()
            .trim();
      }
      throw Exception(
        message ?? 'Backend upload request failed with status $statusCode.',
      );
    }

    final videoId = _extractVideoId(data);
    if (videoId == null || videoId.isEmpty) {
      throw Exception(
        'Upload accepted by server but no video_id was returned.',
      );
    }

    return BackendUploadResult(videoId: videoId);
  }

  // ─── STEP 3 ──────────────────────────────────────────────────────────────

  /// Polls GET /api/videos/:videoId/status every 5 s.
  /// Calls [onStatus] on each poll. When polling terminates, calls [onDone]
  /// with one of three final statuses:
  ///   - 'failed'  : backend reported failure; stop immediately.
  ///   - 'timeout' : [maxAttempts] exhausted and still pending.
  ///   - the raw status string (e.g. 'processed') on success.
  /// Stops after [maxAttempts] regardless of status.
  static Timer startProcessingPoller({
    required String videoId,
    required void Function(String status) onStatus,
    required Future<void> Function(String finalStatus) onDone,
    int maxAttempts = 20,
  }) {
    int attempt = 0;

    late final Timer timer;
    timer = Timer.periodic(const Duration(seconds: 5), (_) async {
      attempt++;

      try {
        final response = await ApiClient.instance.dio.get<dynamic>(
          '/api/videos/$videoId/status',
        );

        final dynamic data = response.data;
        final String? rawStatus = _extractStatusFromPayload(data);
        final String status = rawStatus ?? 'pending';

        onStatus(status);

        if (status == 'failed' || status == 'error' || status == 'rejected') {
          timer.cancel();
          await onDone('failed');
          return;
        }

        if (_isTerminalStatus(status)) {
          timer.cancel();
          await onDone(status);
          return;
        }

        if (attempt >= maxAttempts) {
          timer.cancel();
          await onDone('timeout');
        }
      } catch (_) {
        if (attempt >= maxAttempts) {
          timer.cancel();
          await onDone('timeout');
        }
      }
    });

    return timer;
  }

  // ─── Private helpers ─────────────────────────────────────────────────────

  static String? _extractVideoId(dynamic data) {
    if (data is! Map) return null;

    String? check(Map<dynamic, dynamic> m) {
      final id = m['video_id'] ?? m['id'];
      if (id != null && id.toString().trim().isNotEmpty) {
        return id.toString().trim();
      }
      return null;
    }

    final direct = check(data);
    if (direct != null) return direct;

    final nested = data['data'];
    if (nested is Map) return check(nested);

    return null;
  }

  static String? _extractStatusFromPayload(dynamic data) {
    if (data is! Map) return null;

    const keys = <String>[
      'status',
      'state',
      'processing_status',
      'job_status',
      'phase',
    ];

    for (final key in keys) {
      final v = data[key];
      if (v != null && v.toString().trim().isNotEmpty) {
        return v.toString().trim().toLowerCase();
      }
    }

    final nested = data['data'];
    if (nested is Map) {
      for (final key in keys) {
        final v = nested[key];
        if (v != null && v.toString().trim().isNotEmpty) {
          return v.toString().trim().toLowerCase();
        }
      }
    }

    return null;
  }

  static bool _isTerminalStatus(String status) {
    const terminal = <String>{
      'processed',
      'complete',
      'completed',
      'done',
      'success',
      'ready',
      'failed',
      'error',
      'rejected',
    };
    return terminal.contains(status);
  }
}
