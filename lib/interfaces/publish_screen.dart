import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:unibuzz/services/error_helper.dart';
import 'package:unibuzz/services/pending_upload_tracker_service.dart';
import 'package:unibuzz/services/video_service.dart';
import 'package:dio/dio.dart';
import 'package:crypto/crypto.dart';
import 'package:video_player/video_player.dart';

class PublishScreen extends StatefulWidget {
  const PublishScreen({super.key, required this.videoPath});

  final String videoPath;

  @override
  State<PublishScreen> createState() => _PublishScreenState();
}

class _PublishScreenState extends State<PublishScreen> {
  static const int _maxUploadSizeBytes = 50 * 1024 * 1024;
  static const Duration _processingPollInterval = Duration(seconds: 5);
  static const int _maxProcessingPollAttempts = 20;

  VideoPlayerController? _videoController;
  bool _isInitializing = true;
  bool _hasLoadError = false;
  late TextEditingController _captionController;
  late TextEditingController _hashtagController;

  // Upload state variables
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  String _uploadStatus =
      'idle'; // idle, uploading_media, queueing, processing, completed, failed
  String _uploadMessage = '';
  bool _isProcessingQueuedVideo = false;
  bool _stopProcessingPollRequested = false;
  int _processingPollAttempt = 0;
  String? _processingVideoId;
  bool get _isBusy => _isUploading || _isProcessingQueuedVideo;

  @override
  void initState() {
    super.initState();
    _captionController = TextEditingController();
    _hashtagController = TextEditingController();
    _hashtagController.addListener(_onHashtagChanged);
    _initializeVideo();
  }

  void _onHashtagChanged() {
    setState(() {});
  }

  Future<void> _initializeVideo() async {
    try {
      final VideoPlayerController controller = VideoPlayerController.file(
        File(widget.videoPath),
      );

      await controller.initialize();
      await controller.setLooping(true);

      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _videoController = controller;
        _isInitializing = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isInitializing = false;
        _hasLoadError = true;
      });
    }
  }

  void _togglePlayback() {
    final VideoPlayerController? controller = _videoController;
    if (controller == null || !controller.value.isInitialized) return;

    setState(() {
      if (controller.value.isPlaying) {
        controller.pause();
      } else {
        controller.play();
      }
    });
  }

  String _formatDuration(Duration duration) {
    final int minutes = duration.inMinutes;
    final int seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  List<String> _parseTags(String rawTags) {
    final tags = <String>{};
    final parts = rawTags.split(RegExp(r'[\s,]+'));
    for (final raw in parts) {
      final normalized = raw.trim().replaceFirst(RegExp(r'^#+'), '');
      if (normalized.isEmpty) {
        continue;
      }
      tags.add(normalized.toLowerCase());
    }
    return tags.take(10).toList();
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

  String? _extractVideoId(Map<String, dynamic> payload) {
    final direct = payload['video_id'] ?? payload['id'];
    if (direct != null && direct.toString().trim().isNotEmpty) {
      return direct.toString().trim();
    }

    final nested = payload['data'];
    if (nested is Map) {
      final nestedId = nested['video_id'] ?? nested['id'];
      if (nestedId != null && nestedId.toString().trim().isNotEmpty) {
        return nestedId.toString().trim();
      }
    }

    return null;
  }

  String? _extractStatus(Map<String, dynamic> payload) {
    String? readValue(dynamic raw) {
      if (raw == null) return null;
      final text = raw.toString().trim().toLowerCase();
      return text.isEmpty ? null : text;
    }

    const statusKeys = <String>[
      'status',
      'state',
      'processing_status',
      'job_status',
      'phase',
    ];

    for (final key in statusKeys) {
      final value = readValue(payload[key]);
      if (value != null) {
        return value;
      }
    }

    final nested = payload['data'];
    if (nested is Map) {
      for (final key in statusKeys) {
        final value = readValue(nested[key]);
        if (value != null) {
          return value;
        }
      }
    }

    return null;
  }

  bool _isCompleteStatus(String? status) {
    if (status == null) return false;
    return status == 'complete' ||
        status == 'completed' ||
        status == 'done' ||
        status == 'success' ||
        status == 'processed' ||
        status == 'ready';
  }

  bool _isFailedStatus(String? status) {
    if (status == null) return false;
    return status == 'failed' || status == 'error' || status == 'rejected';
  }

  String? _extractMessage(Map<String, dynamic> payload) {
    final direct = payload['message'] ?? payload['error'] ?? payload['detail'];
    if (direct != null && direct.toString().trim().isNotEmpty) {
      return direct.toString().trim();
    }

    final nested = payload['data'];
    if (nested is Map) {
      final nestedMessage =
          nested['message'] ?? nested['error'] ?? nested['detail'];
      if (nestedMessage != null && nestedMessage.toString().trim().isNotEmpty) {
        return nestedMessage.toString().trim();
      }
    }

    return null;
  }

  Map<String, String> _resolveCloudinaryConfig() {
    final cloudName = dotenv.env['CLOUDINARY_CLOUD_NAME'] ?? '';
    final uploadPreset = dotenv.env['CLOUDINARY_UPLOAD_PRESET'] ?? '';
    final apiKey = dotenv.env['CLOUDINARY_API_KEY'] ?? '';
    final apiSecret = dotenv.env['CLOUDINARY_API_SECRET'] ?? '';

    if (cloudName.isEmpty) {
      throw Exception(
        'Publishing is not configured in this app build. Please contact support.',
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
      'Publishing is not configured in this app build. Provide CLOUDINARY_UPLOAD_PRESET (unsigned) or CLOUDINARY_API_KEY/CLOUDINARY_API_SECRET (signed).',
    );
  }

  String _buildCloudinarySignature({
    required int timestamp,
    required String apiSecret,
    required String folder,
  }) {
    // Cloudinary signature requires a sorted query-string style payload.
    // Excluded params: file, cloud_name, resource_type, api_key.
    final params = <String, String>{
      'folder': folder,
      'timestamp': timestamp.toString(),
    };
    final sortedKeys = params.keys.toList()..sort();
    final payload =
        '${sortedKeys.map((key) => '$key=${params[key]}').join('&')}$apiSecret';
    return sha1.convert(utf8.encode(payload)).toString();
  }

  void _validateUploadConstraintsForPath(String videoPath) {
    if (_isHttpUrl(videoPath)) {
      return;
    }

    final file = File(videoPath);
    if (!file.existsSync()) {
      throw Exception('Selected video file no longer exists.');
    }

    final bytes = file.lengthSync();
    if (bytes > _maxUploadSizeBytes) {
      throw Exception('Video is too large. Please keep uploads under 50MB.');
    }
  }

  bool _isBackendSourceUploadUnavailable(Object error) {
    final text = _exceptionText(error).toLowerCase();
    return text.contains('backend source upload endpoint is not available');
  }

  Future<String> _prepareVideoPathForUpload() async {
    if (_isHttpUrl(widget.videoPath)) {
      return widget.videoPath;
    }

    final sourcePath = widget.videoPath.trim();
    final sourceFile = File(sourcePath);
    if (!sourceFile.existsSync()) {
      throw Exception('Selected video file no longer exists.');
    }

    return sourcePath;
  }

  bool _hasPlayableVideoUrl(Map<String, dynamic> payload) {
    String? readUrl(Map<dynamic, dynamic> map) {
      final raw = map['video_url'];
      if (raw is String && raw.trim().isNotEmpty) {
        return raw.trim();
      }
      return null;
    }

    if (readUrl(payload) != null) {
      return true;
    }

    final nested = payload['data'];
    if (nested is Map && readUrl(nested) != null) {
      return true;
    }

    return false;
  }

  void _continueProcessingInBackground() {
    _stopProcessingPollRequested = true;
    final processingVideoId = _processingVideoId;

    if (!mounted) {
      return;
    }

    setState(() {
      _isProcessingQueuedVideo = false;
      _isUploading = false;
      _processingVideoId = null;
      _processingPollAttempt = 0;
      _uploadStatus = 'completed';
      _uploadProgress = 1.0;
      _uploadMessage =
          'Upload queued. We\'ll publish it when processing finishes.';
    });

    final message = processingVideoId == null
        ? 'Upload queued. Your video is processing and will appear once ready.'
        : 'Upload queued (ID: $processingVideoId). Your video is processing and will appear once ready.';

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
    Navigator.of(context).pop(true);
  }

  Future<void> _pollQueuedVideoStatus({
    required String videoId,
    required String? trackedVideoId,
  }) async {
    _stopProcessingPollRequested = false;

    if (!mounted) {
      return;
    }

    setState(() {
      _isUploading = false;
      _isProcessingQueuedVideo = true;
      _processingVideoId = videoId;
      _processingPollAttempt = 0;
      _uploadStatus = 'processing';
      _uploadProgress = 0.25;
      _uploadMessage =
          'Video is processing... (status check 0/$_maxProcessingPollAttempts)';
    });

    for (int attempt = 1; attempt <= _maxProcessingPollAttempts; attempt++) {
      if (!mounted || _stopProcessingPollRequested) {
        return;
      }

      setState(() {
        _processingPollAttempt = attempt;
        final progressStep = (attempt / _maxProcessingPollAttempts) * 0.7;
        _uploadProgress = (0.25 + progressStep).clamp(0.25, 0.95);
        _uploadMessage =
            'Video is processing... (status check $attempt/$_maxProcessingPollAttempts)';
      });

      try {
        final statusPayload = await VideoService.getVideoStatus(
          videoId: videoId,
        );
        final status = _extractStatus(statusPayload);

        if (_isCompleteStatus(status) || _hasPlayableVideoUrl(statusPayload)) {
          if (trackedVideoId != null) {
            await PendingUploadTrackerService.removePendingUpload(
              trackedVideoId,
            );
          }

          if (!mounted || _stopProcessingPollRequested) {
            return;
          }

          setState(() {
            _isProcessingQueuedVideo = false;
            _processingVideoId = null;
            _processingPollAttempt = 0;
            _uploadStatus = 'completed';
            _uploadProgress = 1.0;
            _uploadMessage = 'Post published successfully!';
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Post published successfully!')),
          );
          Navigator.of(context).pop(true);
          return;
        }

        if (_isFailedStatus(status)) {
          throw Exception(
            _extractMessage(statusPayload) ??
                'Video processing failed on the server.',
          );
        }
      } catch (error) {
        final loweredError = error.toString().toLowerCase();
        final isTerminalProcessingFailure =
            loweredError.contains('processing failed') ||
            loweredError.contains('status failed') ||
            loweredError.contains('rejected');
        if (isTerminalProcessingFailure) {
          rethrow;
        }

        if (attempt < _maxProcessingPollAttempts && mounted) {
          setState(() {
            _uploadMessage =
                'Still processing... retrying status check ($attempt/$_maxProcessingPollAttempts)';
          });
        }
      }

      if (attempt < _maxProcessingPollAttempts) {
        await Future.delayed(_processingPollInterval);
      }
    }

    if (!mounted || _stopProcessingPollRequested) {
      return;
    }

    setState(() {
      _isProcessingQueuedVideo = false;
      _isUploading = false;
      _processingVideoId = null;
      _processingPollAttempt = 0;
      _uploadStatus = 'completed';
      _uploadProgress = 1.0;
      _uploadMessage =
          'Upload queued. Video is still processing and will appear when ready.';
    });

    final queueMessage = trackedVideoId == null
        ? 'Upload queued. Your video is still processing, check back shortly.'
        : 'Upload queued (ID: $trackedVideoId). Still processing, check back shortly.';

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(queueMessage)));
    Navigator.of(context).pop(true);
  }

  Future<String> _uploadLocalVideoViaBackend({required String filePath}) async {
    final localFile = File(filePath);
    if (!localFile.existsSync()) {
      throw Exception('Local video file could not be found for upload.');
    }

    if (!mounted) {
      throw Exception('Upload cancelled.');
    }

    setState(() {
      _uploadStatus = 'uploading_media';
      _uploadMessage = 'Uploading source video...';
      _uploadProgress = 0.08;
    });

    const int maxAttempts = 3;
    Object? lastError;

    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      if (!mounted) {
        throw Exception('Upload cancelled.');
      }

      if (attempt > 1) {
        setState(() {
          _uploadMessage = 'Retrying source upload ($attempt/$maxAttempts)...';
          _uploadProgress = 0.08;
        });
      }

      try {
        final sourceUrl = await VideoService.uploadSourceVideoFile(
          filePath: filePath,
        );

        if (!mounted) {
          throw Exception('Upload cancelled.');
        }

        setState(() {
          _uploadProgress = 0.22;
          _uploadMessage = 'Source upload complete.';
        });

        return sourceUrl;
      } catch (error) {
        lastError = error;

        if (_isBackendSourceUploadUnavailable(error)) {
          break;
        }

        if (attempt == maxAttempts) {
          break;
        }

        await Future.delayed(Duration(seconds: attempt * 2));
      }
    }

    throw Exception(
      'Unable to upload source video through backend: ${_exceptionText(lastError ?? 'unknown error')}',
    );
  }

  Future<String> _uploadLocalVideoToCloudinary({
    required String filePath,
  }) async {
    final config = _resolveCloudinaryConfig();
    final cloudName = config['cloud_name']!;
    final uploadMode = config['upload_mode'] ?? 'unsigned';
    final uploadPreset = config['upload_preset'];
    final apiKey = config['api_key'];
    final apiSecret = config['api_secret'];

    final localFile = File(filePath);
    if (!localFile.existsSync()) {
      throw Exception('Local video file could not be found for upload.');
    }

    if (!mounted) {
      throw Exception('Upload cancelled.');
    }

    setState(() {
      _uploadStatus = 'uploading_media';
      _uploadMessage = 'Uploading source video...';
      _uploadProgress = 0.08;
    });

    const int maxAttempts = 3;
    Object? lastError;

    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      if (!mounted) {
        throw Exception('Upload cancelled.');
      }

      if (attempt > 1) {
        setState(() {
          _uploadMessage = 'Retrying source upload ($attempt/$maxAttempts)...';
          _uploadProgress = 0.08;
        });
      }

      try {
        final cloudinaryDio = Dio(BaseOptions(validateStatus: (_) => true));
        const folder = 'unibuzz/videos';
        final fields = <String, dynamic>{'folder': folder};

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
            folder: folder,
          );
        }

        fields['file'] = await MultipartFile.fromFile(filePath);
        final formData = FormData.fromMap(fields);

        final response = await cloudinaryDio.post<dynamic>(
          'https://api.cloudinary.com/v1_1/$cloudName/video/upload',
          data: formData,
        );

        final dynamic decoded = response.data;

        if (response.statusCode == null ||
            response.statusCode! < 200 ||
            response.statusCode! >= 300) {
          String? cloudinaryMessage;
          if (decoded is Map && decoded['error'] is Map) {
            final dynamic message = decoded['error']['message'];
            if (message != null && message.toString().trim().isNotEmpty) {
              cloudinaryMessage = message.toString().trim();
            }
          }

          final statusCode = response.statusCode ?? 0;
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

        if (!mounted) {
          throw Exception('Upload cancelled.');
        }

        setState(() {
          _uploadProgress = 0.22;
          _uploadMessage = 'Source upload complete.';
        });

        return secureUrl;
      } catch (error) {
        lastError = error;
        if (attempt == maxAttempts) {
          break;
        }
        await Future.delayed(Duration(seconds: attempt * 2));
      }
    }

    throw Exception(
      'Unable to upload source video after multiple attempts: ${_exceptionText(lastError ?? 'unknown error')}',
    );
  }

  Future<String> _resolveInputUrl({required String uploadFilePath}) async {
    if (_isHttpUrl(uploadFilePath)) {
      return uploadFilePath;
    }

    try {
      // Spec-first path: direct Cloudinary upload.
      return await _uploadLocalVideoToCloudinary(filePath: uploadFilePath);
    } catch (cloudinaryError) {
      try {
        // Compatibility fallback for environments using backend source upload.
        return await _uploadLocalVideoViaBackend(filePath: uploadFilePath);
      } catch (backendFallbackError) {
        final cloudinaryMessage = _exceptionText(cloudinaryError).toLowerCase();
        final backendMessage = _exceptionText(backendFallbackError);

        if (cloudinaryMessage.contains('publishing is not configured') &&
            _isBackendSourceUploadUnavailable(backendFallbackError)) {
          throw Exception(
            'Local upload is unavailable. Configure CLOUDINARY_UPLOAD_PRESET or enable backend source upload.',
          );
        }

        throw Exception(
          'Cloudinary upload failed, and backend fallback failed: $backendMessage',
        );
      }
    }
  }

  Future<void> _onSharePressed() async {
    if (_isBusy) {
      return;
    }

    if (_uploadStatus == 'completed') {
      Navigator.of(context).pop(true);
      return;
    }

    setState(() {
      _isUploading = true;
      _isProcessingQueuedVideo = false;
      _stopProcessingPollRequested = false;
      _processingPollAttempt = 0;
      _processingVideoId = null;
      _uploadStatus = 'uploading_media';
      _uploadMessage = 'Preparing upload...';
      _uploadProgress = 0.02;
    });

    String? trackedVideoId;
    String uploadVideoPath = widget.videoPath;

    try {
      uploadVideoPath = await _prepareVideoPathForUpload();
      _validateUploadConstraintsForPath(uploadVideoPath);

      final caption = _captionController.text.trim();
      final tags = _parseTags(_hashtagController.text);

      final inputUrl = await _resolveInputUrl(uploadFilePath: uploadVideoPath);
      if (!mounted) return;

      setState(() {
        _uploadStatus = 'queueing';
        _uploadMessage = 'Queueing video for processing...';
        _uploadProgress = _uploadProgress < 0.22 ? 0.22 : _uploadProgress;
      });

      Map<String, dynamic>? uploadPayload;
      Object? queueError;
      const int maxQueueAttempts = 3;
      for (int attempt = 1; attempt <= maxQueueAttempts; attempt++) {
        try {
          uploadPayload = await VideoService.uploadVideo(
            inputUrl: inputUrl,
            caption: caption.isEmpty ? null : caption,
            tags: tags.isEmpty ? null : tags,
          );
          break;
        } catch (error) {
          queueError = error;
          if (attempt == maxQueueAttempts) {
            rethrow;
          }

          if (!mounted) {
            throw Exception('Upload cancelled.');
          }

          setState(() {
            _uploadStatus = 'queueing';
            _uploadMessage =
                'Queue request failed. Retrying ($attempt/$maxQueueAttempts)...';
          });
          await Future.delayed(Duration(seconds: attempt));
        }
      }

      if (uploadPayload == null) {
        throw Exception(
          'Unable to queue upload: ${_exceptionText(queueError ?? 'unknown error')}',
        );
      }

      final videoId = _extractVideoId(uploadPayload);
      if (videoId != null && videoId.isNotEmpty) {
        trackedVideoId = videoId;
        await PendingUploadTrackerService.addPendingUpload(videoId);
      }

      final immediateStatus = _extractStatus(uploadPayload);
      if (_isFailedStatus(immediateStatus)) {
        throw Exception(
          _extractMessage(uploadPayload) ??
              'Video processing failed on the server.',
        );
      }

      if (_isCompleteStatus(immediateStatus)) {
        if (trackedVideoId != null) {
          await PendingUploadTrackerService.removePendingUpload(trackedVideoId);
        }

        if (!mounted) return;
        setState(() {
          _uploadStatus = 'completed';
          _uploadProgress = 1.0;
          _uploadMessage = 'Post published successfully!';
          _isUploading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post published successfully!')),
        );
        Navigator.of(context).pop(true);
        return;
      }

      if (videoId == null || videoId.isEmpty) {
        throw Exception(
          _extractMessage(uploadPayload) ??
              'Upload accepted but no video ID was returned.',
        );
      }

      await _pollQueuedVideoStatus(
        videoId: videoId,
        trackedVideoId: trackedVideoId,
      );
      return;
    } catch (error) {
      if (trackedVideoId != null) {
        await PendingUploadTrackerService.removePendingUpload(trackedVideoId);
      }

      if (!mounted) return;

      final message = friendlyError(error);
      setState(() {
        _isUploading = false;
        _isProcessingQueuedVideo = false;
        _processingVideoId = null;
        _processingPollAttempt = 0;
        _uploadStatus = 'failed';
        _uploadMessage = message;
        _uploadProgress = 0.0;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {}
  }

  void _onDiscardPressed() {
    if (_isBusy) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Upload in progress. Please wait until it finishes.'),
        ),
      );
      return;
    }

    showDialog<void>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text(
          'Discard Post?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Are you sure you want to discard this post?',
          style: TextStyle(color: Color(0xFF999999)),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Color(0xFF00B4D8)),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: const Text('Discard', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _stopProcessingPollRequested = true;
    _captionController.dispose();
    _hashtagController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final VideoPlayerController? controller = _videoController;
    final tagCount = _parseTags(_hashtagController.text).length;

    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0B),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            // Top Navigation Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: <Widget>[
                  GestureDetector(
                    onTap: () {
                      if (_isBusy) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Upload in progress. Please wait until it finishes.',
                            ),
                          ),
                        );
                        return;
                      }
                      Navigator.of(context).pop();
                    },
                    child: const Icon(
                      Icons.arrow_back,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const Expanded(
                    child: Text(
                      'New Post',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  // Share Button or Upload Status
                  if (_uploadStatus != 'completed')
                    GestureDetector(
                      onTap: _isBusy ? null : _onSharePressed,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: _isBusy
                                ? const Color(0xFF00B4D8).withValues(alpha: 0.5)
                                : const Color(0xFF00B4D8),
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _isBusy
                              ? (_uploadStatus == 'processing'
                                    ? 'Processing...'
                                    : (_uploadStatus == 'queueing'
                                          ? 'Queueing...'
                                          : 'Uploading...'))
                              : 'Share',
                          style: TextStyle(
                            color: _isBusy
                                ? const Color(0xFF00B4D8).withValues(alpha: 0.5)
                                : const Color(0xFF00B4D8),
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    )
                  else
                    GestureDetector(
                      onTap: _onSharePressed,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00B4D8),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Done',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Scrollable Content
            Expanded(
              child: Stack(
                children: <Widget>[
                  SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        children: <Widget>[
                          // Media Preview Card
                          Center(
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth:
                                    (MediaQuery.of(context).size.width - 32)
                                        .clamp(220.0, 320.0),
                                maxHeight: 420,
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  width: double.infinity,
                                  color: const Color(0xFF1A1A1A),
                                  child: _isInitializing
                                      ? const AspectRatio(
                                          aspectRatio: 9 / 16,
                                          child: Center(
                                            child: CircularProgressIndicator(
                                              color: Color(0xFF00B4D8),
                                            ),
                                          ),
                                        )
                                      : _hasLoadError
                                      ? const AspectRatio(
                                          aspectRatio: 9 / 16,
                                          child: Center(
                                            child: Padding(
                                              padding: EdgeInsets.symmetric(
                                                horizontal: 24,
                                              ),
                                              child: Text(
                                                'Unable to load video preview.',
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ),
                                          ),
                                        )
                                      : AspectRatio(
                                          aspectRatio:
                                              controller!.value.aspectRatio,
                                          child: Stack(
                                            alignment: Alignment.center,
                                            children: <Widget>[
                                              // Video Player
                                              VideoPlayer(controller),
                                              // Progress Indicator or Play/Pause Icon
                                              if (_isUploading)
                                                SizedBox(
                                                  width: 100,
                                                  height: 100,
                                                  child: Stack(
                                                    alignment: Alignment.center,
                                                    children: <Widget>[
                                                      CircularProgressIndicator(
                                                        value: _uploadProgress,
                                                        strokeWidth: 5,
                                                        valueColor:
                                                            const AlwaysStoppedAnimation<
                                                              Color
                                                            >(
                                                              Color(0xFF00B4D8),
                                                            ),
                                                        backgroundColor:
                                                            const Color(
                                                              0xFF333333,
                                                            ),
                                                      ),
                                                      Text(
                                                        '${(_uploadProgress * 100).toInt()}%',
                                                        style: const TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 18,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                )
                                              else
                                                GestureDetector(
                                                  onTap: _togglePlayback,
                                                  child: Container(
                                                    width: 60,
                                                    height: 60,
                                                    decoration: BoxDecoration(
                                                      color: Colors.black
                                                          .withValues(
                                                            alpha: 0.5,
                                                          ),
                                                      shape: BoxShape.circle,
                                                    ),
                                                    child: Icon(
                                                      controller.value.isPlaying
                                                          ? Icons.pause
                                                          : Icons.replay,
                                                      color: const Color(
                                                        0xFF00B4D8,
                                                      ),
                                                      size: 32,
                                                    ),
                                                  ),
                                                ),
                                              // Progress Bar
                                              Positioned(
                                                bottom: 0,
                                                left: 0,
                                                right: 0,
                                                child: ValueListenableBuilder<VideoPlayerValue>(
                                                  valueListenable: controller,
                                                  builder:
                                                      (
                                                        BuildContext context,
                                                        VideoPlayerValue value,
                                                        Widget? child,
                                                      ) {
                                                        final Duration
                                                        duration =
                                                            value.duration;
                                                        final Duration
                                                        position =
                                                            value.position;
                                                        final double progress =
                                                            duration.inMilliseconds >
                                                                0
                                                            ? position.inMilliseconds /
                                                                  duration
                                                                      .inMilliseconds
                                                            : 0.0;

                                                        return Padding(
                                                          padding:
                                                              const EdgeInsets.symmetric(
                                                                horizontal: 12,
                                                                vertical: 8,
                                                              ),
                                                          child: Column(
                                                            children: <Widget>[
                                                              // Duration Labels
                                                              Row(
                                                                mainAxisAlignment:
                                                                    MainAxisAlignment
                                                                        .spaceBetween,
                                                                children: <Widget>[
                                                                  Text(
                                                                    _formatDuration(
                                                                      position,
                                                                    ),
                                                                    style: const TextStyle(
                                                                      color: Color(
                                                                        0xFFBBBBBB,
                                                                      ),
                                                                      fontSize:
                                                                          12,
                                                                    ),
                                                                  ),
                                                                  Text(
                                                                    _formatDuration(
                                                                      duration,
                                                                    ),
                                                                    style: const TextStyle(
                                                                      color: Color(
                                                                        0xFFBBBBBB,
                                                                      ),
                                                                      fontSize:
                                                                          12,
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                              const SizedBox(
                                                                height: 4,
                                                              ),
                                                              // Progress Bar
                                                              ClipRRect(
                                                                borderRadius:
                                                                    BorderRadius.circular(
                                                                      2,
                                                                    ),
                                                                child: LinearProgressIndicator(
                                                                  minHeight: 3,
                                                                  backgroundColor:
                                                                      const Color(
                                                                        0xFF333333,
                                                                      ),
                                                                  valueColor:
                                                                      const AlwaysStoppedAnimation<
                                                                        Color
                                                                      >(
                                                                        Color(
                                                                          0xFF00B4D8,
                                                                        ),
                                                                      ),
                                                                  value:
                                                                      progress,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        );
                                                      },
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          // Caption Label
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Caption',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Caption Box
                          TextField(
                            controller: _captionController,
                            enabled: !_isBusy,
                            maxLines: 4,
                            decoration: InputDecoration(
                              hintText: "What's on your mind?",
                              hintStyle: const TextStyle(
                                color: Color(0xFF666666),
                                fontSize: 14,
                              ),
                              fillColor: const Color(0xFF121212),
                              filled: true,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.all(16),
                            ),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Hashtag Label
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Hashtags',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Hashtag Bar
                          TextField(
                            controller: _hashtagController,
                            enabled: !_isBusy,
                            decoration: InputDecoration(
                              prefixIcon: const Padding(
                                padding: EdgeInsets.only(left: 12, right: 8),
                                child: Text(
                                  '#',
                                  style: TextStyle(
                                    color: Color(0xFF00B4D8),
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              prefixIconConstraints: const BoxConstraints(
                                minWidth: 0,
                                minHeight: 0,
                              ),
                              hintText: 'Add hashtags',
                              hintStyle: const TextStyle(
                                color: Color(0xFF666666),
                                fontSize: 14,
                              ),
                              fillColor: const Color(0xFF1A1A1A),
                              filled: true,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(20),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                            ),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              '$tagCount/10 tags',
                              style: const TextStyle(
                                color: Color(0xFF8B8B8B),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ),
                  // Upload Progress Overlay
                  if (_isBusy)
                    Container(
                      color: Colors.black.withValues(alpha: 0.7),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            // Circular Progress Indicator
                            SizedBox(
                              width: 120,
                              height: 120,
                              child: Stack(
                                alignment: Alignment.center,
                                children: <Widget>[
                                  CircularProgressIndicator(
                                    value: _uploadProgress,
                                    strokeWidth: 6,
                                    valueColor:
                                        const AlwaysStoppedAnimation<Color>(
                                          Color(0xFF00B4D8),
                                        ),
                                    backgroundColor: const Color(0xFF333333),
                                  ),
                                  // Progress Percentage
                                  Text(
                                    '${(_uploadProgress * 100).toInt()}%',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 24,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                            // Status Message
                            Text(
                              _uploadMessage,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (_isProcessingQueuedVideo) ...[
                              const SizedBox(height: 8),
                              Text(
                                'Checked $_processingPollAttempt/$_maxProcessingPollAttempts',
                                style: const TextStyle(
                                  color: Color(0xFFB8B8B8),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                            if (_isProcessingQueuedVideo) ...[
                              const SizedBox(height: 18),
                              OutlinedButton(
                                onPressed: _continueProcessingInBackground,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF00B4D8),
                                  side: const BorderSide(
                                    color: Color(0xFF00B4D8),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 18,
                                    vertical: 10,
                                  ),
                                ),
                                child: const Text('Continue in background'),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Secondary Tool Actions (Bottom)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  // Discard Button
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      GestureDetector(
                        onTap: _onDiscardPressed,
                        child: Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.6),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.delete_outline,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Discard',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
