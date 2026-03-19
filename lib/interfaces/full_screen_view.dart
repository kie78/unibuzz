import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:unibuzz/interfaces/comment_section.dart';
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

class FullScreenVideoView extends StatefulWidget {
  const FullScreenVideoView({
    super.key,
    required this.cardIndex,
    required this.video,
    this.heroTag = 'video-card',
    this.initialVoteState,
    this.initialUpvotes,
    this.initialCommentsCount,
  });

  final int cardIndex;
  final Map<String, dynamic> video;
  final String heroTag;
  final int? initialVoteState;
  final int? initialUpvotes;
  final int? initialCommentsCount;

  @override
  State<FullScreenVideoView> createState() => _FullScreenVideoViewState();
}

class _FullScreenVideoViewState extends State<FullScreenVideoView> {
  int? _voteState; // null = no vote, 1 = upvote, -1 = downvote
  VideoPlayerController? _controller;
  bool _isInitializing = true;
  bool _hasLoadError = false;
  double _playbackProgress = 0.0;
  int? _upvotes;
  int? _commentsCount;

  String? get _videoId {
    final id = widget.video['id'];
    if (id is String && id.isNotEmpty) {
      return id;
    }
    return null;
  }

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

  String _captionWithoutHashtags(String caption) {
    if (caption.isEmpty) return caption;
    final cleaned = caption
        .replaceAll(RegExp(r'(^|\s)#[A-Za-z0-9_]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return cleaned.isEmpty ? caption : cleaned;
  }

  String get _caption {
    final caption = _readNonEmptyString(<String>['caption', 'description']);
    if (caption != null) {
      return _captionWithoutHashtags(caption);
    }
    return 'Check out this amazing moment from campus!';
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

  String? get _videoUrl {
    final url = widget.video['video_url'];
    if (url is String && url.isNotEmpty) {
      return url;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _voteState = widget.initialVoteState;
    _upvotes = widget.initialUpvotes;
    _commentsCount = widget.initialCommentsCount;
    _initializeVideo();
    _loadCounts();
  }

  Map<String, int?> _buildInteractionResult() {
    return <String, int?>{
      'voteState': _voteState,
      'upvotes': _upvotes,
      'commentsCount': _commentsCount,
    };
  }

  void _popWithInteractionState() {
    Navigator.of(context).pop(_buildInteractionResult());
  }

  Future<void> _initializeVideo() async {
    final url = _videoUrl;
    if (url == null) {
      setState(() {
        _isInitializing = false;
        _hasLoadError = true;
      });
      return;
    }
    try {
      final controller = VideoPlayerController.networkUrl(Uri.parse(url));
      await controller.initialize();
      await controller.setLooping(true);
      controller.addListener(() {
        if (!mounted) return;
        final value = controller.value;
        final duration = value.duration;
        final position = value.position;
        if (duration.inMilliseconds > 0) {
          setState(() {
            _playbackProgress =
                position.inMilliseconds / duration.inMilliseconds;
          });
        }
      });
      await controller.play();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
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

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
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
      HapticFeedback.lightImpact();
    });
    try {
      await VideoService.voteOnVideo(videoId: videoId, voteType: voteType);
      await _loadCounts();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _voteState = previousState;
        _upvotes = previousUpvotes;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
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
      HapticFeedback.lightImpact();
    });
    try {
      await VideoService.voteOnVideo(videoId: videoId, voteType: voteType);
      await _loadCounts();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _voteState = previousState;
        _upvotes = previousUpvotes;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _popWithInteractionState();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Stack(
            children: [
              // Full-bleed video background
              Hero(
                tag: widget.heroTag,
                child: SizedBox(
                  width: double.infinity,
                  height: double.infinity,
                  child: _isInitializing
                      ? const Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Color(0xFF00B4D8),
                            ),
                          ),
                        )
                      : _hasLoadError || controller == null
                      ? const Center(
                          child: Icon(
                            Icons.error_outline,
                            color: Colors.white,
                            size: 48,
                          ),
                        )
                      : FittedBox(
                          fit: BoxFit.cover,
                          child: SizedBox(
                            width: controller.value.size.width,
                            height: controller.value.size.height,
                            child: VideoPlayer(controller),
                          ),
                        ),
                ),
              ),

              // Top Navigation - Back Arrow
              Positioned(
                top: 16,
                left: 16,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Material(
                      color: Colors.black.withValues(alpha: 0.4),
                      child: InkWell(
                        onTap: _popWithInteractionState,
                        child: const SizedBox(
                          width: 44,
                          height: 44,
                          child: Center(
                            child: Icon(
                              Icons.arrow_back,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Bottom Content Overlay - Handle, Caption, Hashtags
              Positioned(
                bottom: 120,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 40, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _displayName,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (_profileMeta.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          _profileMeta,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: const Color(0xFFB8B8B8),
                                fontWeight: FontWeight.w400,
                              ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: [
                          Text(
                            _caption,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.normal,
                                ),
                          ),
                          if (_hashtags.isNotEmpty)
                            Text(
                              _hashtags.join(' '),
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: const Color(0xFF00B4D8),
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Bottom Center Interaction Pill
              Positioned(
                bottom: 20,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // User Avatar
                        _buildAvatarWidget(
                          radius: 16,
                          backgroundColor: Color(0xFF00B4D8),
                          imageUrl: _authorAvatarUrl,
                          iconColor: Colors.white,
                          iconSize: 18,
                        ),
                        // Vertical Divider
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 12),
                          width: 1,
                          height: 20,
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                        // Upvote
                        GestureDetector(
                          onTap: _handleUpvote,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.arrow_upward,
                                size: 16,
                                color: _voteState == 1
                                    ? const Color(0xFF00B4D8)
                                    : Colors.white,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                (_upvotes ?? 0).toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Downvote
                        GestureDetector(
                          onTap: _handleDownvote,
                          child: Icon(
                            Icons.arrow_downward,
                            size: 16,
                            color: _voteState == -1
                                ? const Color(0xFF00B4D8)
                                : const Color(0xFF999999),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Comment Divider
                        Container(
                          width: 1,
                          height: 20,
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                        const SizedBox(width: 12),
                        // Comments
                        GestureDetector(
                          onTap: () async {
                            final videoId = _videoId;
                            if (videoId == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Video details not available'),
                                ),
                              );
                              return;
                            }
                            final updatedCommentsCount =
                                await showModalBottomSheet<int>(
                                  context: context,
                                  builder: (BuildContext context) =>
                                      CommentSheet(videoId: videoId),
                                  isScrollControlled: true,
                                  backgroundColor: Colors.transparent,
                                );

                            if (updatedCommentsCount != null && mounted) {
                              setState(() {
                                _commentsCount = updatedCommentsCount;
                              });
                            }

                            if (!mounted) return;
                            await _loadCounts();
                          },
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.comment_outlined,
                                size: 16,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                (_commentsCount ?? 0).toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Bottom Progress Indicator
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 3,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
                  child: Row(
                    children: [
                      Container(
                        height: 3,
                        width:
                            MediaQuery.of(context).size.width *
                            _playbackProgress,
                        color: const Color(0xFF00B4D8),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
