import 'dart:async';

import 'package:flutter/material.dart';
import 'package:unibuzz/app_colors.dart';
import 'package:unibuzz/interfaces/full_screen_view.dart';
import 'package:unibuzz/services/video_service.dart';

Widget _buildAvatarWidget({
  required double radius,
  required String? imageUrl,
  required Color backgroundColor,
  required Color iconColor,
  required double iconSize,
}) {
  final normalizedUrl = imageUrl?.trim();
  final hasImage = normalizedUrl != null && normalizedUrl.isNotEmpty;

  return CircleAvatar(
    radius: radius,
    backgroundColor: backgroundColor,
    child: hasImage
        ? ClipOval(
            child: Image.network(
              normalizedUrl,
              width: radius * 2,
              height: radius * 2,
              fit: BoxFit.cover,
              errorBuilder:
                  (BuildContext context, Object error, StackTrace? stackTrace) {
                    return Icon(Icons.person, color: iconColor, size: iconSize);
                  },
            ),
          )
        : Icon(Icons.person, color: iconColor, size: iconSize),
  );
}

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  String? _selectedTag;
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  bool _isLoading = false;
  String? _error;
  String _activeQuery = '';
  int _requestToken = 0;
  List<Map<String, dynamic>> _results = <Map<String, dynamic>>[];

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

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchTextChanged);
  }

  void _onSearchTextChanged() {
    final input = _searchController.text.trim();

    if (_selectedTag != null && input.isNotEmpty) {
      setState(() {
        _selectedTag = null;
      });
    } else {
      setState(() {});
    }

    _searchDebounce?.cancel();

    if (input.isEmpty) {
      if (_selectedTag == null) {
        _clearSearchState();
      }
      return;
    }

    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      _runSearch(rawQuery: input);
    });
  }

  void _clearSearchState() {
    _requestToken += 1;
    setState(() {
      _isLoading = false;
      _error = null;
      _activeQuery = '';
      _results = <Map<String, dynamic>>[];
    });
  }

  String _normalizeQuery(String query) {
    return query.trim().replaceFirst(RegExp(r'^[#@]+'), '').trim();
  }

  String? _extractVideoId(Map<String, dynamic> video) {
    return VideoService.extractVideoId(video);
  }

  List<Map<String, dynamic>> _normalizeResults(List<dynamic> rawResults) {
    final normalized = <Map<String, dynamic>>[];
    final seenIds = <String>{};

    for (final item in rawResults) {
      if (item is! Map) continue;

      final map = Map<String, dynamic>.from(item);
      final fallbackId =
          '${map['video_url'] ?? ''}:${map['created_at'] ?? ''}:${normalized.length}';
      final id = _extractVideoId(map) ?? fallbackId;

      if (seenIds.add(id)) {
        normalized.add(map);
      }
    }

    return normalized;
  }

  Future<void> _runSearch({String? rawQuery, String? tagOverride}) async {
    final rawInput = tagOverride ?? rawQuery ?? _searchController.text.trim();
    final normalized = _normalizeQuery(rawInput);

    if (normalized.isEmpty) {
      _clearSearchState();
      return;
    }

    final bool forceTag = tagOverride != null;
    final bool hashtagQuery = forceTag || rawInput.trim().startsWith('#');
    final bool usernameQuery = !forceTag && rawInput.trim().startsWith('@');
    final String queryLabel = hashtagQuery
        ? '#$normalized'
        : usernameQuery
        ? '@$normalized'
        : normalized;

    final requestToken = ++_requestToken;

    setState(() {
      _isLoading = true;
      _error = null;
      _activeQuery = queryLabel;
    });

    try {
      late final List<dynamic> rawResults;

      if (hashtagQuery) {
        rawResults = await VideoService.searchVideos(tag: normalized);
      } else if (usernameQuery) {
        rawResults = await VideoService.searchVideos(username: normalized);
      } else {
        final byTag = await VideoService.searchVideos(tag: normalized);
        final byUsername = await VideoService.searchVideos(
          username: normalized,
        );
        rawResults = <dynamic>[...byTag, ...byUsername];
      }

      if (!mounted || requestToken != _requestToken) {
        return;
      }

      setState(() {
        _results = _normalizeResults(rawResults);
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted || requestToken != _requestToken) {
        return;
      }

      setState(() {
        _isLoading = false;
        _results = <Map<String, dynamic>>[];
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _retrySearch() async {
    if (_selectedTag != null) {
      await _runSearch(tagOverride: _selectedTag);
      return;
    }

    final query = _searchController.text.trim();
    if (query.isEmpty) {
      _clearSearchState();
      return;
    }

    await _runSearch(rawQuery: query);
  }

  void _selectTag(String tag) {
    FocusScope.of(context).unfocus();
    _searchDebounce?.cancel();
    _searchController.clear();

    setState(() {
      _selectedTag = tag;
    });

    _runSearch(tagOverride: tag);
  }

  void _clearAllFilters() {
    _searchDebounce?.cancel();
    _searchController.clear();

    setState(() {
      _selectedTag = null;
    });

    _clearSearchState();
  }

  bool get _hasActiveSearch {
    return _selectedTag != null ||
        _searchController.text.trim().isNotEmpty ||
        _activeQuery.isNotEmpty;
  }

  Widget _buildTagCloud() {
    return ListView.builder(
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
    );
  }

  Widget _buildResultsList() {
    return RefreshIndicator(
      onRefresh: _retrySearch,
      color: const Color(0xFF00B4D8),
      backgroundColor: context.cardBg,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
        itemCount: _results.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (BuildContext context, int index) {
          return _DiscoverResultCard(video: _results[index], index: index);
        },
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00B4D8)),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, color: context.primaryText, size: 34),
            const SizedBox(height: 12),
            Text(
              'Search failed',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: context.primaryText,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'Unable to fetch results right now.',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: const Color(0xFF999999)),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _retrySearch,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00B4D8),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final label = _activeQuery.isEmpty ? 'your search' : _activeQuery;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.travel_explore,
              color: Color(0xFF00B4D8),
              size: 34,
            ),
            const SizedBox(height: 10),
            Text(
              'No results for $label',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: context.primaryText,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Try a different hashtag or @username.',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: context.secondaryText),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBodyContent() {
    if (_isLoading) {
      return _buildLoadingState();
    }

    if (_error != null) {
      return _buildErrorState();
    }

    if (_results.isNotEmpty) {
      return _buildResultsList();
    }

    if (_hasActiveSearch) {
      return _buildEmptyState();
    }

    return _buildTagCloud();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.removeListener(_onSearchTextChanged);
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBg,
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
                  Text(
                    'EXPLORE COMMUNITIES',
                    style: TextStyle(
                      color: context.primaryText,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Fixed Search Bar
                  TextField(
                    controller: _searchController,
                    style: TextStyle(color: context.primaryText, fontSize: 14),
                    cursorColor: const Color(0xFF00B4D8),
                    onSubmitted: (value) {
                      _searchDebounce?.cancel();
                      _runSearch(rawQuery: value);
                    },
                    decoration: InputDecoration(
                      hintText: 'Search #hashtags or @username',
                      hintStyle: const TextStyle(
                        color: Color(0xFF999999),
                        fontSize: 14,
                      ),
                      prefixIcon: const Icon(
                        Icons.search,
                        color: Color(0xFF00B4D8),
                        size: 20,
                      ),
                      suffixIcon:
                          _searchController.text.trim().isNotEmpty ||
                              _selectedTag != null
                          ? IconButton(
                              onPressed: _clearAllFilters,
                              icon: const Icon(
                                Icons.close,
                                color: Color(0xFF999999),
                                size: 18,
                              ),
                            )
                          : null,
                      filled: true,
                      fillColor: context.inputFillBg,
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
            if (_selectedTag != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF14222A),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: const Color(0xFF00B4D8),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        '#$_selectedTag',
                        style: const TextStyle(
                          color: Color(0xFF00B4D8),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: _clearAllFilters,
                      child: const Text(
                        'Clear',
                        style: TextStyle(color: Color(0xFF999999)),
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(child: _buildBodyContent()),
          ],
        ),
      ),
    );
  }
}

class _DiscoverResultCard extends StatelessWidget {
  const _DiscoverResultCard({required this.video, required this.index});

  final Map<String, dynamic> video;
  final int index;

  dynamic _readValueForPath(String path) {
    final segments = path.split('.');
    dynamic current = video;

    for (final segment in segments) {
      if (current is Map<String, dynamic>) {
        current = current[segment];
      } else if (current is Map) {
        current = current[segment];
      } else {
        return null;
      }
    }

    return current;
  }

  dynamic _readFirstValue(List<String> paths) {
    for (final path in paths) {
      final value = _readValueForPath(path);
      if (value != null) {
        return value;
      }
    }
    return null;
  }

  String? _readNonEmptyString(List<String> paths) {
    for (final path in paths) {
      final value = _readValueForPath(path);
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
      if (value is num || value is bool) {
        final asText = value.toString().trim();
        if (asText.isNotEmpty) {
          return asText;
        }
      }
    }
    return null;
  }

  String _captionWithoutHashtags(String caption) {
    if (caption.isEmpty) return caption;
    final cleaned = caption
        .replaceAll(RegExp(r'(^|\s)#[A-Za-z0-9_]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return cleaned.isEmpty ? caption : cleaned;
  }

  String? _readNonEmptyImageUrl(List<String> paths) {
    for (final path in paths) {
      final value = _readValueForPath(path);
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return null;
  }

  String? get _authorAvatarUrl {
    return _readNonEmptyImageUrl(<String>[
      'profile_photo_url',
      'avatar_url',
      'photo_url',
      'image_url',
      'user.profile_photo_url',
      'user.avatar_url',
      'user.photo_url',
      'author.profile_photo_url',
      'author.avatar_url',
      'author.photo_url',
      'uploader.profile_photo_url',
      'uploader.avatar_url',
      'uploader.photo_url',
      'posted_by.profile_photo_url',
      'posted_by.avatar_url',
      'creator.profile_photo_url',
      'creator.avatar_url',
    ]);
  }

  String get _displayName {
    final username = _readNonEmptyString(<String>[
      'username',
      'user_name',
      'user.username',
      'author.username',
      'uploader.username',
    ]);
    if (username != null) {
      return username.startsWith('@') ? username : '@$username';
    }

    final fullName = _readNonEmptyString(<String>[
      'full_name',
      'name',
      'user.full_name',
      'user.name',
      'author.full_name',
      'author.name',
      'uploader.full_name',
      'uploader.name',
    ]);
    if (fullName != null) {
      return fullName;
    }

    final userId = _readNonEmptyString(<String>[
      'user_id',
      'author_id',
      'user.id',
      'author.id',
      'uploader.id',
    ]);
    if (userId != null) {
      final shortId = userId.length > 8 ? userId.substring(0, 8) : userId;
      return 'User $shortId';
    }

    return 'Student';
  }

  String _formatYearLabel(dynamic rawYear) {
    final int? year = rawYear is int
        ? rawYear
        : int.tryParse(rawYear?.toString() ?? '');
    if (year == null || year <= 0) return '';

    final int mod100 = year % 100;
    if (mod100 >= 11 && mod100 <= 13) {
      return '${year}th Year';
    }

    switch (year % 10) {
      case 1:
        return '${year}st Year';
      case 2:
        return '${year}nd Year';
      case 3:
        return '${year}rd Year';
      default:
        return '${year}th Year';
    }
  }

  String get _profileMeta {
    final university = _readNonEmptyString(<String>[
      'university_name',
      'university',
      'user.university_name',
      'author.university_name',
      'uploader.university_name',
    ]);
    final yearLabel = _formatYearLabel(
      _readFirstValue(<String>[
        'year_of_study',
        'year',
        'user.year_of_study',
        'author.year_of_study',
        'uploader.year_of_study',
      ]),
    );

    if (university != null && yearLabel.isNotEmpty) {
      return '$university • $yearLabel';
    }
    if (university != null) {
      return university;
    }
    if (yearLabel.isNotEmpty) {
      return yearLabel;
    }
    return '';
  }

  String get _caption {
    final caption = _readNonEmptyString(<String>['caption', 'description']);
    if (caption != null) {
      return _captionWithoutHashtags(caption);
    }
    return 'A new moment from campus';
  }

  List<String> get _hashtags {
    final dynamic rawTags = _readFirstValue(<String>[
      'tags',
      'hashtags',
      'meta.tags',
      'metadata.tags',
    ]);
    final tags = <String>{};

    void addTag(dynamic value) {
      final text = value?.toString().trim() ?? '';
      if (text.isEmpty) return;
      tags.add(text.startsWith('#') ? text : '#$text');
    }

    if (rawTags is List) {
      for (final tag in rawTags) {
        addTag(tag);
      }
    } else if (rawTags is String && rawTags.trim().isNotEmpty) {
      for (final tag in rawTags.split(',')) {
        addTag(tag);
      }
    }

    if (tags.isEmpty) {
      final rawCaption = _readNonEmptyString(<String>[
        'caption',
        'description',
      ]);
      if (rawCaption != null) {
        final matches = RegExp(r'#[A-Za-z0-9_]+').allMatches(rawCaption);
        for (final match in matches) {
          addTag(match.group(0));
        }
      }
    }

    return tags.take(3).toList();
  }

  String? get _thumbnailUrl {
    return _readNonEmptyString(<String>[
      'thumbnail_url',
      'thumbnail',
      'preview_url',
      'media.thumbnail_url',
      'media.preview_url',
    ]);
  }

  String? get _videoId {
    final id = _readFirstValue(<String>['id', 'video_id']);
    final value = id?.toString().trim();
    if (value == null || value.isEmpty) {
      return null;
    }
    return value;
  }

  String get _timestampLabel {
    final createdAt = _readNonEmptyString(<String>['created_at']);
    if (createdAt != null) {
      try {
        final dt = DateTime.parse(createdAt).toLocal();
        final day = dt.day.toString().padLeft(2, '0');
        final month = dt.month.toString().padLeft(2, '0');
        final yearTwoDigits = (dt.year % 100).toString().padLeft(2, '0');
        return '$day/$month/$yearTwoDigits';
      } catch (_) {
        return 'Just now';
      }
    }
    return 'Just now';
  }

  @override
  Widget build(BuildContext context) {
    final heroTag = 'discover-video-${_videoId ?? index}';

    return GestureDetector(
      onTap: () async {
        await Navigator.of(context).push<Map<String, int?>>(
          MaterialPageRoute<Map<String, int?>>(
            builder: (BuildContext context) => FullScreenVideoView(
              cardIndex: index,
              video: video,
              heroTag: heroTag,
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: context.cardBg,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: Row(
                children: [
                  _buildAvatarWidget(
                    radius: 18,
                    backgroundColor: Color(0xFF00B4D8),
                    imageUrl: _authorAvatarUrl,
                    iconColor: Colors.white,
                    iconSize: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: context.primaryText,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (_profileMeta.isNotEmpty)
                          Text(
                            _profileMeta,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: context.secondaryText,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Text(
                    _timestampLabel,
                    style: TextStyle(
                      color: context.tertiaryText,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Hero(
              tag: heroTag,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: double.infinity,
                  height: 190,
                  child: _thumbnailUrl != null
                      ? Image.network(
                          _thumbnailUrl!,
                          fit: BoxFit.cover,
                          cacheHeight: 285,
                          cacheWidth: 360,
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
                                  color: const Color(0xFF0B0B0B),
                                  child: const Center(
                                    child: CircularProgressIndicator(
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Color(0xFF00B4D8),
                                      ),
                                    ),
                                  ),
                                );
                              },
                          errorBuilder:
                              (
                                BuildContext context,
                                Object error,
                                StackTrace? stackTrace,
                              ) {
                                return Container(
                                  color: const Color(0xFF0B0B0B),
                                  child: const Center(
                                    child: Icon(
                                      Icons.play_circle_outline,
                                      color: Color(0xFF00B4D8),
                                      size: 42,
                                    ),
                                  ),
                                );
                              },
                        )
                      : Container(
                          color: const Color(0xFF0B0B0B),
                          child: const Center(
                            child: Icon(
                              Icons.play_circle_outline,
                              color: Color(0xFF00B4D8),
                              size: 42,
                            ),
                          ),
                        ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  Text(
                    _caption,
                    style: TextStyle(
                      color: context.primaryText,
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  if (_hashtags.isNotEmpty)
                    Text(
                      _hashtags.join(' '),
                      style: const TextStyle(
                        color: Color(0xFF00B4D8),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
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
          color: context.cardBg,
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
                style: TextStyle(
                  color: context.primaryText,
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
