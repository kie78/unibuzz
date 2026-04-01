import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:unibuzz/services/feed_cache_service.dart';
import 'package:unibuzz/services/pending_upload_tracker_service.dart';
import 'package:unibuzz/services/video_service.dart';
import 'package:unibuzz/services/video_upload_service.dart';

/// Three-step video upload screen:
///   1. Pick / record → validate → compress → upload to Cloudinary
///   2. Submit Cloudinary URL to UniBuzz backend
///   3. Poll processing status non-blocking in background
class VideoUploadScreen extends StatefulWidget {
  const VideoUploadScreen({super.key, this.initialVideoPath, this.onUploadSuccess});

  /// If provided, the screen starts with this video already selected.
  final String? initialVideoPath;

  /// Called just before popping on a successful upload. The shell uses this
  /// to switch to the Feed tab and trigger a refresh.
  final VoidCallback? onUploadSuccess;

  @override
  State<VideoUploadScreen> createState() => _VideoUploadScreenState();
}

class _VideoUploadScreenState extends State<VideoUploadScreen> {
  // ─── Controllers ────────────────────────────────────────────────────────
  final TextEditingController _captionController = TextEditingController();
  final TextEditingController _hashtagController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  // ─── Picked video ────────────────────────────────────────────────────────
  String? _pickedVideoPath;

  // ─── Upload state ────────────────────────────────────────────────────────
  /// idle | compressing | uploading | submitting | processing | done | error
  String _phase = 'idle';
  double _uploadProgress = 0.0;
  String _statusMessage = '';
  String? _errorMessage;

  // ─── Cleanup handles ─────────────────────────────────────────────────────
  String? _tempCompressedPath;
  Timer? _pollingTimer;

  // ─── Tag parsing ─────────────────────────────────────────────────────────
  List<String> get _tags {
    final raw = _hashtagController.text;
    final parts = raw.split(RegExp(r'[\s,]+'));
    final result = <String>{};
    for (final part in parts) {
      final cleaned = part.replaceAll(RegExp(r'^#+'), '').trim();
      if (cleaned.isNotEmpty) result.add(cleaned.toLowerCase());
      if (result.length >= 10) break;
    }
    return result.toList();
  }

  bool get _isBusy =>
      _phase == 'compressing' ||
      _phase == 'uploading' ||
      _phase == 'submitting' ||
      _phase == 'processing';

  // ─── Lifecycle ───────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _hashtagController.addListener(() => setState(() {}));
    if (widget.initialVideoPath != null) {
      _pickedVideoPath = widget.initialVideoPath;
    }
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _captionController.dispose();
    _hashtagController.dispose();
    _deleteTempCompressed();
    super.dispose();
  }

  void _deleteTempCompressed() {
    final path = _tempCompressedPath;
    _tempCompressedPath = null;
    if (path == null) return;
    try {
      final f = File(path);
      if (f.existsSync()) f.deleteSync();
    } catch (_) {}
  }

  // ─── Video picking ───────────────────────────────────────────────────────

  Future<void> _pickFromGallery() async {
    if (_isBusy) return;
    try {
      final XFile? file = await _picker.pickVideo(source: ImageSource.gallery);
      if (!mounted || file == null) return;
      setState(() {
        _pickedVideoPath = file.path;
        _phase = 'idle';
        _errorMessage = null;
      });
    } catch (e) {
      _showSnackBar('Could not access gallery: $e');
    }
  }

  Future<void> _recordWithCamera() async {
    if (_isBusy) return;
    try {
      final XFile? file = await _picker.pickVideo(
        source: ImageSource.camera,
        maxDuration: const Duration(minutes: 5),
      );
      if (!mounted || file == null) return;
      setState(() {
        _pickedVideoPath = file.path;
        _phase = 'idle';
        _errorMessage = null;
      });
    } catch (e) {
      _showSnackBar('Could not access camera: $e');
    }
  }

  // ─── Upload pipeline ─────────────────────────────────────────────────────

  Future<void> _startUpload() async {
    final videoPath = _pickedVideoPath;
    if (videoPath == null) {
      _showSnackBar('Please pick or record a video first.');
      return;
    }
    if (_isBusy) return;

    setState(() {
      _phase = 'uploading';
      _uploadProgress = 0.0;
      _statusMessage = 'Validating video…';
      _errorMessage = null;
    });

    try {
      // ── Validate size ────────────────────────────────────────────────────
      VideoUploadService.validateFileSize(videoPath);

      final String pathToUpload = videoPath;

      // ── STEP 1b: Upload to Cloudinary ────────────────────────────────────
      setState(() {
        _phase = 'uploading';
        _uploadProgress = 0.0;
        _statusMessage = 'Uploading to cloud…';
      });

      final CloudinaryUploadResult cloudResult =
          await VideoUploadService.uploadToCloudinary(
            filePath: pathToUpload,
            onProgress: (p) {
              if (mounted) {
                setState(() {
                  _uploadProgress = p;
                  _statusMessage = 'Uploading… ${(p * 100).toInt()}%';
                });
              }
            },
          );

      if (!mounted) return;

      // ── STEP 2: Submit URL to backend ────────────────────────────────────
      setState(() {
        _phase = 'submitting';
        _uploadProgress = 1.0;
        _statusMessage = 'Queuing video for processing…';
      });

      final BackendUploadResult backendResult =
          await VideoUploadService.submitToBackend(
            secureUrl: cloudResult.secureUrl,
            caption: _captionController.text.trim().isEmpty
                ? null
                : _captionController.text.trim(),
            tags: _tags.isEmpty ? null : _tags,
          );

      if (!mounted) return;

      // ── STEP 3: Poll processing status ───────────────────────────────────
      setState(() {
        _phase = 'processing';
        _statusMessage = 'Video is being processed…';
      });

      await PendingUploadTrackerService.addPendingUpload(backendResult.videoId);
      if (!mounted) return;

      _pollingTimer = VideoUploadService.startProcessingPoller(
        videoId: backendResult.videoId,
        onStatus: (status) {
          if (!mounted) return;
          setState(() => _statusMessage = 'Processing: $status');
        },
        onDone: (finalStatus) async {
          if (!mounted) return;

          if (finalStatus == 'failed') {
            await PendingUploadTrackerService.removePendingUpload(
              backendResult.videoId,
            );
            if (!mounted) return;
            setState(() {
              _phase = 'idle';
              _statusMessage = '';
              _errorMessage = null;
              _uploadProgress = 0.0;
            });
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(
                  content: const Text('Video upload failed. Please try again.'),
                  action: SnackBarAction(
                    label: 'Retry',
                    onPressed: () {
                      if (mounted) _startUpload();
                    },
                  ),
                ),
              );
            return;
          }

          if (finalStatus == 'timeout') {
            await PendingUploadTrackerService.removePendingUpload(
              backendResult.videoId,
            );
            if (!mounted) return;
            setState(() {
              _phase = 'done';
              _statusMessage =
                  'Something went wrong processing your video. Please try uploading again.';
            });
            return;
          }

          // Processing succeeded — wait 5 s for Redis cache to settle,
          // then warm the feed cache and navigate away.
          setState(() => _statusMessage = 'Video is live! Loading feed…');
          await Future.delayed(const Duration(seconds: 5));
          if (!mounted) return;

          try {
            final freshVideos = await VideoService.fetchFeed();
            if (!mounted) return;
            if (freshVideos.isNotEmpty) {
              await FeedCacheService.cacheResponse(freshVideos);
            }
          } catch (_) {
            // Cache warm-up is best-effort; do not block navigation.
          }

          await PendingUploadTrackerService.removePendingUpload(
            backendResult.videoId,
          );
          if (!mounted) return;
          // Notify the shell to switch to the Feed tab and refresh before pop.
          widget.onUploadSuccess?.call();
          Navigator.of(context).pop(true);
        },
      );
    } catch (e) {
      final message = e.toString().replaceFirst('Exception: ', '').trim();
      if (!mounted) return;
      setState(() {
        _phase = 'error';
        _errorMessage = message;
        _uploadProgress = 0.0;
        _statusMessage = '';
      });
      _showSnackBar(message);
    } finally {
      _deleteTempCompressed();
    }
  }

  // ─── UI helpers ──────────────────────────────────────────────────────────

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _confirmDiscard() {
    if (_isBusy) {
      _showSnackBar('Upload in progress. Please wait.');
      return;
    }
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text(
          'Discard Post?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Are you sure you want to go back?',
          style: TextStyle(color: Color(0xFF999999)),
        ),
        actions: [
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

  // ─── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final tagCount = _tags.length;
    final bool hasVideo = _pickedVideoPath != null;

    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0B),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Video picker area ──────────────────────────────────
                    _buildVideoPickerArea(hasVideo),
                    const SizedBox(height: 20),

                    // ── Pick / Record buttons ──────────────────────────────
                    Row(
                      children: [
                        Expanded(
                          child: _ActionButton(
                            icon: Icons.photo_library_outlined,
                            label: 'Gallery',
                            onTap: _isBusy ? null : _pickFromGallery,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _ActionButton(
                            icon: Icons.videocam_outlined,
                            label: 'Record',
                            onTap: _isBusy ? null : _recordWithCamera,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // ── Caption ───────────────────────────────────────────
                    const Text(
                      'Caption',
                      style: TextStyle(
                        color: Color(0xFFBBBBBB),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _captionController,
                      enabled: !_isBusy,
                      maxLines: 3,
                      maxLength: 300,
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration('Write a caption…'),
                    ),
                    const SizedBox(height: 16),

                    // ── Hashtags ──────────────────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Hashtags',
                          style: TextStyle(
                            color: Color(0xFFBBBBBB),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          '$tagCount/10',
                          style: TextStyle(
                            color: tagCount >= 10
                                ? Colors.red
                                : const Color(0xFF777777),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _hashtagController,
                      enabled: !_isBusy,
                      style: const TextStyle(color: Colors.white),
                      onChanged: (value) {
                        // Strip leading # characters as the user types.
                        final stripped = value.replaceAll(
                          RegExp(r'(?<!\w)#+(?=\w)'),
                          '',
                        );
                        if (stripped != value) {
                          _hashtagController
                            ..text = stripped
                            ..selection = TextSelection.collapsed(
                              offset: stripped.length,
                            );
                        }
                      },
                      decoration: _inputDecoration(
                        'Add tags separated by spaces or commas',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '# symbols are stripped automatically',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.35),
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 28),

                    // ── Upload progress ───────────────────────────────────
                    if (_isBusy) ...[
                      _buildProgressSection(),
                      const SizedBox(height: 20),
                    ],

                    // ── Error message ─────────────────────────────────────
                    if (_phase == 'error' && _errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          border: Border.all(
                            color: Colors.red.withValues(alpha: 0.4),
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                            color: Colors.redAccent,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // ── Upload button ─────────────────────────────────────
                    _buildUploadButton(hasVideo),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Sub-widgets ─────────────────────────────────────────────────────────

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          GestureDetector(
            onTap: _confirmDiscard,
            child: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
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
          // Balance the row
          const SizedBox(width: 24),
        ],
      ),
    );
  }

  Widget _buildVideoPickerArea(bool hasVideo) {
    return GestureDetector(
      onTap: _isBusy ? null : _pickFromGallery,
      child: Container(
        height: 200,
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          border: Border.all(
            color: _pickedVideoPath != null
                ? const Color(0xFF00B4D8)
                : const Color(0xFF333333),
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: hasVideo
            ? Stack(
                alignment: Alignment.center,
                children: [
                  const Icon(
                    Icons.movie_outlined,
                    color: Color(0xFF00B4D8),
                    size: 48,
                  ),
                  Positioned(
                    bottom: 12,
                    left: 0,
                    right: 0,
                    child: Text(
                      _pickedVideoPath!.split('/').last,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF888888),
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(
                    Icons.add_circle_outline,
                    color: Color(0xFF555555),
                    size: 44,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Tap to pick a video',
                    style: TextStyle(color: Color(0xFF666666), fontSize: 14),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildProgressSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _statusMessage,
          style: const TextStyle(color: Color(0xFFBBBBBB), fontSize: 13),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value:
                _phase == 'compressing' ||
                    _phase == 'submitting' ||
                    _phase == 'processing'
                ? null // indeterminate
                : _uploadProgress,
            minHeight: 6,
            backgroundColor: const Color(0xFF333333),
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00B4D8)),
          ),
        ),
        if (_phase == 'uploading') ...[
          const SizedBox(height: 4),
          Text(
            '${(_uploadProgress * 100).toInt()}% uploaded',
            style: const TextStyle(color: Color(0xFF777777), fontSize: 11),
          ),
        ],
      ],
    );
  }

  Widget _buildUploadButton(bool hasVideo) {
    final bool enabled = hasVideo && !_isBusy;
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: enabled ? _startUpload : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF00B4D8),
          disabledBackgroundColor: const Color(0xFF1A4A55),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: _isBusy
            ? const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Uploading…',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              )
            : Text(
                hasVideo ? 'Upload Video' : 'Pick a video first',
                style: TextStyle(
                  color: enabled ? Colors.white : Colors.white38,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF555555)),
      filled: true,
      fillColor: const Color(0xFF1A1A1A),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF333333)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF333333)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF00B4D8)),
      ),
      counterStyle: const TextStyle(color: Color(0xFF555555)),
    );
  }
}

// ─── Helper widget ────────────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          border: Border.all(
            color: enabled ? const Color(0xFF00B4D8) : const Color(0xFF333333),
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: enabled
                  ? const Color(0xFF00B4D8)
                  : const Color(0xFF444444),
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: enabled
                    ? const Color(0xFF00B4D8)
                    : const Color(0xFF444444),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
