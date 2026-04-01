import 'dart:async';

import 'package:video_player/video_player.dart';

/// Manages a pool of VideoPlayerController instances for efficient preloading.
/// Maintains controllers for the current, next, and previous video pages.
class VideoPlayerPoolService {
  VideoPlayerPoolService({required this.videoUrls});

  final List<String> videoUrls;
  final Map<int, VideoPlayerController> _controllers =
      <int, VideoPlayerController>{};
  int _currentPageIndex = 0;

  /// Gets a controller for the video at the given index.
  /// Initializes it if not already cached.
  Future<VideoPlayerController?> getController(int index) async {
    if (index < 0 || index >= videoUrls.length) {
      return null;
    }

    final videoUrl = videoUrls[index].trim();
    if (videoUrl.isEmpty) {
      return null;
    }

    // Return existing controller if cached
    if (_controllers.containsKey(index)) {
      return _controllers[index];
    }

    try {
      final uri = Uri.tryParse(videoUrl);
      if (uri == null || uri.host.isEmpty) {
        return null;
      }

      final controller = VideoPlayerController.networkUrl(uri);
      await controller.initialize();
      await controller.setLooping(true);
      _controllers[index] = controller;
      return controller;
    } catch (_) {
      return null;
    }
  }

  /// Preloads the next two video controllers in the background.
  Future<void> preloadNext(int currentIndex) async {
    _currentPageIndex = currentIndex;

    // Preload next two pages
    for (int i = 1; i <= 2; i++) {
      if (currentIndex + i < videoUrls.length) {
        unawaited(getController(currentIndex + i));
      }
    }

    // Cleanup pages further than 2 away
    _cleanupFarPages(currentIndex);
  }

  /// Preloads previous page and the next two pages around current index.
  Future<void> preloadAround(int currentIndex) async {
    _currentPageIndex = currentIndex;

    if (currentIndex - 1 >= 0) {
      unawaited(getController(currentIndex - 1));
    }

    for (int i = 1; i <= 2; i++) {
      if (currentIndex + i < videoUrls.length) {
        unawaited(getController(currentIndex + i));
      }
    }

    _cleanupFarPages(currentIndex);
  }

  /// Disposes controllers that are more than 2 pages away from current.
  void _cleanupFarPages(int currentIndex) {
    final keysToDispose = <int>[];
    for (final index in _controllers.keys) {
      if ((index - currentIndex).abs() > 2) {
        keysToDispose.add(index);
      }
    }

    for (final index in keysToDispose) {
      _controllers[index]?.dispose();
      _controllers.remove(index);
    }
  }

  /// Pauses all active controllers.
  Future<void> pauseAll() async {
    for (final controller in _controllers.values) {
      if (!controller.value.isInitialized) {
        continue;
      }
      if (controller.value.isPlaying) {
        await controller.pause();
      }
    }
  }

  /// Plays the controller at the given index (pauses others).
  Future<void> playOnly(int index) async {
    for (final entry in _controllers.entries) {
      if (entry.key == index) {
        if (!entry.value.value.isPlaying && entry.value.value.isInitialized) {
          await entry.value.play();
        }
      } else {
        if (entry.value.value.isPlaying) {
          await entry.value.pause();
        }
      }
    }
  }

  /// Disposes all cached controllers.
  Future<void> dispose() async {
    for (final controller in _controllers.values) {
      await controller.dispose();
    }
    _controllers.clear();
  }

  /// Gets the number of cached controllers.
  int get cachedCount => _controllers.length;

  /// Gets the current page index.
  int get currentPageIndex => _currentPageIndex;
}
