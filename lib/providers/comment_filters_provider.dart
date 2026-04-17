import 'package:flutter/foundation.dart';
import 'package:unibuzz/services/video_service.dart';

class CommentFiltersProvider extends ChangeNotifier {
  List<Map<String, dynamic>> _filters = [];
  bool _isLoading = false;
  String? _error;
  bool _isAddingFilter = false;

  List<Map<String, dynamic>> get filters => List.unmodifiable(_filters);
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAddingFilter => _isAddingFilter;

  void clearError() {
    _error = null;
    notifyListeners();
  }

  Future<void> loadFilters() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _filters = await VideoService.getCommentFilters();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Returns null on success, or a user-facing error message on failure.
  Future<String?> addFilter(String keyword) async {
    final trimmed = keyword.trim();
    if (trimmed.isEmpty) return 'Please enter a keyword.';

    _isAddingFilter = true;
    notifyListeners();

    try {
      await VideoService.addCommentFilter(keyword: trimmed);
      _isAddingFilter = false;
      await loadFilters();
      return null;
    } catch (e) {
      _isAddingFilter = false;
      String msg = e.toString().replaceFirst('Exception: ', '').trim();
      if (msg.contains('already exists')) {
        msg = 'This keyword is already in your filter list.';
      } else if (msg.contains('50') || msg.contains('maximum')) {
        msg = 'You have reached the maximum of 50 filter keywords.';
      }
      notifyListeners();
      return msg;
    }
  }

  /// Returns null on success, or a user-facing error message on failure.
  Future<String?> deleteFilter(String filterId) async {
    try {
      await VideoService.deleteCommentFilter(filterId: filterId);
      await loadFilters();
      return null;
    } catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return msg;
    }
  }
}
