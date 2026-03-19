import 'package:flutter/material.dart';
import 'package:unibuzz/services/auth_service.dart';
import 'package:unibuzz/services/video_service.dart';

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
  final String videoId;

  const CommentSheet({super.key, required this.videoId});

  @override
  State<CommentSheet> createState() => _CommentSheetState();
}

class _CommentSheetState extends State<CommentSheet> {
  late TextEditingController _commentController;
  String? _editingCommentId;
  bool _isLoading = true;
  bool _commentsDisabled = false;
  String? _error;
  List<Comment> comments = <Comment>[];

  @override
  void initState() {
    super.initState();
    _commentController = TextEditingController();
    _loadComments();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _handleSubmitComment() {
    if (_commentsDisabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Comments are disabled for this video.')),
      );
      return;
    }

    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    if (_editingCommentId != null) {
      _updateExistingComment(text);
    } else {
      _createNewComment(text);
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
              onPressed: () async {
                Navigator.of(context).pop();
                await _deleteComment(comment);
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

  Future<void> _deleteComment(Comment comment) async {
    try {
      await VideoService.deleteComment(commentId: comment.id);
      if (!mounted) return;

      if (_editingCommentId == comment.id) {
        setState(() {
          _editingCommentId = null;
          _commentController.clear();
        });
      }

      await _loadComments();
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Comment Deleted'),
          duration: Duration(milliseconds: 1500),
          backgroundColor: Color(0xFF1A1A1A),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _loadComments() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final currentUserId = await AuthService.getCurrentUserId();
      final commentsResponse = await VideoService.getCommentsResponse(
        videoId: widget.videoId,
      );
      final rawComments = commentsResponse.comments;
      final mapped = rawComments.map<Comment>((dynamic item) {
        if (item is Map<String, dynamic>) {
          final id = item['id']?.toString() ?? '';
          final text = item['content']?.toString() ?? '';
          final userId = item['user_id']?.toString() ?? '';
          final isOwn = currentUserId != null && userId == currentUserId;
          return Comment(
            id: id,
            username: isOwn
                ? 'You'
                : (userId.isNotEmpty ? 'User $userId' : 'User'),
            text: text,
            isOwn: isOwn,
          );
        }
        return Comment(
          id: DateTime.now().toString(),
          username: 'User',
          text: item.toString(),
          isOwn: false,
        );
      }).toList();

      if (!mounted) return;
      setState(() {
        comments = mapped;
        _commentsDisabled = commentsResponse.commentsDisabled;
        if (_commentsDisabled) {
          _editingCommentId = null;
          _commentController.clear();
        }
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _createNewComment(String text) async {
    if (_commentsDisabled) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Comments are disabled for this video.')),
      );
      return;
    }

    try {
      await VideoService.addComment(videoId: widget.videoId, comment: text);
      _commentController.clear();
      await _loadComments();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _updateExistingComment(String text) async {
    final editingId = _editingCommentId;
    if (editingId == null) return;
    try {
      await VideoService.updateComment(commentId: editingId, comment: text);
      _editingCommentId = null;
      _commentController.clear();
      await _loadComments();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
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
                      onTap: () => Navigator.of(context).pop(comments.length),
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
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Color(0xFF00B4D8),
                          ),
                        ),
                      )
                    : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      )
                    : _commentsDisabled && comments.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'Comments are disabled for this video.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 14,
                            ),
                          ),
                        ),
                      )
                    : ListView.builder(
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
                                    padding: const EdgeInsets.only(
                                      left: 48,
                                      top: 8,
                                    ),
                                    child: Row(
                                      children: [
                                        GestureDetector(
                                          onTap: () =>
                                              _handleEditComment(comment),
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
                                          onTap: () =>
                                              _handleDeleteComment(comment),
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
                          enabled: !_commentsDisabled,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                          ),
                          decoration: InputDecoration(
                            hintText: _commentsDisabled
                                ? 'Comments are disabled'
                                : _editingCommentId != null
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
                      onTap: _commentsDisabled ? null : _handleSubmitComment,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _commentsDisabled
                              ? const Color(0xFF4D4D4D)
                              : const Color(0xFF00B4D8),
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
