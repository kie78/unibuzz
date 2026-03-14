import 'package:flutter/material.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  String? _selectedTag;
  final TextEditingController _searchController = TextEditingController();

  static const List<String> _placeholderTags = [
    'ExamStress',
    'CampusLife',
    'StudyGroup',
    'MountainHiking',
    'DebatingClub',
    'MusicLovers',
    'GameNight',
    'QuickBreak',
    'TechTalk',
    'FitnessGoals',
    'BookClub',
    'CoffeeChatters',
  ];

  void _selectTag(String tag) {
    setState(() {
      _selectedTag = tag;
    });
    // Navigate to Results Screen
    // TODO: Push to Results screen for this hashtag
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0B),
      body: SafeArea(
        child: Column(
          children: [
            // Pinned Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Unibuzz',
                    style: TextStyle(
                      color: Color(0xFF00B4D8),
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'EXPLORE COMMUNITIES',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Fixed Search Bar
                  TextField(
                    controller: _searchController,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    cursorColor: const Color(0xFF00B4D8),
                    decoration: InputDecoration(
                      hintText: 'Search hashtags...',
                      hintStyle: const TextStyle(
                        color: Color(0xFF999999),
                        fontSize: 14,
                      ),
                      prefixIcon: const Icon(
                        Icons.search,
                        color: Color(0xFF00B4D8),
                        size: 20,
                      ),
                      filled: true,
                      fillColor: const Color(0xFF121212),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Scrollable Tag Cloud (Dual Column)
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: (_placeholderTags.length / 2).ceil(),
                itemBuilder: (context, rowIndex) {
                  final tag1Index = rowIndex * 2;
                  final tag2Index = rowIndex * 2 + 1;
                  final tag1 = _placeholderTags[tag1Index];
                  final tag2 = tag2Index < _placeholderTags.length
                      ? _placeholderTags[tag2Index]
                      : null;

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: _TagPill(
                            tag: tag1,
                            isSelected: _selectedTag == tag1,
                            onTap: () => _selectTag(tag1),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: tag2 != null
                              ? _TagPill(
                                  tag: tag2,
                                  isSelected: _selectedTag == tag2,
                                  onTap: () => _selectTag(tag2),
                                )
                              : const SizedBox.shrink(),
                        ),
                      ],
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
}

class _TagPill extends StatelessWidget {
  final String tag;
  final bool isSelected;
  final VoidCallback onTap;

  const _TagPill({
    required this.tag,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          border: isSelected
              ? Border.all(color: const Color(0xFF00B4D8), width: 2)
              : null,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF00B4D8).withValues(alpha: 0.5),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '#',
              style: TextStyle(
                color: const Color(0xFF00B4D8),
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                tag,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
