import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:unibuzz/interfaces/video_upload_screen.dart';
import 'package:unibuzz/services/error_helper.dart';

class CreateScreen extends StatefulWidget {
  const CreateScreen({super.key, this.onUploadSuccess});

  /// Called by VideoUploadScreen when an upload completes. The shell uses this
  /// to switch to the Feed tab and trigger a refresh.
  final VoidCallback? onUploadSuccess;

  @override
  State<CreateScreen> createState() => _CreateScreenState();
}

class _CreateScreenState extends State<CreateScreen> {
  static const int _maxDurationSeconds = 20;

  final ImagePicker _imagePicker = ImagePicker();
  List<CameraDescription> _availableCameras = <CameraDescription>[];

  CameraController? _cameraController;
  CameraLensDirection _activeLensDirection = CameraLensDirection.back;
  Timer? _recordingTimer;

  int _elapsedSeconds = 0;
  bool _isRecordingActive = false;
  bool _isInitializingCamera = true;
  bool _isProcessingVideo = false;
  String? _readyVideoPath;

  @override
  void initState() {
    super.initState();
    _initializeCamera(_activeLensDirection);
  }

  Future<List<CameraDescription>> _loadAvailableCameras() async {
    if (_availableCameras.isNotEmpty) {
      return _availableCameras;
    }
    _availableCameras = await availableCameras();
    return _availableCameras;
  }

  Future<bool> _initializeCamera(
    CameraLensDirection lensDirection, {
    bool showUnavailableLensMessage = false,
  }) async {
    try {
      final List<CameraDescription> cameras = await _loadAvailableCameras();
      if (cameras.isEmpty) {
        if (!mounted) return false;
        setState(() {
          _isInitializingCamera = false;
        });
        _showToast('No camera found on this device.');
        return false;
      }

      CameraDescription? selectedCamera;
      for (final CameraDescription camera in cameras) {
        if (camera.lensDirection == lensDirection) {
          selectedCamera = camera;
          break;
        }
      }

      if (selectedCamera == null) {
        if (!mounted) {
          return false;
        }
        setState(() {
          _isInitializingCamera = false;
        });

        if (showUnavailableLensMessage) {
          _showToast(
            lensDirection == CameraLensDirection.front
                ? 'Front camera is not available on this device.'
                : 'Rear camera is not available on this device.',
          );
        }
        return false;
      }

      final CameraDescription targetCamera = selectedCamera;

      final CameraController? previousController = _cameraController;
      final CameraController controller = CameraController(
        targetCamera,
        ResolutionPreset.high,
        enableAudio: true,
      );

      await previousController?.dispose();
      await controller.initialize();

      if (!mounted) {
        await controller.dispose();
        return false;
      }

      setState(() {
        _cameraController = controller;
        _activeLensDirection = targetCamera.lensDirection;
        _isInitializingCamera = false;
      });

      return true;
    } on CameraException catch (error) {
      if (!mounted) return false;
      setState(() {
        _isInitializingCamera = false;
      });
      _showToast('Camera access failed: ${error.description ?? error.code}');
      return false;
    } catch (error) {
      if (!mounted) return false;
      setState(() {
        _isInitializingCamera = false;
      });
      _showToast('Camera initialization failed: ${friendlyError(error)}');
      return false;
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

  Future<void> _toggleCamera() async {
    if (_isInitializingCamera) {
      _showToast('Camera is still initializing. Please wait.');
      return;
    }

    if (_isProcessingVideo) {
      _showToast('Please wait while video processing is in progress.');
      return;
    }

    if (_isRecordingActive) {
      _showToast('Pause or publish current recording before flipping camera.');
      return;
    }

    final CameraLensDirection nextLensDirection =
        _activeLensDirection == CameraLensDirection.back
        ? CameraLensDirection.front
        : CameraLensDirection.back;

    setState(() {
      _isInitializingCamera = true;
    });

    final bool switched = await _initializeCamera(
      nextLensDirection,
      showUnavailableLensMessage: true,
    );

    if (!mounted || !switched) return;

    _showToast(
      _activeLensDirection == CameraLensDirection.front
          ? 'Front camera active'
          : 'Rear camera active',
    );
  }

  void _startProgressTimer() {
    _recordingTimer?.cancel();
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (
      Timer timer,
    ) async {
      if (!mounted) {
        timer.cancel();
        return;
      }

      final int nextValue = _elapsedSeconds + 1;
      if (nextValue >= _maxDurationSeconds) {
        setState(() {
          _elapsedSeconds = _maxDurationSeconds;
        });
        timer.cancel();
        await _stopRecording(openTrimTool: true);
        return;
      }

      setState(() {
        _elapsedSeconds = nextValue;
      });
    });
  }

  Future<void> _startRecording() async {
    final CameraController? controller = _cameraController;
    if (controller == null ||
        !controller.value.isInitialized ||
        _isProcessingVideo) {
      return;
    }

    try {
      if (controller.value.isRecordingVideo) return;

      await controller.startVideoRecording();

      if (!mounted) return;
      setState(() {
        _isRecordingActive = true;
        _elapsedSeconds = 0;
        _readyVideoPath = null;
      });
      _startProgressTimer();
      _showToast('Recording started');
    } on CameraException catch (error) {
      _showToast(
        'Unable to start recording: ${error.description ?? error.code}',
      );
    }
  }

  Future<void> _stopRecording({required bool openTrimTool}) async {
    final CameraController? controller = _cameraController;
    if (controller == null ||
        !controller.value.isRecordingVideo ||
        _isProcessingVideo) {
      return;
    }

    _recordingTimer?.cancel();

    setState(() {
      _isProcessingVideo = true;
    });

    try {
      final XFile capturedVideo = await controller.stopVideoRecording();

      if (!mounted) return;
      setState(() {
        _isRecordingActive = false;
      });

      _showToast('Max video length is 20 seconds.');

      final outputPath = capturedVideo.path;

      if (!mounted) return;
      setState(() {
        _readyVideoPath = outputPath;
      });
      _showToast('Video ready to publish');
    } on CameraException catch (error) {
      if (!mounted) return;
      _showToast(
        'Unable to finalize recording: ${error.description ?? error.code}',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingVideo = false;
          _elapsedSeconds = 0;
        });
      }
    }
  }

  Future<void> _discardRecording() async {
    _recordingTimer?.cancel();

    final CameraController? controller = _cameraController;
    if (controller != null && controller.value.isRecordingVideo) {
      try {
        await controller.stopVideoRecording();
      } on CameraException {
        // Ignore stop errors when clearing draft state.
      }
    }

    if (!mounted) return;
    setState(() {
      _isRecordingActive = false;
      _isProcessingVideo = false;
      _elapsedSeconds = 0;
      _readyVideoPath = null;
    });
  }

  Future<void> _openGallery() async {
    if (_isProcessingVideo) return;
    if (_isRecordingActive) {
      _showToast('Pause or publish current recording before opening gallery.');
      return;
    }

    try {
      final XFile? selectedVideo = await _imagePicker.pickVideo(
        source: ImageSource.gallery,
      );

      if (!mounted || selectedVideo == null) return;

      await Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(
          builder: (_) => VideoUploadScreen(
            initialVideoPath: selectedVideo.path,
            onUploadSuccess: widget.onUploadSuccess,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      _showToast('Unable to access gallery: ${friendlyError(error)}');
    }
  }

  Future<void> _onRecordButtonPressed() async {
    if (_isInitializingCamera || _isProcessingVideo) return;

    if (!_isRecordingActive) {
      await _startRecording();
      return;
    }

    await _stopRecording(openTrimTool: true);
  }

  Future<void> _navigateToPublish() async {
    if (_isProcessingVideo) return;

    if (_isRecordingActive) {
      await _stopRecording(openTrimTool: true);
    }

    if (!mounted) return;

    try {
      await Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(
          builder: (_) => VideoUploadScreen(
            initialVideoPath: _readyVideoPath,
            onUploadSuccess: widget.onUploadSuccess,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      _showToast('Unable to open publish flow: ${friendlyError(error)}');
    }
  }

  Future<void> _handleClose() async {
    await _discardRecording();

    if (!mounted) return;
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return;
    }

    _showToast('Draft cleared');
  }

  String _formatTime(int seconds) {
    final int mins = seconds ~/ 60;
    final int secs = seconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  Widget _buildCameraPreview() {
    if (_isInitializingCamera) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF00B4D8)),
      );
    }

    final CameraController? controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) {
      return Container(
        color: Colors.black87,
        alignment: Alignment.center,
        child: const Icon(
          Icons.videocam_off_outlined,
          size: 80,
          color: Colors.white54,
        ),
      );
    }

    final Size? previewSize = controller.value.previewSize;
    if (previewSize == null) {
      final double fallbackAspectRatio = controller.value.aspectRatio == 0
          ? (9 / 16)
          : controller.value.aspectRatio;

      return Center(
        child: AspectRatio(
          aspectRatio: fallbackAspectRatio,
          child: CameraPreview(
            controller,
            key: ValueKey<int>(controller.hashCode),
          ),
        ),
      );
    }

    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: previewSize.height,
          height: previewSize.width,
          child: CameraPreview(
            controller,
            key: ValueKey<int>(controller.hashCode),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double progressPercent = (_elapsedSeconds / _maxDurationSeconds)
        .clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            _buildCameraPreview(),

            // Top controls
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  GestureDetector(
                    onTap: _handleClose,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF808080).withValues(alpha: 0.45),
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: _toggleCamera,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF808080).withValues(alpha: 0.45),
                      ),
                      child: const Icon(
                        Icons.flip_camera_android,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Progress and timestamp
            Positioned(
              top: 70,
              left: 16,
              right: 16,
              child: Column(
                children: <Widget>[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: progressPercent,
                      minHeight: 4,
                      backgroundColor: Colors.grey.withValues(alpha: 0.35),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFF00B4D8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      '${_formatTime(_elapsedSeconds)} / ${_formatTime(_maxDurationSeconds)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Record trigger
            Positioned(
              bottom: 120,
              left: 0,
              right: 0,
              child: Column(
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00B4D8),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _isRecordingActive
                          ? 'REC'
                          : (_readyVideoPath != null ? 'READY' : 'REC'),
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _onRecordButtonPressed,
                    child: Stack(
                      alignment: Alignment.center,
                      children: <Widget>[
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFF00B4D8),
                              width: 4,
                            ),
                          ),
                        ),
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _isRecordingActive
                                ? const Color(0xFF00B4D8)
                                : Colors.white,
                          ),
                          child: _isRecordingActive
                              ? const Icon(
                                  Icons.stop,
                                  color: Colors.white,
                                  size: 28,
                                )
                              : null,
                        ),
                        if (_isProcessingVideo)
                          const SizedBox(
                            width: 32,
                            height: 32,
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              color: Color(0xFF00B4D8),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Bottom actions
            Positioned(
              bottom: 16,
              left: 24,
              right: 24,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  GestureDetector(
                    onTap: _openGallery,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.grey.withValues(alpha: 0.4),
                          ),
                          padding: const EdgeInsets.all(12),
                          child: const Icon(
                            Icons.image_outlined,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'GALLERY',
                          style: TextStyle(
                            color: Color(0xFF999999),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: _navigateToPublish,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.grey.withValues(alpha: 0.4),
                          ),
                          padding: const EdgeInsets.all(12),
                          child: const Icon(
                            Icons.chevron_right,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'PUBLISH',
                          style: TextStyle(
                            color: Color(0xFF999999),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
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
