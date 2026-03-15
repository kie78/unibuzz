import 'package:flutter/material.dart';
import 'package:unibuzz/interfaces/comment_section.dart';
import 'package:unibuzz/interfaces/full_screen_view.dart';
import 'package:unibuzz/interfaces/report_screen.dart';

class FeedScreen extends StatelessWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0B),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Top Header
            SliverAppBar(
              backgroundColor: const Color(0xFF0B0B0B),
              elevation: 0,
              scrolledUnderElevation: 0,
              pinned: true,
              toolbarHeight: 56,
              title: const Text(
                'Unibuzz',
                style: TextStyle(
                  color: Color(0xFF00B4D8),
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF00B4D8),
                        width: 2,
                      ),
                    ),
                    child: const CircleAvatar(
                      radius: 18,
                      backgroundColor: Color(0xFF1A1A1A),
                      child: Icon(
                        Icons.person,
                        color: Color(0xFF00B4D8),
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            // Feed Content Cards
            SliverList(
              delegate: SliverChildBuilderDelegate((
                BuildContext context,
                int index,
              ) {
                return _BuzzCard(index: index);
              }, childCount: 10),
            ),
          ],
        ),
      ),
    );
  }
}

class _BuzzCard extends StatefulWidget {
  final int index;

  const _BuzzCard({required this.index});

  @override
  State<_BuzzCard> createState() => _BuzzCardState();
}

class _BuzzCardState extends State<_BuzzCard> {
  int? _voteState; // null = no vote, 1 = upvote, -1 = downvote

  void _handleUpvote() {
    setState(() {
      _voteState = _voteState == 1 ? null : 1;
    });
  }

  void _handleDownvote() {
    setState(() {
      _voteState = _voteState == -1 ? null : -1;
    });
  }

  void _showOptionsMenu() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(
                  Icons.flag_outlined,
                  color: Color(0xFFFF4D4D),
                ),
                title: const Text(
                  'Report',
                  style: TextStyle(color: Color(0xFFFF4D4D)),
                ),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (BuildContext context) => const ReportScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (BuildContext context) => FullScreenVideoView(
              cardIndex: widget.index,
              heroTag: 'video-card-${widget.index}',
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Card Header: Avatar, Username, University/Year
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 20,
                    backgroundColor: Color(0xFF00B4D8),
                    child: Icon(Icons.person, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'User ${widget.index + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Text(
                        'Stanford University • 3rd Year',
                        style: TextStyle(
                          color: Color(0xFF999999),
                          fontSize: 12,
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Visual Asset: 16:9 Media Container
            Hero(
              tag: 'video-card-${widget.index}',
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    children: [
                    Container(
                      width: double.infinity,
                      height: 200,
                      color: const Color(0xFF0B0B0B),
                    ),
                  // Timestamp Overlay
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          '2 hours ago',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            ),
            // Caption Area with Hashtags
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    children: [
                      Text(
                        'Check out this amazing moment from campus! ',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                      Text(
                        '#unibuzz',
                        style: const TextStyle(
                          color: Color(0xFF00B4D8),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(' ', style: const TextStyle(color: Colors.white)),
                      Text(
                        '#university',
                        style: const TextStyle(
                          color: Color(0xFF00B4D8),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Interaction Bar
                  Row(
                    children: [
                      // Voting Pill
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0B0B0B),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            GestureDetector(
                              onTap: _handleUpvote,
                              child: Icon(
                                Icons.arrow_upward,
                                size: 16,
                                color: _voteState == 1
                                    ? const Color(0xFF00B4D8)
                                    : Colors.white,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              '1.2k',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 8),
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
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Comments Pill
                      GestureDetector(
                        onTap: () {
                          showModalBottomSheet<void>(
                            context: context,
                            builder: (BuildContext context) =>
                                CommentSheet(cardIndex: widget.index),
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0B0B0B),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(
                                Icons.comment_outlined,
                                size: 16,
                                color: Colors.white,
                              ),
                              SizedBox(width: 8),
                              Text(
                                '342',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Spacer(),
                      // Options Icon
                      IconButton(
                        icon: const Icon(Icons.more_vert, color: Colors.white),
                        onPressed: _showOptionsMenu,
                        iconSize: 18,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
