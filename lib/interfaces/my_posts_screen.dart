import 'package:flutter/material.dart';
import 'package:unibuzz/app_colors.dart';
import 'package:unibuzz/interfaces/edit_post_screen.dart';
import 'package:unibuzz/interfaces/full_screen_view.dart';
import 'package:unibuzz/services/error_helper.dart';
import 'package:unibuzz/services/video_service.dart';

class MyPostsScreen extends StatefulWidget {
  const MyPostsScreen({super.key});

  @override
  State<MyPostsScreen> createState() => _MyPostsScreenState();
}

class _MyPostsScreenState extends State<MyPostsScreen> {
  bool _isLoading = true;
  String? _error;
  List<_PostItem> _posts = <_PostItem>[];

  @override
  void initState() {
    super.initState();
    _loadMyPosts();
  }

  String? _readNonEmptyString(Map<String, dynamic> data, List<String> keys) {
    for (final String key in keys) {
      final dynamic value = data[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return null;
  }

  String? _extractPostId(Map<String, dynamic> video) =>
      _readNonEmptyString(video, <String>['id', 'video_id']);

  String? _extractCreatedAt(Map<String, dynamic> video) =>
      _readNonEmptyString(video, <String>['created_at']);

  DateTime? _parseDate(String? rawDate) {
    if (rawDate == null || rawDate.isEmpty) return null;
    return DateTime.tryParse(rawDate)?.toLocal();
  }

  String _formatRelativeTime(DateTime createdAt) {
    final Duration diff = DateTime.now().difference(createdAt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} h ago';
    if (diff.inDays < 7) return '${diff.inDays} d ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()} w ago';
    final String d = createdAt.day.toString().padLeft(2, '0');
    final String m = createdAt.month.toString().padLeft(2, '0');
    final String y = (createdAt.year % 100).toString().padLeft(2, '0');
    return '$d/$m/$y';
  }

  int _parseCount(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  _PostItem _mapToPostItem(Map<String, dynamic> raw) {
    final String id = _extractPostId(raw) ?? 'post-${raw.hashCode}';
    final DateTime? createdAt = _parseDate(_extractCreatedAt(raw));
    final String caption =
        _readNonEmptyString(raw, <String>['caption', 'description']) ??
        'No caption';
    final String? thumbnailUrl = _readNonEmptyString(raw, <String>[
      'thumbnail_url',
      'thumbnail',
      'preview_url',
    ]);
    final String? videoUrl =
        _readNonEmptyString(raw, <String>['video_url', 'url']);
    final String? status = raw['status'] as String?;

    return _PostItem(
      id: id,
      createdAt: createdAt,
      timestamp:
          createdAt == null ? 'Recently' : _formatRelativeTime(createdAt),
      caption: caption,
      thumbnailUrl: thumbnailUrl,
      videoUrl: videoUrl,
      status: status,
      upvotes: _parseCount(raw['upvotes']),
      downvotes: _parseCount(raw['downvotes']),
      comments: _parseCount(raw['comments']),
      rawVideo: Map<String, dynamic>.from(raw),
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
      final List<dynamic> rawVideos = await VideoService.getMyVideos();
      final List<_PostItem> mappedPosts = rawVideos
          .whereType<Map<String, dynamic>>()
          .map(_mapToPostItem)
          .toList();

      if (!mounted) return;
      setState(() {
        _posts = mappedPosts;
        _isLoading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      final String message = friendlyError(error);
      if (!showLoading && _posts.isNotEmpty) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
        return;
      }
      setState(() {
        _isLoading = false;
        _error = message;
      });
    }
  }

  void _handlePlayPost(_PostItem post) {
    if (post.status == 'pending' ||
        post.videoUrl == null ||
        post.videoUrl!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This video is still processing. Please check back shortly.'),
        ),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FullScreenVideoView(
          cardIndex: 0,
          video: post.rawVideo,
        ),
      ),
    );
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
          backgroundColor: context.cardBg,
          title: Text(
            'Delete Post',
            style: TextStyle(color: context.primaryText),
          ),
          content: Text(
            'Are you sure you want to delete this post? This action cannot be undone.',
            style: TextStyle(color: context.secondaryText),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text('Cancel', style: TextStyle(color: context.accent)),
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
    return Center(
      child: CircularProgressIndicator(color: context.accent),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.error_outline, color: context.primaryText, size: 34),
            const SizedBox(height: 12),
            Text(
              _error ?? 'Unable to load your posts right now.',
              textAlign: TextAlign.center,
              style: TextStyle(color: context.secondaryText, fontSize: 14),
            ),
            const SizedBox(height: 14),
            ElevatedButton(
              onPressed: _loadMyPosts,
              style: ElevatedButton.styleFrom(
                backgroundColor: context.accent,
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
      color: context.accent,
      backgroundColor: context.cardBg,
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
                  color: context.primaryText.withValues(alpha: 0.3),
                ),
                const SizedBox(height: 16),
                Text(
                  'No posts yet',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: context.primaryText.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Pull down to refresh after you publish.',
                  style: TextStyle(color: context.tertiaryText, fontSize: 12),
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
      color: context.accent,
      backgroundColor: context.cardBg,
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
            onPlay: () => _handlePlayPost(post),
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
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        backgroundColor: context.appBarBg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: context.primaryText),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'My Posts',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: context.primaryText,
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
    required this.onPlay,
    required this.onEdit,
    required this.onDelete,
  });

  final _PostItem post;
  final VoidCallback onPlay;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  Widget _buildThumbnail(BuildContext context) {
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
          child: Icon(Icons.play_circle_outline, color: Colors.white, size: 38),
        ),
      );
    }

    if (thumbnailUrl == null || thumbnailUrl.isEmpty) return fallback();

    return Image.network(
      thumbnailUrl,
      fit: BoxFit.cover,
      loadingBuilder: (_, Widget child, ImageChunkEvent? progress) =>
          progress == null ? child : fallback(),
      errorBuilder: (_, __, ___) => fallback(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isPending = post.status == 'pending';
    final bool canPlay = !isPending &&
        post.videoUrl != null &&
        post.videoUrl!.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        children: <Widget>[
          // ── Thumbnail / video preview ──────────────────────────────────
          GestureDetector(
            onTap: onPlay,
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                SizedBox(
                  width: double.infinity,
                  height: 180,
                  child: _buildThumbnail(context),
                ),
                // Processing overlay
                if (isPending)
                  Container(
                    width: double.infinity,
                    height: 180,
                    color: Colors.black.withValues(alpha: 0.50),
                    child: const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 10),
                          Text(
                            'Processing…',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                // Play button (only for ready videos)
                if (canPlay)
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.15),
                      border: Border.all(
                        color: const Color(0xFF00B4D8),
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.play_arrow,
                      color: Color(0xFF00B4D8),
                      size: 28,
                    ),
                  ),
                // Timestamp badge
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
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
          ),

          // ── Caption ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 2),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                post.caption,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: context.primaryText,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),

          // ── Metrics ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Row(
                    children: <Widget>[
                      Icon(Icons.arrow_upward,
                          size: 18, color: context.tertiaryText),
                      const SizedBox(width: 6),
                      Text('${post.upvotes}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: context.secondaryText)),
                    ],
                  ),
                ),
                Expanded(
                  child: Row(
                    children: <Widget>[
                      Icon(Icons.arrow_downward,
                          size: 18, color: context.tertiaryText),
                      const SizedBox(width: 6),
                      Text('${post.downvotes}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: context.secondaryText)),
                    ],
                  ),
                ),
                Expanded(
                  child: Row(
                    children: <Widget>[
                      Icon(Icons.message_outlined,
                          size: 18, color: context.tertiaryText),
                      const SizedBox(width: 6),
                      Text('${post.comments}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: context.secondaryText)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Divider(color: context.dividerColor, height: 1, thickness: 1),

          // ── Actions ────────────────────────────────────────────────────
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
    required this.videoUrl,
    required this.status,
    required this.upvotes,
    required this.downvotes,
    required this.comments,
    required this.rawVideo,
  });

  final String id;
  final DateTime? createdAt;
  final String timestamp;
  final String caption;
  final String? thumbnailUrl;
  final String? videoUrl;
  final String? status;
  final int upvotes;
  final int downvotes;
  final int comments;

  /// The original API response map — passed directly to FullScreenVideoView.
  final Map<String, dynamic> rawVideo;
}
