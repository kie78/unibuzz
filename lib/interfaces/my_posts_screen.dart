import 'package:flutter/material.dart';
import 'package:unibuzz/interfaces/edit_post_screen.dart';

class MyPostsScreen extends StatefulWidget {
  const MyPostsScreen({super.key});

  @override
  State<MyPostsScreen> createState() => _MyPostsScreenState();
}

class _MyPostsScreenState extends State<MyPostsScreen> {
  late List<_PostItem> _posts;

  @override
  void initState() {
    super.initState();
    _posts = [
      _PostItem(
        id: '1',
        duration: '0:45',
        upvotes: 234,
        downvotes: 3,
        comments: 18,
      ),
      _PostItem(
        id: '2',
        duration: '1:22',
        upvotes: 567,
        downvotes: 8,
        comments: 42,
      ),
      _PostItem(
        id: '3',
        duration: '0:30',
        upvotes: 89,
        downvotes: 1,
        comments: 5,
      ),
    ];
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
          actions: [
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
                  _posts.removeWhere((element) => element.id == post.id);
                });
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Post deleted')));
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

  @override
  Widget build(BuildContext context) {
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
      body: SafeArea(
        child: _posts.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
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
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 16,
                ),
                itemCount: _posts.length,
                itemBuilder: (context, index) {
                  final post = _posts[index];
                  return _PostCard(
                    post: post,
                    onEdit: () => _handleEditPost(post),
                    onDelete: () => _handleDeletePost(post),
                  );
                },
              ),
      ),
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
        children: [
          // Media Thumbnail
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: double.infinity,
                height: 180,
                color: const Color(0xFF141414),
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF00B4D8), Color(0xFF0B7A92)],
                    ),
                  ),
                ),
              ),
              // Play Button
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
              // Duration Tag
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
                    post.duration,
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
          // Analytics Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                // Upvotes
                Expanded(
                  child: Row(
                    children: [
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
                // Downvotes
                Expanded(
                  child: Row(
                    children: [
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
                // Comments
                Expanded(
                  child: Row(
                    children: [
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
          // Creator Actions
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                // Edit Button
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
                // Delete Button
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
  _PostItem({
    required this.id,
    required this.duration,
    required this.upvotes,
    required this.downvotes,
    required this.comments,
  });

  final String id;
  final String duration;
  final int upvotes;
  final int downvotes;
  final int comments;
}
