import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:unibuzz/providers/comment_provider.dart';

export 'package:unibuzz/providers/comment_provider.dart' show Comment;

class CommentSheet extends StatefulWidget {
  const CommentSheet({super.key});

  @override
  State<CommentSheet> createState() => _CommentSheetState();
}

class _CommentSheetState extends State<CommentSheet> {
  late final TextEditingController _commentController;

  @override
  void initState() {
    super.initState();
    _commentController = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<CommentProvider>().loadComments();
    });
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit(CommentProvider provider) async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    final editingId = provider.editingCommentId;
    String? error;

    if (editingId != null) {
      error = await provider.updateComment(editingId, text);
    } else {
      error = await provider.addComment(text);
    }

    if (!mounted) return;

    if (error != null) {
      _showError(error);
    } else {
      _commentController.clear();
      if (provider.successMessage != null) {
        _showSuccess(provider.successMessage!);
        provider.clearSuccess();
      }
    }
  }

  Future<void> _handleDelete(CommentProvider provider, Comment comment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Delete Comment', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to delete this comment?',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF00B4D8))),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete', style: TextStyle(color: Color(0xFFFF4D4D))),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final error = await provider.deleteComment(comment.id);
    if (!mounted) return;

    if (error != null) {
      _showError(error);
    } else {
      if (provider.editingCommentId == comment.id) {
        _commentController.clear();
      }
      if (provider.successMessage != null) {
        _showSuccess(provider.successMessage!);
        provider.clearSuccess();
      }
    }
  }

  Future<void> _handleToggle(CommentProvider provider) async {
    final error = await provider.toggleComments();
    if (!mounted) return;
    if (error != null) {
      _showError(error);
    } else if (provider.successMessage != null) {
      _showSuccess(provider.successMessage!);
      provider.clearSuccess();
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFFF4D4D),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF1A3A2A),
        duration: const Duration(milliseconds: 1800),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CommentProvider>(
      builder: (context, provider, _) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.75,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (BuildContext ctx, ScrollController scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Color(0xFF0B0B0B),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  _buildHeader(context, provider),
                  const Divider(color: Color(0xFF333333), height: 1),
                  Expanded(child: _buildBody(provider, scrollController)),
                  _buildInputBar(provider),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, CommentProvider provider) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
      child: Row(
        children: [
          const Text(
            'Comments',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (provider.commentsDisabled)
            const Padding(
              padding: EdgeInsets.only(left: 8),
              child: Text(
                '(disabled)',
                style: TextStyle(color: Color(0xFF999999), fontSize: 13),
              ),
            ),
          const Spacer(),
          if (provider.isVideoOwner)
            Tooltip(
              message: provider.commentsDisabled
                  ? 'Enable comments'
                  : 'Disable comments',
              child: IconButton(
                onPressed: provider.isLoading
                    ? null
                    : () => _handleToggle(provider),
                icon: Icon(
                  provider.commentsDisabled
                      ? Icons.comments_disabled_outlined
                      : Icons.comment_outlined,
                  color: provider.commentsDisabled
                      ? const Color(0xFF999999)
                      : const Color(0xFF00B4D8),
                  size: 22,
                ),
              ),
            ),
          GestureDetector(
            onTap: () => Navigator.of(context).pop(provider.comments.length),
            child: Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.only(left: 4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.1),
              ),
              child: const Center(
                child: Icon(Icons.close, color: Colors.white, size: 18),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(CommentProvider provider, ScrollController scrollController) {
    if (provider.isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00B4D8)),
        ),
      );
    }

    if (provider.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                color: Color(0xFFFF4D4D),
                size: 32,
              ),
              const SizedBox(height: 12),
              Text(
                provider.error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: provider.loadComments,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00B4D8),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (provider.commentsDisabled) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.comments_disabled_outlined,
                color: Color(0xFF666666),
                size: 32,
              ),
              const SizedBox(height: 12),
              Text(
                'Comments are disabled for this video.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (provider.comments.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'No comments yet. Be the first!',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 14,
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      controller: scrollController,
      itemCount: provider.comments.length,
      itemBuilder: (context, index) {
        final comment = provider.comments[index];
        final isEditing = provider.editingCommentId == comment.id;
        return _buildCommentTile(provider, comment, isEditing);
      },
    );
  }

  Widget _buildCommentTile(
    CommentProvider provider,
    Comment comment,
    bool isEditing,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: comment.isOwn
                    ? const Color(0xFF00B4D8)
                    : const Color(0xFF333333),
                child: const Icon(Icons.person, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  comment.username,
                  style: TextStyle(
                    color: comment.isOwn
                        ? const Color(0xFF00B4D8)
                        : const Color(0xFFCCCCCC),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (isEditing)
                GestureDetector(
                  onTap: () {
                    provider.cancelEditing();
                    _commentController.clear();
                  },
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Color(0xFF999999), fontSize: 12),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 48),
            child: Text(
              comment.text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
              ),
            ),
          ),
          if (comment.isOwn)
            Padding(
              padding: const EdgeInsets.only(left: 48, top: 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      provider.startEditing(comment);
                      _commentController.text = comment.text;
                    },
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.edit, size: 14, color: Color(0xFF00B4D8)),
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
                    onTap: () => _handleDelete(provider, comment),
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
  }

  Widget _buildInputBar(CommentProvider provider) {
    final disabled = provider.commentsDisabled;
    final submitting = provider.isSubmitting;
    final isEditing = provider.editingCommentId != null;

    return Container(
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: TextField(
                controller: _commentController,
                enabled: !disabled && !submitting,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                maxLength: 500,
                maxLines: null,
                buildCounter: (_, {required currentLength, required isFocused, maxLength}) =>
                    null,
                decoration: InputDecoration(
                  hintText: disabled
                      ? 'Comments are disabled'
                      : isEditing
                          ? 'Edit your comment...'
                          : 'Add a comment...',
                  hintStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 13,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: (disabled || submitting) ? null : () => _handleSubmit(provider),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: (disabled || submitting)
                    ? const Color(0xFF4D4D4D)
                    : const Color(0xFF00B4D8),
              ),
              child: submitting
                  ? const Padding(
                      padding: EdgeInsets.all(8),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Center(
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
    );
  }
}
