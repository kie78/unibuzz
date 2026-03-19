import 'package:flutter/material.dart';
import 'package:unibuzz/interfaces/comment_section.dart';
import 'package:unibuzz/interfaces/full_screen_view.dart';
import 'package:unibuzz/interfaces/report_screen.dart';
import 'package:unibuzz/services/auth_service.dart';
import 'package:unibuzz/services/feed_cache_service.dart';
import 'package:unibuzz/services/pending_upload_tracker_service.dart';
import 'package:unibuzz/services/video_player_pool_service.dart';
import 'package:unibuzz/services/video_service.dart';
import 'package:video_player/video_player.dart';

Widget _buildAvatarWidget({
  required double radius,
  required String? imageUrl,
  required Color backgroundColor,
  required Color iconColor,
  required double iconSize,
}) {
  final normalizedUrl = imageUrl?.trim();
  final hasImage = normalizedUrl != null && normalizedUrl.isNotEmpty;

  return CircleAvatar(
    radius: radius,
    backgroundColor: backgroundColor,
    child: hasImage
        ? ClipOval(
            child: Image.network(
              normalizedUrl,
              width: radius * 2,
              height: radius * 2,
              fit: BoxFit.cover,
              errorBuilder:
                  (BuildContext context, Object error, StackTrace? stackTrace) {
                    return Icon(Icons.person, color: iconColor, size: iconSize);
                  },
            ),
          )
        : Icon(Icons.person, color: iconColor, size: iconSize),
  );
}

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> with WidgetsBindingObserver {
  static const Duration _avatarSyncInterval = Duration(seconds: 20);

  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _videos = <Map<String, dynamic>>[];

  String? _currentUserAvatarUrl;
  bool _isFetchingCurrentUserAvatar = false;
  DateTime? _lastCurrentUserAvatarSyncAt;

  bool _isSyncingPendingUploads = false;

  final PageController _pageController = PageController();
  VideoPlayerPoolService? _videoPlayerPool;

  int _currentPageIndex = 0;
  int _videoPoolEpoch = 0;
  bool _isMuted = true;

  final Map<int, VideoPlayerController?> _controllersByIndex =
      <int, VideoPlayerController?>{};
  final Set<int> _controllerLoadInProgress = <int>{};
  final Set<int> _preloadTriggeredIndices = <int>{};

  VideoPlayerController? _progressController;
  VoidCallback? _progressListener;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadFeed();
    _loadCurrentUserAvatar(force: true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _detachProgressListener();
    _videoPlayerPool?.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _pauseAllVideos();
      return;
    }

    if (state == AppLifecycleState.resumed) {
      _resumeCurrentVideo();
    }
  }

  Future<void> _pauseAllVideos() async {
    await _videoPlayerPool?.pauseAll();
  }

  Future<void> _resumeCurrentVideo() async {
    if (_videos.isEmpty) return;
    await _videoPlayerPool?.playOnly(_currentPageIndex);
  }

  Future<void> _toggleMute() async {
    setState(() {
      _isMuted = !_isMuted;
    });
    await _applyMuteStateToControllers();
  }

  Future<void> _applyMuteStateToControllers() async {
    final targetVolume = _isMuted ? 0.0 : 1.0;
    for (final controller in _controllersByIndex.values) {
      if (controller == null || !controller.value.isInitialized) {
        continue;
      }
      try {
        await controller.setVolume(targetVolume);
      } catch (_) {
        // Ignore volume updates for disposed/failed controllers.
      }
    }
  }

  String? _readNestedProfileString(Map<String, dynamic> source, String path) {
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

    if (current is String && current.trim().isNotEmpty) {
      return current.trim();
    }
    return null;
  }

  String? _extractCurrentUserAvatarUrl(Map<String, dynamic> profile) {
    const paths = <String>[
      'profile_photo_url',
      'avatar_url',
      'photo_url',
      'image_url',
      'user.profile_photo_url',
      'user.avatar_url',
      'profile.photo_url',
      'data.profile_photo_url',
      'data.avatar_url',
    ];

    for (final path in paths) {
      final value = _readNestedProfileString(profile, path);
      if (value != null) {
        return value;
      }
    }
    return null;
  }

  Future<void> _loadCurrentUserAvatar({bool force = false}) async {
    if (_isFetchingCurrentUserAvatar) return;

    final lastSyncAt = _lastCurrentUserAvatarSyncAt;
    final shouldThrottle =
        !force &&
        lastSyncAt != null &&
        DateTime.now().difference(lastSyncAt) < _avatarSyncInterval;
    if (shouldThrottle) {
      return;
    }

    _isFetchingCurrentUserAvatar = true;
    try {
      final profile = await AuthService.getCurrentUserProfile();
      final avatarUrl = _extractCurrentUserAvatarUrl(profile);
      if (!mounted) return;

      if (_currentUserAvatarUrl == avatarUrl) {
        return;
      }

      setState(() {
        _currentUserAvatarUrl = avatarUrl;
      });
    } catch (_) {
      // Keep fallback icon when profile fetch fails.
    } finally {
      _isFetchingCurrentUserAvatar = false;
      _lastCurrentUserAvatarSyncAt = DateTime.now();
    }
  }

  Future<void> _refreshFeed() async {
    await Future.wait<void>(<Future<void>>[
      _loadFeed(preserveExisting: true),
      _loadCurrentUserAvatar(force: true),
    ]);
  }

  String? _extractVideoId(dynamic video) {
    if (video is! Map<String, dynamic>) return null;
    final id = video['id'];
    if (id is String && id.isNotEmpty) {
      return id;
    }
    return null;
  }

  String? _extractPlayableVideoUrl(Map<String, dynamic> video) {
    final value = video['video_url'];
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    return null;
  }

  List<Map<String, dynamic>> _normalizeVideos(List<dynamic> rawVideos) {
    final uniqueVideos = <Map<String, dynamic>>[];
    final seenVideoIds = <String>{};

    for (final video in rawVideos) {
      if (video is! Map) {
        continue;
      }

      final normalized = Map<String, dynamic>.from(video);
      final id = _extractVideoId(normalized);

      if (id == null || seenVideoIds.add(id)) {
        uniqueVideos.add(normalized);
      }
    }

    return uniqueVideos;
  }

  Future<void> _loadFeed({
    bool preserveExisting = false,
    bool checkPendingUploads = true,
  }) async {
    bool showedCachedFeed = false;

    if (!preserveExisting) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    } else {
      setState(() {
        _error = null;
      });
    }

    try {
      if (!preserveExisting) {
        final cached = await FeedCacheService.getCachedFeed();
        if (!mounted) return;

        if (cached != null && cached.isNotEmpty) {
          final cachedVideos = _normalizeVideos(cached);
          if (cachedVideos.isNotEmpty) {
            setState(() {
              _videos = cachedVideos;
              _isLoading = false;
            });
            await _resetVideoPoolForFeed(preserveCurrentPage: false);
            showedCachedFeed = true;
          }
        }
      }

      final freshVideos = await VideoService.fetchFeed();
      if (!mounted) return;

      final normalizedFreshVideos = _normalizeVideos(freshVideos);

      setState(() {
        _videos = normalizedFreshVideos;
        _isLoading = false;
        _error = null;
      });

      await FeedCacheService.cacheResponse(normalizedFreshVideos);
      await _resetVideoPoolForFeed(preserveCurrentPage: preserveExisting);

      if (checkPendingUploads) {
        await _syncPendingUploads();
      }
    } catch (error) {
      if (!mounted) return;

      final message = error.toString().replaceFirst('Exception: ', '').trim();
      if ((preserveExisting || showedCachedFeed) && _videos.isNotEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
        return;
      }

      setState(() {
        _error = message;
        _isLoading = false;
      });
    }
  }

  Future<void> _resetVideoPoolForFeed({
    required bool preserveCurrentPage,
  }) async {
    _detachProgressListener();

    final previousPool = _videoPlayerPool;
    _videoPlayerPool = null;

    _controllersByIndex.clear();
    _controllerLoadInProgress.clear();
    _preloadTriggeredIndices.clear();

    await previousPool?.dispose();

    if (_videos.isEmpty) {
      if (!mounted) return;
      setState(() {
        _currentPageIndex = 0;
      });
      return;
    }

    final targetIndex = preserveCurrentPage
        ? _currentPageIndex.clamp(0, _videos.length - 1)
        : 0;

    _currentPageIndex = targetIndex;

    final urls = _videos
        .map((video) => _extractPlayableVideoUrl(video) ?? '')
        .toList(growable: false);

    _videoPlayerPool = VideoPlayerPoolService(videoUrls: urls);
    final epoch = ++_videoPoolEpoch;

    if (!mounted) return;

    setState(() {});

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_pageController.hasClients) {
        return;
      }
      final currentPage = _pageController.page?.round();
      if (currentPage != _currentPageIndex) {
        _pageController.jumpToPage(_currentPageIndex);
      }
    });

    await _prepareControllersForPage(_currentPageIndex, epoch: epoch);
  }

  Future<void> _ensureControllerForIndex(int index, {int? epoch}) async {
    if (index < 0 || index >= _videos.length) {
      return;
    }

    if (_controllersByIndex.containsKey(index) ||
        _controllerLoadInProgress.contains(index)) {
      return;
    }

    final activeEpoch = epoch ?? _videoPoolEpoch;
    final pool = _videoPlayerPool;
    if (pool == null) {
      return;
    }

    _controllerLoadInProgress.add(index);
    try {
      final controller = await pool.getController(index);

      if (!mounted ||
          activeEpoch != _videoPoolEpoch ||
          !identical(pool, _videoPlayerPool)) {
        return;
      }

      if (controller != null) {
        try {
          await controller.setVolume(_isMuted ? 0.0 : 1.0);
        } catch (_) {
          // Ignore volume set failures.
        }
      }

      setState(() {
        _controllersByIndex[index] = controller;
      });

      if (index == _currentPageIndex) {
        _attachProgressListenerForCurrentPage();
      }
    } finally {
      _controllerLoadInProgress.remove(index);
    }
  }

  Future<void> _prepareControllersForPage(int pageIndex, {int? epoch}) async {
    if (_videos.isEmpty || pageIndex < 0 || pageIndex >= _videos.length) {
      return;
    }

    final activeEpoch = epoch ?? _videoPoolEpoch;

    await _ensureControllerForIndex(pageIndex, epoch: activeEpoch);
    await _ensureControllerForIndex(pageIndex - 1, epoch: activeEpoch);
    await _ensureControllerForIndex(pageIndex + 1, epoch: activeEpoch);

    final pool = _videoPlayerPool;
    if (pool == null || activeEpoch != _videoPoolEpoch) {
      return;
    }

    await pool.preloadAround(pageIndex);
    await pool.playOnly(pageIndex);
    await _applyMuteStateToControllers();

    _controllersByIndex.removeWhere((index, _) {
      return (index - pageIndex).abs() > 1;
    });

    _attachProgressListenerForCurrentPage();
  }

  void _onPageChanged(int index) {
    if (index == _currentPageIndex) {
      return;
    }

    setState(() {
      _currentPageIndex = index;
    });

    _prepareControllersForPage(index);
  }

  void _detachProgressListener() {
    final controller = _progressController;
    final listener = _progressListener;

    if (controller != null && listener != null) {
      controller.removeListener(listener);
    }

    _progressController = null;
    _progressListener = null;
  }

  void _attachProgressListenerForCurrentPage() {
    final controller = _controllersByIndex[_currentPageIndex];

    if (controller == null || !controller.value.isInitialized) {
      _detachProgressListener();
      return;
    }

    if (identical(controller, _progressController)) {
      return;
    }

    _detachProgressListener();

    final watchedIndex = _currentPageIndex;
    void listener() {
      final value = controller.value;
      if (!value.isInitialized) {
        return;
      }

      final totalMs = value.duration.inMilliseconds;
      if (totalMs <= 0) {
        return;
      }

      final progress = value.position.inMilliseconds / totalMs;
      if (progress >= 0.7 && _preloadTriggeredIndices.add(watchedIndex)) {
        _ensureControllerForIndex(watchedIndex + 1);
      }
    }

    _progressController = controller;
    _progressListener = listener;
    controller.addListener(listener);
  }

  String? _extractStatusFromPayload(Map<String, dynamic> payload) {
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

  bool _statusImpliesComplete(String? status) {
    if (status == null) return false;
    return status == 'complete' ||
        status == 'completed' ||
        status == 'done' ||
        status == 'success' ||
        status == 'ready' ||
        status == 'processed';
  }

  bool _statusImpliesFailure(String? status) {
    if (status == null) return false;
    return status == 'failed' || status == 'error' || status == 'rejected';
  }

  String? _extractMessageFromPayload(Map<String, dynamic> payload) {
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

  bool _hasPlayableVideoUrl(Map<String, dynamic> payload) {
    String? readVideoUrl(Map<dynamic, dynamic> map) {
      final value = map['video_url'];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
      return null;
    }

    final direct = readVideoUrl(payload);
    if (direct != null) {
      return true;
    }

    final nested = payload['data'];
    if (nested is Map) {
      return readVideoUrl(nested) != null;
    }

    return false;
  }

  Future<void> _syncPendingUploads() async {
    if (_isSyncingPendingUploads) {
      return;
    }

    _isSyncingPendingUploads = true;

    try {
      final pendingIds =
          await PendingUploadTrackerService.getPendingUploadIds();
      if (pendingIds.isEmpty) {
        return;
      }

      final nowLiveIds = <String>[];
      final failedIds = <String>[];
      String? failureMessage;

      for (final videoId in pendingIds) {
        try {
          final statusPayload = await VideoService.getVideoStatus(
            videoId: videoId,
          );
          final status = _extractStatusFromPayload(statusPayload);

          if (_statusImpliesComplete(status) ||
              _hasPlayableVideoUrl(statusPayload)) {
            nowLiveIds.add(videoId);
            continue;
          }

          if (_statusImpliesFailure(status)) {
            failedIds.add(videoId);
            failureMessage ??= _extractMessageFromPayload(statusPayload);
          }
        } catch (_) {
          // Ignore transient status errors; leave item pending.
        }
      }

      if (nowLiveIds.isEmpty && failedIds.isEmpty) {
        return;
      }

      await PendingUploadTrackerService.removePendingUploads(<String>[
        ...nowLiveIds,
        ...failedIds,
      ]);

      if (!mounted) return;

      if (failedIds.isNotEmpty) {
        final failedText =
            failureMessage ?? 'One of your queued uploads failed processing.';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(failedText)));
      }

      if (nowLiveIds.isNotEmpty) {
        await _loadFeed(preserveExisting: true, checkPendingUploads: false);
        if (!mounted) return;

        final count = nowLiveIds.length;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              count == 1
                  ? 'Your queued video is now live in the feed.'
                  : '$count queued videos are now live in the feed.',
            ),
          ),
        );
      }
    } finally {
      _isSyncingPendingUploads = false;
    }
  }

  Widget _buildHeader() {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          const Text(
            'Unibuzz',
            style: TextStyle(
              color: Color(0xFF00B4D8),
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: _videos.isEmpty ? null : _toggleMute,
            icon: Icon(
              _isMuted ? Icons.volume_off : Icons.volume_up,
              color: Colors.white,
              size: 20,
            ),
            tooltip: _isMuted ? 'Unmute' : 'Mute',
          ),
          IconButton(
            onPressed: _isLoading ? null : _refreshFeed,
            icon: const Icon(Icons.refresh, color: Colors.white, size: 20),
            tooltip: 'Refresh feed',
          ),
          const SizedBox(width: 4),
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF00B4D8), width: 2),
            ),
            child: _buildAvatarWidget(
              radius: 18,
              backgroundColor: const Color(0xFF1A1A1A),
              imageUrl: _currentUserAvatarUrl,
              iconColor: const Color(0xFF00B4D8),
              iconSize: 20,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return PageView.builder(
      scrollDirection: Axis.vertical,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 2,
      itemBuilder: (BuildContext context, int index) {
        return const _FeedSkeletonPage();
      },
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off, color: Colors.white, size: 32),
            const SizedBox(height: 12),
            Text(
              'Couldn\'t load your feed',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'Something went wrong.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: const Color(0xFF999999)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadFeed,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00B4D8),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Text(
        'No videos yet. Be the first to share!',
        style: TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildFeedBody() {
    if (_isLoading) {
      return _buildLoadingState();
    }

    if (_error != null) {
      return _buildErrorState();
    }

    if (_videos.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _refreshFeed,
      color: const Color(0xFF00B4D8),
      backgroundColor: const Color(0xFF1A1A1A),
      child: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        physics: const PageScrollPhysics(parent: BouncingScrollPhysics()),
        itemCount: _videos.length,
        onPageChanged: _onPageChanged,
        itemBuilder: (BuildContext context, int index) {
          return _FeedVideoPage(
            key: ValueKey<String>(
              'feed-page-${_extractVideoId(_videos[index]) ?? index}',
            ),
            index: index,
            video: _videos[index],
            controller: _controllersByIndex[index],
            isActive: index == _currentPageIndex,
            isMuted: _isMuted,
            onEnsureController: () => _ensureControllerForIndex(index),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0B),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildFeedBody()),
          ],
        ),
      ),
    );
  }
}

class _FeedSkeletonPage extends StatelessWidget {
  const _FeedSkeletonPage();

  Widget _bar({
    required double width,
    required double height,
    double radius = 8,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }

  Widget _pill({required double width, required double height}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
          width: 1,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF111111), Color(0xFF161616), Color(0xFF0E0E0E)],
            ),
          ),
        ),
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x22000000),
                  Color(0x00000000),
                  Color(0xAA000000),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          top: 14,
          left: 12,
          right: 12,
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.18),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _bar(width: 118, height: 12, radius: 6),
                    const SizedBox(height: 6),
                    _bar(width: 156, height: 10, radius: 6),
                  ],
                ),
              ),
              _bar(width: 56, height: 10, radius: 6),
            ],
          ),
        ),
        Positioned(
          left: 12,
          right: 12,
          bottom: 20,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _bar(width: 230, height: 12, radius: 6),
              const SizedBox(height: 6),
              _bar(width: 138, height: 12, radius: 6),
              const SizedBox(height: 12),
              Row(
                children: [
                  _pill(width: 72, height: 34),
                  const SizedBox(width: 8),
                  _pill(width: 44, height: 34),
                  const SizedBox(width: 8),
                  _pill(width: 78, height: 34),
                  const Spacer(),
                  _pill(width: 44, height: 34),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FeedVideoPage extends StatefulWidget {
  const _FeedVideoPage({
    super.key,
    required this.index,
    required this.video,
    required this.controller,
    required this.isActive,
    required this.isMuted,
    required this.onEnsureController,
  });

  final int index;
  final Map<String, dynamic> video;
  final VideoPlayerController? controller;
  final bool isActive;
  final bool isMuted;
  final Future<void> Function() onEnsureController;

  @override
  State<_FeedVideoPage> createState() => _FeedVideoPageState();
}

class _FeedVideoPageState extends State<_FeedVideoPage> {
  int? _voteState;
  int? _upvotes;
  int? _commentsCount;

  @override
  void initState() {
    super.initState();
    _loadCounts();
    _requestControllerIfNeeded();
    _syncPlaybackWithState();
  }

  @override
  void didUpdateWidget(covariant _FeedVideoPage oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (_videoId != _extractVideoId(oldWidget.video)) {
      _voteState = null;
      _upvotes = null;
      _commentsCount = null;
      _loadCounts();
    }

    if (oldWidget.controller != widget.controller ||
        oldWidget.isActive != widget.isActive ||
        oldWidget.isMuted != widget.isMuted) {
      _requestControllerIfNeeded();
      _syncPlaybackWithState();
    }
  }

  Future<void> _requestControllerIfNeeded() async {
    if (!widget.isActive || widget.controller != null) {
      return;
    }
    await widget.onEnsureController();
  }

  Future<void> _syncPlaybackWithState() async {
    final controller = widget.controller;

    if (controller == null || !controller.value.isInitialized) {
      return;
    }

    try {
      await controller.setVolume(widget.isMuted ? 0.0 : 1.0);
      if (widget.isActive) {
        if (!controller.value.isPlaying) {
          await controller.play();
        }
      } else {
        if (controller.value.isPlaying) {
          await controller.pause();
        }
      }
    } catch (_) {
      // Ignore transient playback state sync errors.
    }
  }

  String? _extractVideoId(Map<String, dynamic> video) {
    final id = video['id'];
    if (id is String && id.isNotEmpty) {
      return id;
    }
    return null;
  }

  String? get _videoId => _extractVideoId(widget.video);

  dynamic _readValueForPath(String path) {
    final segments = path.split('.');
    dynamic current = widget.video;

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

  dynamic _readFirstValue(List<String> paths) {
    for (final path in paths) {
      final value = _readValueForPath(path);
      if (value != null) {
        return value;
      }
    }
    return null;
  }

  String? _readNonEmptyString(List<String> paths) {
    for (final path in paths) {
      final value = _readValueForPath(path);
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
      if (value is num || value is bool) {
        final asText = value.toString().trim();
        if (asText.isNotEmpty) {
          return asText;
        }
      }
    }
    return null;
  }

  String get _caption {
    final caption = _readNonEmptyString(<String>['caption', 'description']);
    if (caption != null) {
      return _captionWithoutHashtags(caption);
    }
    return 'A new moment from campus';
  }

  String _captionWithoutHashtags(String caption) {
    if (caption.isEmpty) return caption;
    final cleaned = caption
        .replaceAll(RegExp(r'(^|\s)#[A-Za-z0-9_]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return cleaned.isEmpty ? caption : cleaned;
  }

  String get _displayName {
    final username = _readNonEmptyString(<String>[
      'username',
      'user_name',
      'user.username',
      'author.username',
      'uploader.username',
    ]);
    if (username != null) {
      return username.startsWith('@') ? username : '@$username';
    }

    final fullName = _readNonEmptyString(<String>[
      'full_name',
      'name',
      'user.full_name',
      'user.name',
      'author.full_name',
      'author.name',
      'uploader.full_name',
      'uploader.name',
    ]);
    if (fullName != null) {
      return fullName;
    }

    final userId = _readNonEmptyString(<String>[
      'user_id',
      'author_id',
      'user.id',
      'user.user_id',
      'author.id',
      'author.user_id',
      'uploader.id',
      'uploader.user_id',
    ]);
    if (userId != null) {
      final shortId = userId.length > 8 ? userId.substring(0, 8) : userId;
      return 'User $shortId';
    }

    return 'Student';
  }

  String? _readNonEmptyImageUrl(List<String> paths) {
    for (final path in paths) {
      final value = _readValueForPath(path);
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return null;
  }

  String? get _authorAvatarUrl {
    return _readNonEmptyImageUrl(<String>[
      'profile_photo_url',
      'avatar_url',
      'photo_url',
      'image_url',
      'user.profile_photo_url',
      'user.avatar_url',
      'user.photo_url',
      'author.profile_photo_url',
      'author.avatar_url',
      'author.photo_url',
      'uploader.profile_photo_url',
      'uploader.avatar_url',
      'uploader.photo_url',
      'posted_by.profile_photo_url',
      'posted_by.avatar_url',
      'creator.profile_photo_url',
      'creator.avatar_url',
    ]);
  }

  String _formatYearLabel(dynamic rawYear) {
    final int? year = rawYear is int
        ? rawYear
        : int.tryParse(rawYear?.toString() ?? '');
    if (year == null || year <= 0) return '';

    final int mod100 = year % 100;
    if (mod100 >= 11 && mod100 <= 13) {
      return '${year}th Year';
    }

    switch (year % 10) {
      case 1:
        return '${year}st Year';
      case 2:
        return '${year}nd Year';
      case 3:
        return '${year}rd Year';
      default:
        return '${year}th Year';
    }
  }

  String get _profileMeta {
    final university = _readNonEmptyString(<String>[
      'university_name',
      'university',
      'user.university_name',
      'user.university',
      'author.university_name',
      'author.university',
      'uploader.university_name',
      'uploader.university',
    ]);
    final yearLabel = _formatYearLabel(
      _readFirstValue(<String>[
        'year_of_study',
        'year',
        'user.year_of_study',
        'user.year',
        'author.year_of_study',
        'author.year',
        'uploader.year_of_study',
        'uploader.year',
      ]),
    );

    if (university != null && yearLabel.isNotEmpty) {
      return '$university • $yearLabel';
    }
    if (university != null) {
      return university;
    }
    if (yearLabel.isNotEmpty) {
      return yearLabel;
    }
    return '';
  }

  List<String> get _hashtags {
    final dynamic rawTags = _readFirstValue(<String>[
      'tags',
      'hashtags',
      'meta.tags',
      'metadata.tags',
    ]);
    final Set<String> tags = <String>{};

    void addTag(dynamic value) {
      final tag = value?.toString().trim() ?? '';
      if (tag.isEmpty) return;
      tags.add(tag.startsWith('#') ? tag : '#$tag');
    }

    if (rawTags is List) {
      for (final tag in rawTags) {
        addTag(tag);
      }
    } else if (rawTags is String && rawTags.trim().isNotEmpty) {
      for (final tag in rawTags.split(',')) {
        addTag(tag);
      }
    }

    if (tags.isEmpty) {
      final caption = _readNonEmptyString(<String>['caption', 'description']);
      if (caption is String && caption.trim().isNotEmpty) {
        final matches = RegExp(r'#[A-Za-z0-9_]+').allMatches(caption);
        for (final match in matches) {
          addTag(match.group(0));
        }
      }
    }

    return tags.take(3).toList();
  }

  String get _timestampLabel {
    final createdAt = widget.video['created_at'];
    if (createdAt is String && createdAt.isNotEmpty) {
      try {
        final dt = DateTime.parse(createdAt).toLocal();
        final day = dt.day.toString().padLeft(2, '0');
        final month = dt.month.toString().padLeft(2, '0');
        final yearTwoDigits = (dt.year % 100).toString().padLeft(2, '0');
        return '$day/$month/$yearTwoDigits';
      } catch (_) {
        return 'Just now';
      }
    }
    return 'Just now';
  }

  String? get _thumbnailUrl {
    final thumb = widget.video['thumbnail_url'];
    if (thumb is String && thumb.isNotEmpty) {
      return thumb;
    }
    return null;
  }

  int? _parseCount(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '');
  }

  Future<void> _loadCounts() async {
    final videoId = _videoId;
    if (videoId == null) return;

    int? latestUpvotes;
    int? latestCommentsCount;

    try {
      final votes = await VideoService.getVideoVotes(videoId: videoId);
      final dynamic nestedVotes = votes['data'];
      final dynamic votePayload = nestedVotes is Map ? nestedVotes : votes;
      latestUpvotes = _parseCount(
        votePayload is Map ? votePayload['upvotes'] : null,
      );
    } catch (_) {
      // Keep previous vote count if this request fails.
    }

    try {
      final comments = await VideoService.getComments(videoId: videoId);
      latestCommentsCount = comments.length;
    } catch (_) {
      // Keep previous comments count if this request fails.
    }

    if (!mounted) return;
    if (latestUpvotes == null && latestCommentsCount == null) return;

    setState(() {
      if (latestUpvotes != null) {
        _upvotes = latestUpvotes;
      }
      if (latestCommentsCount != null) {
        _commentsCount = latestCommentsCount;
      }
    });
  }

  Future<void> _handleUpvote() async {
    final videoId = _videoId;
    if (videoId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Video details not available')),
      );
      return;
    }

    final int? previousState = _voteState;
    final int? previousUpvotes = _upvotes;
    final bool removeExistingUpvote = previousState == 1;
    final int? nextState = removeExistingUpvote ? null : 1;
    final int voteType = removeExistingUpvote ? 0 : 1;
    final int baseUpvotes = previousUpvotes ?? 0;
    final int nextUpvotes = removeExistingUpvote
        ? (baseUpvotes - 1).clamp(0, 1 << 30)
        : (baseUpvotes + 1);

    setState(() {
      _voteState = nextState;
      _upvotes = nextUpvotes;
    });

    try {
      await VideoService.voteOnVideo(videoId: videoId, voteType: voteType);
      await _loadCounts();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _voteState = previousState;
        _upvotes = previousUpvotes;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }

  Future<void> _handleDownvote() async {
    final videoId = _videoId;
    if (videoId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Video details not available')),
      );
      return;
    }

    final int? previousState = _voteState;
    final int? previousUpvotes = _upvotes;
    final bool removeExistingDownvote = previousState == -1;
    final int? nextState = removeExistingDownvote ? null : -1;
    final int voteType = removeExistingDownvote ? 0 : -1;
    final int baseUpvotes = previousUpvotes ?? 0;
    final int nextUpvotes = previousState == 1
        ? (baseUpvotes - 1).clamp(0, 1 << 30)
        : baseUpvotes;

    setState(() {
      _voteState = nextState;
      _upvotes = nextUpvotes;
    });

    try {
      await VideoService.voteOnVideo(videoId: videoId, voteType: voteType);
      await _loadCounts();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _voteState = previousState;
        _upvotes = previousUpvotes;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }

  Future<void> _openComments() async {
    final videoId = _videoId;
    if (videoId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Video details not available')),
      );
      return;
    }

    final updatedCommentsCount = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) => CommentSheet(videoId: videoId),
    );

    if (updatedCommentsCount != null && mounted) {
      setState(() {
        _commentsCount = updatedCommentsCount;
      });
    }

    if (!mounted) return;
    await _loadCounts();
  }

  Future<void> _openReport() async {
    final videoId = _videoId;
    if (videoId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Video details not available')),
      );
      return;
    }

    final didSubmit = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (BuildContext context) => ReportScreen(
          videoId: videoId,
          caption: _caption,
          thumbnailUrl: _thumbnailUrl,
          authorName: _displayName,
          profileMeta: _profileMeta,
        ),
      ),
    );

    if (!mounted || didSubmit != true) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Report submitted. Thanks for helping.')),
    );
  }

  Future<void> _openFullScreen() async {
    final interactionState = await Navigator.of(context)
        .push<Map<String, int?>>(
          MaterialPageRoute<Map<String, int?>>(
            builder: (BuildContext context) => FullScreenVideoView(
              cardIndex: widget.index,
              heroTag: 'video-card-${widget.index}',
              video: widget.video,
              initialVoteState: _voteState,
              initialUpvotes: _upvotes,
              initialCommentsCount: _commentsCount,
            ),
          ),
        );

    if (!mounted) return;
    if (interactionState != null) {
      setState(() {
        _voteState = interactionState['voteState'];
        _upvotes = interactionState['upvotes'];
        _commentsCount = interactionState['commentsCount'];
      });
    }

    await _loadCounts();
  }

  Widget _buildTopMeta() {
    return Row(
      children: [
        _buildAvatarWidget(
          radius: 18,
          backgroundColor: const Color(0xFF00B4D8),
          imageUrl: _authorAvatarUrl,
          iconColor: Colors.white,
          iconSize: 18,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (_profileMeta.isNotEmpty)
                Text(
                  _profileMeta,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFB8B8B8),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
        ),
        Text(
          _timestampLabel,
          style: const TextStyle(
            color: Color(0xFFC9C9C9),
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildActionPill({
    required Widget child,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.12),
            width: 1,
          ),
        ),
        child: child,
      ),
    );
  }

  Widget _buildBottomPanel() {
    final controller = widget.controller;
    final hasVideo = controller != null && controller.value.isInitialized;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_caption.isNotEmpty)
          Text(
            _caption,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        if (_hashtags.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            _hashtags.join(' '),
            style: const TextStyle(
              color: Color(0xFF00B4D8),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        const SizedBox(height: 10),
        Row(
          children: [
            _buildActionPill(
              onTap: _handleUpvote,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.arrow_upward,
                    color: _voteState == 1
                        ? const Color(0xFF00B4D8)
                        : Colors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    (_upvotes ?? 0).toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _buildActionPill(
              onTap: _handleDownvote,
              child: Icon(
                Icons.arrow_downward,
                color: _voteState == -1
                    ? const Color(0xFF00B4D8)
                    : const Color(0xFFB8B8B8),
                size: 18,
              ),
            ),
            const SizedBox(width: 8),
            _buildActionPill(
              onTap: _openComments,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.comment_outlined,
                    color: Colors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    (_commentsCount ?? 0).toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            _buildActionPill(
              onTap: _openReport,
              child: const Icon(
                Icons.flag_outlined,
                color: Color(0xFFFF7A7A),
                size: 18,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        if (!hasVideo && widget.isActive)
          Text(
            'Buffering video...',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
      ],
    );
  }

  Widget _buildMediaLayer() {
    final controller = widget.controller;
    final hasVideo = controller != null && controller.value.isInitialized;

    return Stack(
      fit: StackFit.expand,
      children: [
        Container(color: const Color(0xFF0B0B0B)),
        if (_thumbnailUrl != null)
          AnimatedOpacity(
            opacity: hasVideo ? 0 : 1,
            duration: const Duration(milliseconds: 220),
            child: Image.network(
              _thumbnailUrl!,
              fit: BoxFit.cover,
              cacheHeight: 960,
              cacheWidth: 540,
              errorBuilder:
                  (BuildContext context, Object error, StackTrace? stackTrace) {
                    return Container(color: const Color(0xFF0B0B0B));
                  },
            ),
          ),
        if (hasVideo)
          FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: controller.value.size.width,
              height: controller.value.size.height,
              child: VideoPlayer(controller),
            ),
          ),
        if (!hasVideo && widget.isActive)
          const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00B4D8)),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _openFullScreen,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Hero(tag: 'video-card-${widget.index}', child: _buildMediaLayer()),
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x33000000),
                    Color(0x00000000),
                    Color(0x99000000),
                  ],
                ),
              ),
            ),
          ),
          Positioned(top: 14, left: 12, right: 12, child: _buildTopMeta()),
          Positioned(
            left: 12,
            right: 12,
            bottom: 20,
            child: _buildBottomPanel(),
          ),
        ],
      ),
    );
  }
}
