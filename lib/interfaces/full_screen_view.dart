import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:unibuzz/interfaces/comment_section.dart';

class FullScreenVideoView extends StatefulWidget {
  const FullScreenVideoView({
    super.key,
    required this.cardIndex,
    this.heroTag = 'video-card',
  });

  final int cardIndex;
  final String heroTag;

  @override
  State<FullScreenVideoView> createState() => _FullScreenVideoViewState();
}

class _FullScreenVideoViewState extends State<FullScreenVideoView> {
  int? _voteState; // null = no vote, 1 = upvote, -1 = downvote
  final double _playbackProgress = 0.35; // 0-1, represents position in video

  void _handleUpvote() {
    setState(() {
      _voteState = _voteState == 1 ? null : 1;
      HapticFeedback.lightImpact();
    });
  }

  void _handleDownvote() {
    setState(() {
      _voteState = _voteState == -1 ? null : -1;
      HapticFeedback.lightImpact();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Full-bleed video background
            Hero(
              tag: widget.heroTag,
              child: Container(
                width: double.infinity,
                height: double.infinity,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF00B4D8), Color(0xFF0B7A92)],
                  ),
                ),
                child: const Center(
                  child: Icon(Icons.play_arrow, color: Colors.white, size: 80),
                ),
              ),
            ),

            // Top Navigation - Back Arrow
            Positioned(
              top: 16,
              left: 16,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: Material(
                    color: Colors.black.withValues(alpha: 0.4),
                    child: InkWell(
                      onTap: () => Navigator.of(context).pop(),
                      child: const SizedBox(
                        width: 44,
                        height: 44,
                        child: Center(
                          child: Icon(
                            Icons.arrow_back,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Bottom Content Overlay - Handle, Caption, Hashtags
            Positioned(
              bottom: 120,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 40, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '@student_user',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      children: [
                        Text(
                          'Check out this amazing moment from campus! ',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.normal,
                              ),
                        ),
                        Text(
                          '#unibuzz',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: const Color(0xFF00B4D8),
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        Text(
                          ' ',
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(color: Colors.white),
                        ),
                        Text(
                          '#university',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: const Color(0xFF00B4D8),
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Bottom Center Interaction Pill
            Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // User Avatar
                      const CircleAvatar(
                        radius: 16,
                        backgroundColor: Color(0xFF00B4D8),
                        child: Icon(
                          Icons.person,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                      // Vertical Divider
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 12),
                        width: 1,
                        height: 20,
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                      // Upvote
                      GestureDetector(
                        onTap: _handleUpvote,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.arrow_upward,
                              size: 16,
                              color: _voteState == 1
                                  ? const Color(0xFF00B4D8)
                                  : Colors.white,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '1.2k',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Downvote
                      GestureDetector(
                        onTap: _handleDownvote,
                        child: Icon(
                          Icons.arrow_downward,
                          size: 16,
                          color: _voteState == -1
                              ? const Color(0xFF00B4D8)
                              : const Color(0xFF999999),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Comment Divider
                      Container(
                        width: 1,
                        height: 20,
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                      const SizedBox(width: 12),
                      // Comments
                      GestureDetector(
                        onTap: () {
                          showModalBottomSheet<void>(
                            context: context,
                            builder: (BuildContext context) =>
                                CommentSheet(cardIndex: widget.cardIndex),
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                          );
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(
                              Icons.comment_outlined,
                              size: 16,
                              color: Colors.white,
                            ),
                            SizedBox(width: 4),
                            Text(
                              '45',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Bottom Progress Indicator
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 3,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                ),
                child: Row(
                  children: [
                    Container(
                      height: 3,
                      width:
                          MediaQuery.of(context).size.width * _playbackProgress,
                      color: const Color(0xFF00B4D8),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
