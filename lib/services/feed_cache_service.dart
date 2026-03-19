import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Service to cache and retrieve feed responses for offline support and cold-start speed.
class FeedCacheService {
  static const String _cacheKey = 'unibuzz_feed_cache';
  static const String _cacheTimestampKey = 'unibuzz_feed_cache_timestamp';
  static const Duration _cacheTtl = Duration(minutes: 5);

  /// Gets the cached feed response if available and not stale.
  static Future<List<dynamic>?> getCachedFeed() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString(_cacheKey);
      if (cachedJson == null) {
        return null;
      }

      // Check if cache is stale
      if (!_isCacheValid(prefs)) {
        return null;
      }

      final decoded = jsonDecode(cachedJson);
      if (decoded is List<dynamic>) {
        return decoded;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Caches a feed response.
  static Future<void> cacheResponse(List<dynamic> videos) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = jsonEncode(videos);
      await prefs.setString(_cacheKey, json);
      await prefs.setInt(_cacheTimestampKey, DateTime.now().millisecondsSinceEpoch);
    } catch (_) {
      // Cache write failed silently
    }
  }

  /// Checks if the cached feed is still valid (not older than TTL).
  static bool _isCacheValid(SharedPreferences prefs) {
    final timestamp = prefs.getInt(_cacheTimestampKey);
    if (timestamp == null) {
      return false;
    }

    final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final age = DateTime.now().difference(cacheTime);
    return age < _cacheTtl;
  }

  /// Clears the cached feed.
  static Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cacheKey);
      await prefs.remove(_cacheTimestampKey);
    } catch (_) {
      // Cache clear failed silently
    }
  }

  /// Gets the age of the cached feed. Returns null if no cache exists.
  static Future<Duration?> getCacheAge() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = prefs.getInt(_cacheTimestampKey);
      if (timestamp == null) {
        return null;
      }

      final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      return DateTime.now().difference(cacheTime);
    } catch (_) {
      return null;
    }
  }
}
