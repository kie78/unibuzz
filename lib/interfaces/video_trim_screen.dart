import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:unibuzz/interfaces/publish_screen.dart';
import 'package:video_trimmer/video_trimmer.dart';

class VideoTrimScreen extends StatefulWidget {
  const VideoTrimScreen({
    super.key,
    required this.videoPath,
    required this.maxDurationSeconds,
    this.navigateToPublishOnSave = true,
  });

  final String videoPath;
  final int maxDurationSeconds;
  final bool navigateToPublishOnSave;

  @override
  State<VideoTrimScreen> createState() => _VideoTrimScreenState();
}

class _VideoTrimScreenState extends State<VideoTrimScreen> {
  final Trimmer _trimmer = Trimmer();

  double _startValue = 0;
  double _endValue = 20000;
  bool _isPlaying = false;
  bool _isLoaded = false;
  bool _isSaving = false;
  String? _safeInputPath;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadVideo();
    });
  }

  Future<void> _loadVideo() async {
    try {
      final File sourceVideo = File(widget.videoPath);
      if (!sourceVideo.existsSync()) {
        throw Exception('Video file not found.');
      }

      File inputVideo = sourceVideo;
      final String fileName = sourceVideo.uri.pathSegments.isNotEmpty
          ? sourceVideo.uri.pathSegments.last
          : sourceVideo.path;

      // Native retriever is sensitive to special chars in some file names.
      if (RegExp(r'[:,\s]').hasMatch(fileName)) {
        final String safePath =
            '${Directory.systemTemp.path}/unibuzz_trim_input_${DateTime.now().millisecondsSinceEpoch}.mp4';
        inputVideo = await sourceVideo.copy(safePath);
        _safeInputPath = inputVideo.path;
      }

      await _trimmer.loadVideo(videoFile: inputVideo);

      if (!mounted) return;
      setState(() {
        _isLoaded = true;
        _endValue = widget.maxDurationSeconds * 1000.0;
      });
    } catch (error) {
      if (!mounted) return;
      _showToast('Failed to load video: $error');
      Navigator.of(context).pop();
    }
  }

  void _showToast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
      );
  }

  Future<void> _togglePlayback() async {
    if (!_isLoaded) return;

    final bool playbackState = await _trimmer.videoPlaybackControl(
      startValue: _startValue,
      endValue: _endValue,
    );

    if (!mounted) return;
    setState(() {
      _isPlaying = playbackState;
    });
  }

  Future<void> _saveTrimmedVideo() async {
    if (!_isLoaded || _isSaving) return;

    if (_endValue <= _startValue) {
      _showToast('Select a valid trim range.');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final Completer<String?> completer = Completer<String?>();

      await _trimmer.saveTrimmedVideo(
        startValue: _startValue,
        endValue: _endValue,
        videoFolderName: 'Unibuzz',
        videoFileName: 'trim_${DateTime.now().millisecondsSinceEpoch}',
        onSave: (String? outputPath) {
          if (!completer.isCompleted) {
            completer.complete(outputPath);
          }
        },
      );

      final String? outputPath = await completer.future;
      if (!mounted) return;

      if (outputPath == null) {
        _showToast('Unable to save trimmed video.');
        return;
      }

      if (widget.navigateToPublishOnSave) {
        await Navigator.of(context).pushReplacement(
          MaterialPageRoute<bool>(
            builder: (BuildContext context) =>
                PublishScreen(videoPath: outputPath),
          ),
        );
      } else {
        Navigator.of(context).pop(outputPath);
      }
    } catch (error) {
      if (!mounted) return;
      final String details = error.toString();
      if (details.contains('LOAD_ERROR') ||
          details.contains('setDataSource failed')) {
        _showToast(
          'Trimming failed: the source video could not be reopened. Try trimming the original clip again.',
        );
      } else {
        _showToast('Trimming failed: $error');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  String _formatTime(double millisecondsValue) {
    final int seconds = (millisecondsValue / 1000).round();
    final int minutesPart = seconds ~/ 60;
    final int secondsPart = seconds % 60;
    return '${minutesPart.toString().padLeft(2, '0')}:${secondsPart.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    final String? safeInputPath = _safeInputPath;
    if (safeInputPath != null) {
      try {
        final File file = File(safeInputPath);
        if (file.existsSync()) {
          file.deleteSync();
        }
      } catch (_) {
        // Ignore cleanup failures for temporary copies.
      }
    }
    _trimmer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double selectedDuration = (_endValue - _startValue) / 1000;

    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0B),
      body: Stack(
        children: <Widget>[
          // Full-screen video preview
          SafeArea(
            bottom: false,
            child: Column(
              children: <Widget>[
                // Header with close button and centered title
                SizedBox(
                  height: 56,
                  child: Row(
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: GestureDetector(
                          onTap: () => Navigator.of(context).pop(),
                          child: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                      ),
                      const Expanded(
                        child: Text(
                          'TRIM VIDEO',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
                // Video preview area with centered play button
                Expanded(
                  child: _isLoaded
                      ? Stack(
                          alignment: Alignment.center,
                          children: <Widget>[
                            VideoViewer(trimmer: _trimmer),
                            // Centered play/pause button
                            GestureDetector(
                              onTap: _isLoaded ? _togglePlayback : null,
                              child: Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.5),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  _isPlaying ? Icons.pause : Icons.play_arrow,
                                  color: Colors.white,
                                  size: 48,
                                ),
                              ),
                            ),
                          ],
                        )
                      : const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF00B4D8),
                          ),
                        ),
                ),
              ],
            ),
          ),
          // Bottom trimming timeline section (overlaid)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              top: false,
              child: Column(
                children: <Widget>[
                  // Trimming timeline
                  Container(
                    color: Colors.black.withValues(alpha: 0.6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    child: Column(
                      children: <Widget>[
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Drag the left and right handles to trim',
                            style: TextStyle(
                              color: Color(0xFFBBBBBB),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TrimViewer(
                          trimmer: _trimmer,
                          viewerHeight: 60,
                          viewerWidth: MediaQuery.of(context).size.width - 24,
                          maxVideoLength: Duration(
                            seconds: widget.maxDurationSeconds,
                          ),
                          onChangeStart: (double startValue) {
                            setState(() {
                              _startValue = startValue;
                            });
                          },
                          onChangeEnd: (double endValue) {
                            setState(() {
                              _endValue = endValue;
                            });
                          },
                          onChangePlaybackState: (bool playbackState) {
                            setState(() {
                              _isPlaying = playbackState;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  // Status pill showing selected duration
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            '${_formatTime(_startValue)} - ${_formatTime(_endValue)}',
                            style: const TextStyle(
                              color: Color(0xFFBBBBBB),
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '${selectedDuration.toStringAsFixed(1)}s Selected',
                            style: const TextStyle(
                              color: Color(0xFF00B4D8),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
          // Floating action button (bottom-right)
          Positioned(
            bottom: 24,
            right: 24,
            child: FloatingActionButton(
              onPressed: (!_isLoaded || _isSaving) ? null : _saveTrimmedVideo,
              backgroundColor: _isSaving
                  ? const Color(0xFF00B4D8).withValues(alpha: 0.5)
                  : const Color(0xFF00B4D8),
              shape: const CircleBorder(),
              child: _isSaving
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.check, color: Colors.white, size: 28),
            ),
          ),
        ],
      ),
    );
  }
}
