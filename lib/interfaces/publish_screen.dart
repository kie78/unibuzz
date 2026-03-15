import 'dart:io';

import 'package:flutter/material.dart';
import 'package:unibuzz/interfaces/video_trim_screen.dart';
import 'package:video_player/video_player.dart';

class PublishScreen extends StatefulWidget {
  const PublishScreen({super.key, required this.videoPath});

  final String videoPath;

  @override
  State<PublishScreen> createState() => _PublishScreenState();
}

class _PublishScreenState extends State<PublishScreen> {
  VideoPlayerController? _videoController;
  bool _isInitializing = true;
  bool _hasLoadError = false;
  late TextEditingController _captionController;
  late TextEditingController _hashtagController;
  
  // Upload state variables
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  String _uploadStatus = 'idle'; // idle, processing, uploading, completed, failed
  String _uploadMessage = '';

  @override
  void initState() {
    super.initState();
    _captionController = TextEditingController();
    _hashtagController = TextEditingController();
    _initializeVideo();
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

  Future<void> _onSharePressed() async {
    if (_isUploading || _uploadStatus == 'completed') {
      // If already completed, show success and close
      if (_uploadStatus == 'completed') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Post published successfully!'),
            duration: Duration(seconds: 2),
          ),
        );
        Navigator.of(context).pop();
        return;
      }
      return; // Don't allow multiple uploads
    }

    setState(() {
      _isUploading = true;
      _uploadStatus = 'processing';
      _uploadMessage = 'Processing video...';
      _uploadProgress = 0.0;
    });

    // Simulate processing phase (1-2 seconds)
    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;

    setState(() {
      _uploadStatus = 'uploading';
      _uploadMessage = 'Uploading to server...';
    });

    // Simulate uploading with progress
    for (int i = 0; i <= 10; i++) {
      if (!mounted) return;
      await Future.delayed(const Duration(milliseconds: 300));
      setState(() {
        _uploadProgress = i / 10;
      });
    }

    // Simulate backend response
    if (!mounted) return;
    setState(() {
      _uploadStatus = 'completed';
      _uploadMessage = 'Upload complete!';
      _uploadProgress = 1.0;
    });

    // Keep completed state for user feedback
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Post published successfully!'),
        duration: Duration(seconds: 2),
      ),
    );
    Navigator.of(context).pop();
  }

  void _onDiscardPressed() {
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

  Future<void> _onTrimPressed() async {
    final String? trimmedPath = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (BuildContext context) => VideoTrimScreen(
          videoPath: widget.videoPath,
          maxDurationSeconds: 20,
          navigateToPublishOnSave: false,
        ),
      ),
    );

    if (!mounted || trimmedPath == null) return;

    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (BuildContext context) =>
            PublishScreen(videoPath: trimmedPath),
      ),
    );
  }

  @override
  void dispose() {
    _captionController.dispose();
    _hashtagController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final VideoPlayerController? controller = _videoController;

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
                    onTap: () => Navigator.of(context).pop(),
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
                      onTap: _isUploading ? null : _onSharePressed,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: _isUploading
                                ? const Color(0xFF00B4D8).withValues(alpha: 0.5)
                                : const Color(0xFF00B4D8),
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _isUploading ? 'Uploading...' : 'Share',
                          style: TextStyle(
                            color: _isUploading
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
                            maxWidth: (MediaQuery.of(context).size.width - 32)
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
                                                        const AlwaysStoppedAnimation<Color>(
                                                      Color(0xFF00B4D8),
                                                    ),
                                                    backgroundColor:
                                                        const Color(0xFF333333),
                                                  ),
                                                  Text(
                                                    '${(_uploadProgress * 100).toInt()}%',
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 18,
                                                      fontWeight: FontWeight.w700,
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
                                                  color: Colors.black.withValues(
                                                    alpha: 0.5,
                                                  ),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Icon(
                                                  controller.value.isPlaying
                                                      ? Icons.pause
                                                      : Icons.replay,
                                                  color: const Color(0xFF00B4D8),
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
                                                    final Duration duration =
                                                        value.duration;
                                                    final Duration position =
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
                                                                  fontSize: 12,
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
                                                                  fontSize: 12,
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
                                                              value: progress,
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
                      const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ),
                  // Upload Progress Overlay
                  if (_isUploading)
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
                  // Trim Video Button
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      GestureDetector(
                        onTap: _onTrimPressed,
                        child: Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.4),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.content_cut,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Trim Video',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(width: 48),
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
