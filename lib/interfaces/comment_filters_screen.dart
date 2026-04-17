import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:unibuzz/providers/comment_filters_provider.dart';

class CommentFiltersScreen extends StatefulWidget {
  const CommentFiltersScreen({super.key});

  @override
  State<CommentFiltersScreen> createState() => _CommentFiltersScreenState();
}

class _CommentFiltersScreenState extends State<CommentFiltersScreen> {
  final TextEditingController _keywordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<CommentFiltersProvider>().loadFilters();
    });
  }

  @override
  void dispose() {
    _keywordController.dispose();
    super.dispose();
  }

  Future<void> _addFilter(CommentFiltersProvider provider) async {
    final keyword = _keywordController.text.trim();
    final error = await provider.addFilter(keyword);
    if (!mounted) return;

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: const Color(0xFFFF4D4D),
        ),
      );
    } else {
      _keywordController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Filter "$keyword" added'),
          backgroundColor: const Color(0xFF00B4D8),
        ),
      );
    }
  }

  Future<void> _deleteFilter(
    CommentFiltersProvider provider,
    String filterId,
    String keyword,
  ) async {
    final error = await provider.deleteFilter(filterId);
    if (!mounted) return;

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: const Color(0xFFFF4D4D),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Filter "$keyword" removed'),
          backgroundColor: const Color(0xFF00B4D8),
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
      body: Consumer<CommentFiltersProvider>(
        builder: (context, provider, _) {
          return SafeArea(
            child: Column(
              children: [
                // Info card
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A3A4A),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFF00B4D8),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      'Comments containing any of these keywords will be hidden from your videos. '
                      'Matching is case-insensitive and partial (e.g., "spam" matches "spammer").',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFFB8B8B8),
                        height: 1.4,
                      ),
                    ),
                  ),
                ),

                // Add filter input
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
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
                              enabled: !provider.isAddingFilter,
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
                              onTap: provider.isAddingFilter
                                  ? null
                                  : () => _addFilter(provider),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: provider.isAddingFilter
                                      ? const Color(0xFF006B85)
                                      : const Color(0xFF00B4D8),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: provider.isAddingFilter
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
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

                // Filters list
                Expanded(child: _buildFilterList(context, provider)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFilterList(
    BuildContext context,
    CommentFiltersProvider provider,
  ) {
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
                'Error loading filters',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                provider.error!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF999999),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: provider.loadFilters,
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

    if (provider.filters.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.filter_none, color: Color(0xFF666666), size: 32),
              const SizedBox(height: 12),
              Text(
                'No filters yet',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: const Color(0xFF999999),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Add keywords above to filter comments on your videos',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF666666),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: provider.filters.length,
      itemBuilder: (BuildContext context, int index) {
        final filter = provider.filters[index];
        final filterId = filter['id']?.toString() ?? '';
        final keyword = filter['keyword']?.toString() ?? 'Unknown';

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF333333), width: 1),
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '"$keyword"',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (filter['created_at'] != null)
                        Text(
                          'Added ${_formatCreatedDate(filter['created_at'])}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF999999),
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => _deleteFilter(provider, filterId, keyword),
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
    );
  }

  String _formatCreatedDate(dynamic rawDate) {
    if (rawDate == null) return 'recently';
    try {
      final date = DateTime.parse(rawDate.toString()).toLocal();
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inSeconds < 60) return 'just now';
      if (difference.inMinutes < 60) return '${difference.inMinutes} min ago';
      if (difference.inHours < 24) return '${difference.inHours} h ago';
      if (difference.inDays < 7) return '${difference.inDays} d ago';
      return '${date.month}/${date.day}/${date.year}';
    } catch (_) {
      return 'recently';
    }
  }
}
