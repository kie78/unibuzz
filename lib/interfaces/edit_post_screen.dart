import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class EditPostScreen extends StatefulWidget {
  const EditPostScreen({super.key, this.postId});

  final String? postId;

  @override
  State<EditPostScreen> createState() => _EditPostScreenState();
}

class _EditPostScreenState extends State<EditPostScreen> {
  late TextEditingController _captionController;
  late TextEditingController _hashtagsController;

  final String _initialCaption = 'Amazing moment with friends at the campus!';
  final String _initialHashtags = '#unibuzz #friends #campus';

  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _captionController = TextEditingController(text: _initialCaption);
    _hashtagsController = TextEditingController(text: _initialHashtags);

    _captionController.addListener(_updateChangesState);
    _hashtagsController.addListener(_updateChangesState);
  }

  void _updateChangesState() {
    final hasChanges =
        _captionController.text != _initialCaption ||
        _hashtagsController.text != _initialHashtags;

    if (hasChanges != _hasChanges) {
      setState(() {
        _hasChanges = hasChanges;
      });
    }
  }

  @override
  void dispose() {
    _captionController.dispose();
    _hashtagsController.dispose();
    super.dispose();
  }

  void _handleCancel() {
    if (!_hasChanges) {
      Navigator.of(context).pop();
      return;
    }

    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          title: const Text(
            'Discard changes?',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            'You have unsaved changes. Are you sure you want to discard them?',
            style: TextStyle(color: Color(0xFFB8B8B8)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text(
                'Keep editing',
                style: TextStyle(color: Color(0xFF00B4D8)),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                Navigator.of(context).pop();
              },
              child: const Text(
                'Discard',
                style: TextStyle(color: Color(0xFFFF4D4D)),
              ),
            ),
          ],
        );
      },
    );
  }

  void _handleSave() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Post changes saved')));
    Navigator.of(context).pop();
  }

  void _handleTrimVideo() {
    // Trimming has been removed from this app.
  }

  void _handleReplaceClip() async {
    final ImagePicker imagePicker = ImagePicker();
    final XFile? pickedVideo = await imagePicker.pickVideo(
      source: ImageSource.gallery,
    );

    if (!mounted || pickedVideo == null) {
      return;
    }

    // Video selected; trimming has been removed — proceed with the raw clip.
  }

  void _editCaption() {
    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        final captionEditController = TextEditingController(
          text: _captionController.text,
        );

        return AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          title: const Text(
            'Edit Caption',
            style: TextStyle(color: Colors.white),
          ),
          content: TextField(
            controller: captionEditController,
            maxLines: 5,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFF121212),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
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
                _captionController.text = captionEditController.text;
                Navigator.of(dialogContext).pop();
              },
              child: const Text(
                'Save',
                style: TextStyle(color: Color(0xFF00B4D8)),
              ),
            ),
          ],
        );
      },
    );
  }

  void _editHashtags() {
    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        final hashtagEditController = TextEditingController(
          text: _hashtagsController.text,
        );

        return AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          title: const Text(
            'Edit Hashtags',
            style: TextStyle(color: Colors.white),
          ),
          content: TextField(
            controller: hashtagEditController,
            maxLines: 3,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFF121212),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
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
                _hashtagsController.text = hashtagEditController.text;
                Navigator.of(dialogContext).pop();
              },
              child: const Text(
                'Save',
                style: TextStyle(color: Color(0xFF00B4D8)),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_hasChanges,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _hasChanges) {
          _handleCancel();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0B0B0B),
        appBar: AppBar(
          backgroundColor: const Color(0xFF0B0B0B),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: _handleCancel,
          ),
          title: Text(
            'Edit Post',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          centerTitle: true,
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _hasChanges ? _handleSave : null,
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _hasChanges
                              ? const Color(0xFF00B4D8)
                              : const Color(0xFF666666),
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        'Save',
                        style: TextStyle(
                          color: _hasChanges
                              ? const Color(0xFF00B4D8)
                              : const Color(0xFF999999),
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Media Preview & Progress Scrubber
                Container(
                  width: double.infinity,
                  height: 180,
                  decoration: BoxDecoration(
                    color: const Color(0xFF141414),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Stack(
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
                      const Icon(
                        Icons.play_arrow,
                        color: Colors.white,
                        size: 48,
                      ),
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
                          child: const Text(
                            '0:20',
                            style: TextStyle(
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
                // Progress Scrubber
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Container(
                    width: double.infinity,
                    height: 3,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A2A2A),
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 80,
                          height: 3,
                          decoration: BoxDecoration(
                            color: const Color(0xFF00B4D8),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Action Buttons
                Row(
                  children: [
                    // Trim Video
                    Expanded(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _handleTrimVideo,
                          borderRadius: BorderRadius.circular(12),
                          splashColor: Colors.white.withValues(alpha: 0.1),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1A1A1A),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.content_cut,
                                  color: Color(0xFF00B4D8),
                                  size: 24,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Trim Video',
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Replace Clip
                    Expanded(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _handleReplaceClip,
                          borderRadius: BorderRadius.circular(12),
                          splashColor: Colors.white.withValues(alpha: 0.1),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1A1A1A),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.refresh,
                                  color: Color(0xFF00B4D8),
                                  size: 24,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Replace Clip',
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Caption Card
                _buildEditCard(
                  context,
                  label: 'CAPTION',
                  content: _captionController.text,
                  onEdit: _editCaption,
                ),
                const SizedBox(height: 12),
                // Hashtags Card
                _buildEditCard(
                  context,
                  label: 'HASHTAGS',
                  content: _hashtagsController.text,
                  onEdit: _editHashtags,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEditCard(
    BuildContext context, {
    required String label,
    required String content,
    required VoidCallback onEdit,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(12),
        splashColor: Colors.white.withValues(alpha: 0.06),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: const Color(0xFF00B4D8),
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      content,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Icon(Icons.edit, color: Colors.white, size: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
