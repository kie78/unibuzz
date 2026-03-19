import 'package:flutter/material.dart';
import 'package:unibuzz/services/video_service.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({
    super.key,
    required this.videoId,
    this.caption,
    this.thumbnailUrl,
    this.authorName,
    this.profileMeta,
  });

  final String videoId;
  final String? caption;
  final String? thumbnailUrl;
  final String? authorName;
  final String? profileMeta;

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  static const int _maxCustomReasonLength = 100;

  String _selectedReason = 'harassment';
  final TextEditingController _detailsController = TextEditingController();
  bool _isSubmitting = false;

  final List<Map<String, String>> _reportReasons = [
    {'value': 'self_harm', 'label': 'Self-Harm'},
    {'value': 'harassment', 'label': 'Harassment'},
    {'value': 'inappropriate_content', 'label': 'Inappropriate Content'},
    {'value': 'spam', 'label': 'Spam'},
    {'value': 'other', 'label': 'Other'},
  ];

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  String get _captionPreview {
    final caption = widget.caption?.trim();
    if (caption == null || caption.isEmpty) {
      return 'No caption provided for this post.';
    }
    return caption;
  }

  Widget _buildThumbnailFallback() {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(
        fit: StackFit.expand,
        alignment: Alignment.center,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF00B4D8), Color(0xFF0B7A92)],
              ),
            ),
          ),
          Container(color: Colors.black.withValues(alpha: 0.2)),
          const Icon(Icons.play_arrow, color: Colors.white, size: 24),
        ],
      ),
    );
  }

  Widget _buildThumbnailPreview() {
    final thumbnailUrl = widget.thumbnailUrl?.trim();
    if (thumbnailUrl == null || thumbnailUrl.isEmpty) {
      return _buildThumbnailFallback();
    }

    return SizedBox(
      width: 60,
      height: 60,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
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
                    return Container(
                      color: const Color(0xFF141414),
                      alignment: Alignment.center,
                      child: const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Color(0xFF00B4D8),
                          ),
                        ),
                      ),
                    );
                  },
              errorBuilder:
                  (BuildContext context, Object error, StackTrace? stackTrace) {
                    return _buildThumbnailFallback();
                  },
            ),
            Container(color: Colors.black.withValues(alpha: 0.2)),
            const Center(
              child: Icon(Icons.play_arrow, color: Colors.white, size: 24),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSubmit() async {
    if (_isSubmitting) {
      return;
    }

    if (_selectedReason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a reason for reporting')),
      );
      return;
    }

    final customReason = _detailsController.text.trim();

    if (_selectedReason == 'other' && customReason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please provide additional details for "Other".'),
        ),
      );
      return;
    }

    if (_selectedReason == 'other' &&
        customReason.length > _maxCustomReasonLength) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Additional details must be 100 characters or fewer.'),
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await VideoService.reportVideo(
        videoId: widget.videoId,
        reason: _selectedReason,
        customReason: _selectedReason == 'other' ? customReason : null,
      );

      if (!mounted) return;

      setState(() {
        _isSubmitting = false;
      });

      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1A1A1A),
            title: const Text(
              'Report Submitted',
              style: TextStyle(color: Colors.white),
            ),
            content: const Text(
              'Thank you for your report. We\'ll review it shortly.',
              style: TextStyle(color: Color(0xFFB8B8B8)),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  Navigator.of(context).pop(true);
                },
                child: const Text(
                  'Got it',
                  style: TextStyle(color: Color(0xFF00B4D8)),
                ),
              ),
            ],
          );
        },
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isSubmitting = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
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
          'Report Content',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Content Summary Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'REPORTED POST',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: const Color(0xFF00B4D8),
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildThumbnailPreview(),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                widget.authorName?.trim().isNotEmpty == true
                                    ? widget.authorName!.trim()
                                    : 'Post author',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.labelMedium
                                    ?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                              if (widget.profileMeta?.trim().isNotEmpty ==
                                  true) ...[
                                const SizedBox(height: 2),
                                Text(
                                  widget.profileMeta!.trim(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: const Color(0xFFA0A0A0),
                                      ),
                                ),
                              ],
                              const SizedBox(height: 6),
                              Text(
                                _captionPreview,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w500,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              // Reason for Reporting Section
              Text(
                'Reason for reporting',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
              // Radio Options
              Column(
                children: _reportReasons.map((reason) {
                  final value = reason['value']!;
                  final label = reason['label']!;
                  final isSelected = _selectedReason == value;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _selectedReason = value;
                          });
                        },
                        borderRadius: BorderRadius.circular(20),
                        splashColor: Colors.white.withValues(alpha: 0.06),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF121212),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFF00B4D8)
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSelected
                                        ? const Color(0xFF00B4D8)
                                        : const Color(0xFF666666),
                                    width: 2,
                                  ),
                                ),
                                child: isSelected
                                    ? DecoratedBox(
                                        decoration: const BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Color(0xFF00B4D8),
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.all(4),
                                          child: Container(
                                            decoration: const BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: Color(0xFF00B4D8),
                                            ),
                                          ),
                                        ),
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                label,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w500,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 28),
              // Additional Details Section (only show when "Other" is selected)
              if (_selectedReason == 'other') ...[
                Text(
                  'Additional Details',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _detailsController,
                  maxLines: 5,
                  maxLength: _maxCustomReasonLength,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                  decoration: InputDecoration(
                    hintText:
                        'Provide more details (required, max 100 chars)...',
                    hintStyle: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 14,
                    ),
                    filled: true,
                    fillColor: const Color(0xFF121212),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    counterStyle: const TextStyle(
                      color: Color(0xFF8B8B8B),
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 28),
              ],
              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: Material(
                  color: _isSubmitting
                      ? const Color(0xFF00B4D8).withValues(alpha: 0.6)
                      : const Color(0xFF00B4D8),
                  borderRadius: BorderRadius.circular(24),
                  child: InkWell(
                    onTap: _isSubmitting ? null : _handleSubmit,
                    borderRadius: BorderRadius.circular(24),
                    child: Center(
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.black,
                                ),
                              ),
                            )
                          : Text(
                              'Submit Report',
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(
                                    color: Colors.black,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
