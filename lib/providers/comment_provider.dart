import 'package:flutter/foundation.dart';
import 'package:unibuzz/services/auth_service.dart';
import 'package:unibuzz/services/video_service.dart';

class Comment {
  const Comment({
    required this.id,
    required this.username,
    required this.text,
    required this.isOwn,
  });

  final String id;
  final String username;
  final String text;
  final bool isOwn;
}

class CommentProvider extends ChangeNotifier {
  CommentProvider({required this.videoId, this.videoOwnerId});

  final String videoId;
  final String? videoOwnerId;

  List<Comment> _comments = [];
  bool _commentsDisabled = false;
  bool _isLoading = false;
  String? _error;
  bool _isSubmitting = false;
  String? _editingCommentId;
  String? _currentUserId;
  String? _successMessage;

  List<Comment> get comments => List.unmodifiable(_comments);
  bool get commentsDisabled => _commentsDisabled;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isSubmitting => _isSubmitting;
  String? get editingCommentId => _editingCommentId;
  String? get currentUserId => _currentUserId;
  String? get successMessage => _successMessage;

  bool get isVideoOwner =>
      _currentUserId != null &&
      videoOwnerId != null &&
      _currentUserId == videoOwnerId;

  void startEditing(Comment comment) {
    _editingCommentId = comment.id;
    notifyListeners();
  }

  void cancelEditing() {
    _editingCommentId = null;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void clearSuccess() {
    _successMessage = null;
    notifyListeners();
  }

  Future<void> loadComments() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _currentUserId ??= await AuthService.getCurrentUserId();
      final response =
          await VideoService.getCommentsResponse(videoId: videoId);

      _comments = response.comments.map<Comment>((dynamic item) {
        if (item is Map<String, dynamic>) {
          final id = item['id']?.toString() ?? '';
          final text = item['content']?.toString() ?? '';
          final userId = item['user_id']?.toString() ?? '';
          final rawUsername = item['username']?.toString();
          final isOwn =
              _currentUserId != null && userId == _currentUserId;

          String displayName;
          if (isOwn) {
            displayName = 'You';
          } else if (rawUsername != null && rawUsername.isNotEmpty) {
            displayName = '@$rawUsername';
          } else {
            displayName = 'User';
          }

          return Comment(id: id, username: displayName, text: text, isOwn: isOwn);
        }
        return Comment(
          id: UniqueKey().toString(),
          username: 'User',
          text: item.toString(),
          isOwn: false,
        );
      }).toList();

      _commentsDisabled = response.commentsDisabled;
      if (_commentsDisabled) _editingCommentId = null;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Returns null on success, or an error message string on failure.
  Future<String?> addComment(String text) async {
    if (_commentsDisabled) return 'Comments are disabled for this video.';
    final trimmed = text.trim();
    if (trimmed.isEmpty) return 'Comment cannot be empty.';
    if (trimmed.length > 500) return 'Comment must be 500 characters or fewer.';

    _isSubmitting = true;
    notifyListeners();

    try {
      await VideoService.addComment(videoId: videoId, comment: trimmed);
      _isSubmitting = false;
      _successMessage = 'Comment posted!';
      await loadComments();
      return null;
    } catch (e) {
      _isSubmitting = false;
      final msg = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return msg;
    }
  }

  /// Returns null on success, or an error message string on failure.
  Future<String?> updateComment(String commentId, String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return 'Comment cannot be empty.';
    if (trimmed.length > 500) return 'Comment must be 500 characters or fewer.';

    _isSubmitting = true;
    notifyListeners();

    try {
      await VideoService.updateComment(commentId: commentId, comment: trimmed);
      _editingCommentId = null;
      _isSubmitting = false;
      _successMessage = 'Comment updated.';
      await loadComments();
      return null;
    } catch (e) {
      _isSubmitting = false;
      final msg = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return msg;
    }
  }

  /// Returns null on success, or an error message string on failure.
  Future<String?> deleteComment(String commentId) async {
    try {
      await VideoService.deleteComment(commentId: commentId);
      if (_editingCommentId == commentId) _editingCommentId = null;
      _successMessage = 'Comment deleted.';
      await loadComments();
      return null;
    } catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return msg;
    }
  }

  /// Toggles comments on/off. Returns null on success, error message on failure.
  Future<String?> toggleComments() async {
    try {
      final result = await VideoService.toggleComments(videoId: videoId);
      _commentsDisabled = result['comments_disabled'] as bool? ?? _commentsDisabled;
      if (_commentsDisabled) _editingCommentId = null;
      _successMessage = _commentsDisabled
          ? 'Comments disabled for this video.'
          : 'Comments enabled for this video.';
      notifyListeners();
      return null;
    } catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return msg;
    }
  }
}
