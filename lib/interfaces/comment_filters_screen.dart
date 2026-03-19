import 'package:flutter/material.dart';
import 'package:unibuzz/services/video_service.dart';

class CommentFiltersScreen extends StatefulWidget {
  const CommentFiltersScreen({super.key});

  @override
  State<CommentFiltersScreen> createState() => _CommentFiltersScreenState();
}

class _CommentFiltersScreenState extends State<CommentFiltersScreen> {
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _filters = <Map<String, dynamic>>[];
  final TextEditingController _keywordController = TextEditingController();
  bool _isAddingFilter = false;

  @override
  void initState() {
    super.initState();
    _loadFilters();
  }

  @override
  void dispose() {
    _keywordController.dispose();
    super.dispose();
  }

  Future<void> _loadFilters() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final filters = await VideoService.getCommentFilters();
      if (!mounted) return;
      setState(() {
        _filters = filters;
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

  Future<void> _addFilter() async {
    final keyword = _keywordController.text.trim();
    if (keyword.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter a keyword')));
      return;
    }

    setState(() {
      _isAddingFilter = true;
    });

    try {
      await VideoService.addCommentFilter(keyword: keyword);
      if (!mounted) return;
      _keywordController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Filter "$keyword" added'),
          backgroundColor: const Color(0xFF00B4D8),
        ),
      );
      setState(() {
        _isAddingFilter = false;
      });
      if (!mounted) return;
      await _loadFilters();
    } catch (e) {
      if (!mounted) return;
      String message = e.toString().replaceFirst('Exception: ', '').trim();
      // Handle specific backend error messages
      if (message.contains('already exists')) {
        message = 'This keyword is already in your filter list';
      } else if (message.contains('50')) {
        message = 'You have reached the maximum of 50 keywords';
      } else if (message.contains('empty')) {
        message = 'Please enter a valid keyword';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: const Color(0xFFFF4D4D),
        ),
      );
      setState(() {
        _isAddingFilter = false;
      });
    }
  }

  Future<void> _deleteFilter(String filterId, String keyword) async {
    try {
      await VideoService.deleteCommentFilter(filterId: filterId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Filter "$keyword" removed'),
          backgroundColor: const Color(0xFF00B4D8),
        ),
      );
      await _loadFilters();
    } catch (e) {
      if (!mounted) return;
      final message = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: const Color(0xFFFF4D4D),
        ),
      );
    }
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
          'Comment Filters',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Info Card
            Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A3A4A),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF00B4D8), width: 1),
                ),
                child: Text(
                  'Comments containing any of these keywords will be hidden from your videos. Matching is case-insensitive and partial (e.g., "spam" matches "spammer").',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFFB8B8B8),
                    height: 1.4,
                  ),
                ),
              ),
            ),

            // Add Filter Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Add Filter',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _keywordController,
                          style: const TextStyle(color: Colors.white),
                          cursorColor: const Color(0xFF00B4D8),
                          enabled: !_isAddingFilter,
                          decoration: InputDecoration(
                            hintText: 'Enter keyword...',
                            hintStyle: const TextStyle(
                              color: Color(0xFF666666),
                              fontSize: 14,
                            ),
                            filled: true,
                            fillColor: const Color(0xFF1A1A1A),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: Color(0xFF333333),
                                width: 1,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: Color(0xFF333333),
                                width: 1,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: Color(0xFF00B4D8),
                                width: 1.5,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _isAddingFilter ? null : _addFilter,
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: _isAddingFilter
                                  ? const Color(0xFF006B85)
                                  : const Color(0xFF00B4D8),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: _isAddingFilter
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : const Icon(
                                    Icons.add,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Filters List
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
                              'Error loading filters',
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _error!,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: const Color(0xFF999999)),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _loadFilters,
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
                    )
                  : _filters.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.filter_none,
                              color: Color(0xFF666666),
                              size: 32,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No filters yet',
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(
                                    color: const Color(0xFF999999),
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Add keywords above to filter comments on your videos',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: const Color(0xFF666666)),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _filters.length,
                      itemBuilder: (BuildContext context, int index) {
                        final filter = _filters[index];
                        final filterId = filter['id']?.toString() ?? '';
                        final keyword =
                            filter['keyword']?.toString() ?? 'Unknown';

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1A1A1A),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color(0xFF333333),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.check_circle_outline,
                                  color: Color(0xFF00B4D8),
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '"$keyword"',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w500,
                                            ),
                                      ),
                                      if (filter['created_at'] != null)
                                        Text(
                                          'Added ${_formatCreatedDate(filter['created_at'])}',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color: const Color(0xFF999999),
                                                fontSize: 12,
                                              ),
                                        ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  onPressed: () =>
                                      _deleteFilter(filterId, keyword),
                                  icon: const Icon(
                                    Icons.close,
                                    color: Color(0xFF999999),
                                    size: 20,
                                  ),
                                  splashRadius: 20,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                    minWidth: 40,
                                    minHeight: 40,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatCreatedDate(dynamic rawDate) {
    if (rawDate == null) return 'recently';
    try {
      final date = DateTime.parse(rawDate.toString()).toLocal();
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inSeconds < 60) {
        return 'just now';
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

      return '${date.month}/${date.day}/${date.year}';
    } catch (_) {
      return 'recently';
    }
  }
}
