import 'package:flutter/material.dart';

class Comment {
  final String id;
  final String username;
  final String text;
  final bool isOwn;

  Comment({
    required this.id,
    required this.username,
    required this.text,
    required this.isOwn,
  });
}

class CommentSheet extends StatefulWidget {
  final int cardIndex;

  const CommentSheet({super.key, required this.cardIndex});

  @override
  State<CommentSheet> createState() => _CommentSheetState();
}

class _CommentSheetState extends State<CommentSheet> {
  late TextEditingController _commentController;
  String? _editingCommentId;
  List<Comment> comments = [
    Comment(
      id: '1',
      username: 'Alice Smith',
      text: 'This is such a vibe! Love the energy here 🔥',
      isOwn: false,
    ),
    Comment(
      id: '2',
      username: 'John Okello',
      text: 'Amazing shot! The lighting is perfect.',
      isOwn: true,
    ),
    Comment(
      id: '3',
      username: 'Maya Patel',
      text: 'When are we hanging out again?',
      isOwn: false,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _commentController = TextEditingController();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _handleSubmitComment() {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    if (_editingCommentId != null) {
      // Update existing comment
      final index = comments.indexWhere((c) => c.id == _editingCommentId);
      if (index != -1) {
        setState(() {
          comments[index] = Comment(
            id: comments[index].id,
            username: comments[index].username,
            text: text,
            isOwn: true,
          );
          _editingCommentId = null;
          _commentController.clear();
        });
      }
    } else {
      // Add new comment
      setState(() {
        comments.add(
          Comment(
            id: DateTime.now().toString(),
            username: 'John Okello',
            text: text,
            isOwn: true,
          ),
        );
        _commentController.clear();
      });
    }
  }

  void _handleEditComment(Comment comment) {
    setState(() {
      _editingCommentId = comment.id;
      _commentController.text = comment.text;
    });
  }

  void _handleDeleteComment(Comment comment) {
    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          title: const Text(
            'Delete Comment',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            'Are you sure you want to delete this comment?',
            style: TextStyle(color: Colors.white),
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
                setState(() {
                  comments.removeWhere((c) => c.id == comment.id);
                  if (_editingCommentId == comment.id) {
                    _editingCommentId = null;
                    _commentController.clear();
                  }
                });
                Navigator.of(context).pop();

                // Show confirmation
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Comment Deleted'),
                    duration: Duration(milliseconds: 1500),
                    backgroundColor: Color(0xFF1A1A1A),
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

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (BuildContext context, ScrollController scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF0B0B0B),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Comments',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(color: Color(0xFF333333), height: 1),

              // Comments List
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: comments.length,
                  itemBuilder: (context, index) {
                    final comment = comments[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Comment Header
                          Row(
                            children: [
                              const CircleAvatar(
                                radius: 18,
                                backgroundColor: Color(0xFF00B4D8),
                                child: Icon(
                                  Icons.person,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  comment.username,
                                  style: const TextStyle(
                                    color: Color(0xFF00B4D8),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),

                          // Comment Text
                          Padding(
                            padding: const EdgeInsets.only(left: 48),
                            child: Text(
                              comment.text,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.normal,
                              ),
                            ),
                          ),

                          // Edit/Delete Controls
                          if (comment.isOwn)
                            Padding(
                              padding: const EdgeInsets.only(left: 48, top: 8),
                              child: Row(
                                children: [
                                  GestureDetector(
                                    onTap: () => _handleEditComment(comment),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.edit,
                                          size: 14,
                                          color: Color(0xFF00B4D8),
                                        ),
                                        SizedBox(width: 6),
                                        Text(
                                          'Edit',
                                          style: TextStyle(
                                            color: Color(0xFF00B4D8),
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  GestureDetector(
                                    onTap: () => _handleDeleteComment(comment),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.delete_outline,
                                          size: 14,
                                          color: Color(0xFFFF4D4D),
                                        ),
                                        SizedBox(width: 6),
                                        Text(
                                          'Delete',
                                          style: TextStyle(
                                            color: Color(0xFFFF4D4D),
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 4),
                        ],
                      ),
                    );
                  },
                ),
              ),

              // Input Bar (Sticky above keyboard)
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF0B0B0B),
                  border: Border(
                    top: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                ),
                padding: EdgeInsets.fromLTRB(
                  16,
                  12,
                  16,
                  16 + MediaQuery.of(context).viewInsets.bottom,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF0B0B0B),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.1),
                            width: 1,
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        child: TextField(
                          controller: _commentController,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                          ),
                          decoration: InputDecoration(
                            hintText: _editingCommentId != null
                                ? 'Edit comment...'
                                : 'Add a comment...',
                            hintStyle: TextStyle(
                              color: Colors.white.withValues(alpha: 0.4),
                              fontSize: 13,
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                          ),
                          maxLines: null,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _handleSubmitComment,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF00B4D8),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.chevron_right,
                            color: Colors.white,
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
      },
    );
  }
}
