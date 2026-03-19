import 'package:flutter/material.dart';
import 'package:unibuzz/interfaces/edit_post_screen.dart';
import 'package:unibuzz/services/auth_service.dart';
import 'package:unibuzz/services/video_service.dart';

class MyPostsScreen extends StatefulWidget {
  const MyPostsScreen({super.key});

  @override
  State<MyPostsScreen> createState() => _MyPostsScreenState();
}

class _MyPostsScreenState extends State<MyPostsScreen> {
  static const int _feedPageSize = 20;
  static const int _maxFeedPagesToScan = 5;

  bool _isLoading = true;
  String? _error;
  List<_PostItem> _posts = <_PostItem>[];

  @override
  void initState() {
    super.initState();
    _loadMyPosts();
  }

  String _exceptionText(Object error) {
    return error.toString().replaceFirst('Exception: ', '').trim();
  }

  dynamic _readValueForPath(Map<String, dynamic> data, String path) {
    final List<String> segments = path.split('.');
    dynamic current = data;

    for (final String segment in segments) {
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

  String? _readNonEmptyString(Map<String, dynamic> data, List<String> paths) {
    for (final String path in paths) {
      final dynamic value = _readValueForPath(data, path);
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
      if (value is num || value is bool) {
        final String text = value.toString().trim();
        if (text.isNotEmpty) {
          return text;
        }
      }
    }
    return null;
  }

  String? _extractPostId(Map<String, dynamic> video) {
    return _readNonEmptyString(video, <String>['id', 'video_id']);
  }

  String? _extractOwnerUserId(Map<String, dynamic> video) {
    return _readNonEmptyString(video, <String>['user_id', 'user.id', 'author_id']);
  }

  String? _extractCreatedAt(Map<String, dynamic> video) {
    return _readNonEmptyString(video, <String>['created_at']);
  }

  DateTime? _parseDate(String? rawDate) {
    if (rawDate == null || rawDate.isEmpty) {
      return null;
    }
    return DateTime.tryParse(rawDate)?.toLocal();
  }

  String _formatRelativeTime(DateTime createdAt) {
    final Duration difference = DateTime.now().difference(createdAt);

    if (difference.inSeconds < 60) {
      return 'Just now';
    }
    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} min ago';
    }
    if (difference.inHours < 24) {
      return '${difference.inHours} h ago';
    }
    if (difference.inDays < 7) {
      return '${difference.inDays} d ago';
    }
    if (difference.inDays < 30) {
      return '${(difference.inDays / 7).floor()} w ago';
    }

    final String day = createdAt.day.toString().padLeft(2, '0');
    final String month = createdAt.month.toString().padLeft(2, '0');
    final String year = (createdAt.year % 100).toString().padLeft(2, '0');
    return '$day/$month/$year';
  }

  String? _findOldestCreatedAt(List<dynamic> videos) {
    DateTime? oldestDate;
    String? oldestRaw;

    for (final dynamic item in videos) {
      if (item is! Map) {
        continue;
      }

      final Map<String, dynamic> map = Map<String, dynamic>.from(item);
      final String? createdAt = _extractCreatedAt(map);
      if (createdAt == null) {
        continue;
      }

      final DateTime? parsed = DateTime.tryParse(createdAt);
      if (parsed == null) {
        continue;
      }

      if (oldestDate == null || parsed.isBefore(oldestDate)) {
        oldestDate = parsed;
        oldestRaw = createdAt;
      }
    }

    return oldestRaw;
  }

  _PostItem _mapToPostItem(Map<String, dynamic> raw) {
    final String id = _extractPostId(raw) ?? 'post-${raw.hashCode}';
    final DateTime? createdAt = _parseDate(_extractCreatedAt(raw));

    final String caption = _readNonEmptyString(raw, <String>['caption', 'description']) ??
        'No caption';

    final String? thumbnailUrl = _readNonEmptyString(raw, <String>[
      'thumbnail_url',
      'thumbnail',
      'preview_url',
      'media.thumbnail_url',
      'media.preview_url',
    ]);

    return _PostItem(
      id: id,
      createdAt: createdAt,
      timestamp: createdAt == null ? 'Recently' : _formatRelativeTime(createdAt),
      caption: caption,
      thumbnailUrl: thumbnailUrl,
      upvotes: 0,
      downvotes: 0,
      comments: 0,
    );
  }

  int? _parseCount(dynamic value) {
    if (value is int) {
      return value;
    }
    return int.tryParse(value?.toString() ?? '');
  }

  Future<void> _loadPostMetrics(String postId) async {
    int? upvotes;
    int? downvotes;
    int? comments;

    try {
      final Map<String, dynamic> votes = await VideoService.getVideoVotes(
        videoId: postId,
      );
      final dynamic nested = votes['data'];
      final Map<dynamic, dynamic> payload = nested is Map ? nested : votes;
      upvotes = _parseCount(payload['upvotes']);
      downvotes = _parseCount(payload['downvotes']);
    } catch (_) {
      // Keep defaults if this request fails.
    }

    try {
      final List<dynamic> rawComments = await VideoService.getComments(
        videoId: postId,
      );
      comments = rawComments.length;
    } catch (_) {
      // Keep defaults if this request fails.
    }

    if (!mounted) {
      return;
    }

    if (upvotes == null && downvotes == null && comments == null) {
      return;
    }

    setState(() {
      final int index = _posts.indexWhere((post) => post.id == postId);
      if (index < 0) {
        return;
      }

      final _PostItem current = _posts[index];
      _posts[index] = current.copyWith(
        upvotes: upvotes ?? current.upvotes,
        downvotes: downvotes ?? current.downvotes,
        comments: comments ?? current.comments,
      );
    });
  }

  Future<void> _loadAllPostMetrics() async {
    final List<_PostItem> snapshot = List<_PostItem>.from(_posts);
    await Future.wait<void>(
      snapshot.map((post) => _loadPostMetrics(post.id)),
    );
  }

  Future<void> _loadMyPosts({bool showLoading = true}) async {
    if (showLoading) {
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
      final String? currentUserId = await AuthService.getCurrentUserId();
      if (currentUserId == null || currentUserId.isEmpty) {
        throw Exception('Session expired. Please log in again.');
      }

      final List<Map<String, dynamic>> ownPostsRaw = <Map<String, dynamic>>[];
      final Set<String> seenPostIds = <String>{};
      String? beforeCursor;

      for (int page = 0; page < _maxFeedPagesToScan; page++) {
        final List<dynamic> pageItems = await VideoService.fetchFeed(
          before: beforeCursor,
          limit: _feedPageSize,
        );

        if (pageItems.isEmpty) {
          break;
        }

        for (final dynamic item in pageItems) {
          if (item is! Map) {
            continue;
          }

          final Map<String, dynamic> map = Map<String, dynamic>.from(item);
          final String? ownerUserId = _extractOwnerUserId(map);
          if (ownerUserId != currentUserId) {
            continue;
          }

          final String? postId = _extractPostId(map);
          if (postId == null || postId.isEmpty || !seenPostIds.add(postId)) {
            continue;
          }

          ownPostsRaw.add(map);
        }

        final String? nextCursor = _findOldestCreatedAt(pageItems);
        if (nextCursor == null || nextCursor.isEmpty) {
          break;
        }

        if (pageItems.length < _feedPageSize) {
          break;
        }

        beforeCursor = nextCursor;
      }

      final List<_PostItem> mappedPosts = ownPostsRaw
          .map(_mapToPostItem)
          .toList()
        ..sort((a, b) {
          final DateTime? aDate = a.createdAt;
          final DateTime? bDate = b.createdAt;
          if (aDate == null && bDate == null) {
            return 0;
          }
          if (aDate == null) {
            return 1;
          }
          if (bDate == null) {
            return -1;
          }
          return bDate.compareTo(aDate);
        });

      if (!mounted) {
        return;
      }

      setState(() {
        _posts = mappedPosts;
        _isLoading = false;
        _error = null;
      });

      if (mappedPosts.isNotEmpty) {
        await _loadAllPostMetrics();
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      final String message = _exceptionText(error);
      if (!showLoading && _posts.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
        return;
      }

      setState(() {
        _isLoading = false;
        _error = message;
      });
    }
  }

  void _handleEditPost(_PostItem post) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => EditPostScreen(postId: post.id),
      ),
    );
  }

  void _handleDeletePost(_PostItem post) {
    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          title: const Text(
            'Delete Post',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            'Are you sure you want to delete this post? This action cannot be undone.',
            style: TextStyle(color: Color(0xFFB8B8B8)),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Color(0xFF00B4D8)),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                setState(() {
                  _posts = _posts.where((item) => item.id != post.id).toList();
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Post removed from this list. Server delete endpoint is not integrated yet.',
                    ),
                  ),
                );
              },
              child: const Text(
                'Delete',
                style: TextStyle(color: Color(0xFFFF4D4D)),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(color: Color(0xFF00B4D8)),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.error_outline, color: Colors.white, size: 34),
            const SizedBox(height: 12),
            Text(
              _error ?? 'Unable to load your posts right now.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFFB8B8B8),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 14),
            ElevatedButton(
              onPressed: _loadMyPosts,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00B4D8),
                foregroundColor: Colors.black,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return RefreshIndicator(
      onRefresh: () => _loadMyPosts(showLoading: false),
      color: const Color(0xFF00B4D8),
      backgroundColor: const Color(0xFF1A1A1A),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        children: <Widget>[
          SizedBox(height: MediaQuery.of(context).size.height * 0.23),
          Center(
            child: Column(
              children: <Widget>[
                Icon(
                  Icons.video_library_outlined,
                  size: 64,
                  color: Colors.white.withValues(alpha: 0.3),
                ),
                const SizedBox(height: 16),
                Text(
                  'No posts yet',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Pull down to refresh after you publish.',
                  style: TextStyle(color: Color(0xFF8C8C8C), fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostsList() {
    return RefreshIndicator(
      onRefresh: () => _loadMyPosts(showLoading: false),
      color: const Color(0xFF00B4D8),
      backgroundColor: const Color(0xFF1A1A1A),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        itemCount: _posts.length,
        itemBuilder: (BuildContext context, int index) {
          final _PostItem post = _posts[index];
          return _PostCard(
            post: post,
            onEdit: () => _handleEditPost(post),
            onDelete: () => _handleDeletePost(post),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (_isLoading) {
      body = _buildLoadingState();
    } else if (_error != null) {
      body = _buildErrorState();
    } else if (_posts.isEmpty) {
      body = _buildEmptyState();
    } else {
      body = _buildPostsList();
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B0B0B),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'My Posts',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(child: body),
    );
  }
}

class _PostCard extends StatelessWidget {
  const _PostCard({
    required this.post,
    required this.onEdit,
    required this.onDelete,
  });

  final _PostItem post;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  Widget _buildThumbnail() {
    final String? thumbnailUrl = post.thumbnailUrl;

    Widget fallback() {
      return const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[Color(0xFF00B4D8), Color(0xFF0B7A92)],
          ),
        ),
        child: Center(
          child: Icon(
            Icons.play_circle_outline,
            color: Colors.white,
            size: 38,
          ),
        ),
      );
    }

    if (thumbnailUrl == null || thumbnailUrl.isEmpty) {
      return fallback();
    }

    return Image.network(
      thumbnailUrl,
      fit: BoxFit.cover,
      loadingBuilder:
          (
            BuildContext context,
            Widget child,
            ImageChunkEvent? loadingProgress,
          ) {
            if (loadingProgress == null) {
              return child;
            }
            return fallback();
          },
      errorBuilder:
          (BuildContext context, Object error, StackTrace? stackTrace) {
            return fallback();
          },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        children: <Widget>[
          Stack(
            alignment: Alignment.center,
            children: <Widget>[
              SizedBox(width: double.infinity, height: 180, child: _buildThumbnail()),
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.12),
                  border: Border.all(color: const Color(0xFF00B4D8), width: 2),
                ),
                child: const Icon(
                  Icons.play_arrow,
                  color: Color(0xFF00B4D8),
                  size: 28,
                ),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    post.timestamp,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 2),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                post.caption,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Row(
                    children: <Widget>[
                      const Icon(
                        Icons.arrow_upward,
                        size: 18,
                        color: Color(0xFF999999),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${post.upvotes}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFFB8B8B8),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Row(
                    children: <Widget>[
                      const Icon(
                        Icons.arrow_downward,
                        size: 18,
                        color: Color(0xFF999999),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${post.downvotes}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFFB8B8B8),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Row(
                    children: <Widget>[
                      const Icon(
                        Icons.message_outlined,
                        size: 18,
                        color: Color(0xFF999999),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${post.comments}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFFB8B8B8),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: Color(0xFF2A2A2A), height: 1, thickness: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: <Widget>[
                Flexible(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onEdit,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: const Color(0xFF00B4D8),
                            width: 1.5,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            'Edit',
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(
                                  color: const Color(0xFF00B4D8),
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                const SizedBox(width: 8),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onDelete,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2A1515),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.delete_outline,
                        color: Color(0xFFFF4D4D),
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PostItem {
  const _PostItem({
    required this.id,
    required this.createdAt,
    required this.timestamp,
    required this.caption,
    required this.thumbnailUrl,
    required this.upvotes,
    required this.downvotes,
    required this.comments,
  });

  final String id;
  final DateTime? createdAt;
  final String timestamp;
  final String caption;
  final String? thumbnailUrl;
  final int upvotes;
  final int downvotes;
  final int comments;

  _PostItem copyWith({
    int? upvotes,
    int? downvotes,
    int? comments,
  }) {
    return _PostItem(
      id: id,
      createdAt: createdAt,
      timestamp: timestamp,
      caption: caption,
      thumbnailUrl: thumbnailUrl,
      upvotes: upvotes ?? this.upvotes,
      downvotes: downvotes ?? this.downvotes,
      comments: comments ?? this.comments,
    );
  }
}
