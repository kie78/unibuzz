import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class PendingUploadTrackerService {
  static final FlutterSecureStorage _storage = FlutterSecureStorage();
  static const String _pendingUploadIdsKey = 'pending_upload_video_ids';

  static Future<List<String>> getPendingUploadIds() async {
    final raw = await _storage.read(key: _pendingUploadIdsKey);
    if (raw == null || raw.trim().isEmpty) {
      return <String>[];
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return <String>[];
      }

      final ids = <String>{};
      for (final value in decoded) {
        final id = value?.toString().trim() ?? '';
        if (id.isNotEmpty) {
          ids.add(id);
        }
      }
      return ids.toList();
    } catch (_) {
      return <String>[];
    }
  }

  static Future<void> addPendingUpload(String videoId) async {
    final normalizedId = videoId.trim();
    if (normalizedId.isEmpty) {
      return;
    }

    final current = await getPendingUploadIds();
    final next = <String>{...current, normalizedId}.toList();
    await _storage.write(key: _pendingUploadIdsKey, value: jsonEncode(next));
  }

  static Future<void> removePendingUpload(String videoId) async {
    final normalizedId = videoId.trim();
    if (normalizedId.isEmpty) {
      return;
    }

    final current = await getPendingUploadIds();
    final next = current.where((id) => id != normalizedId).toList();

    if (next.isEmpty) {
      await _storage.delete(key: _pendingUploadIdsKey);
      return;
    }

    await _storage.write(key: _pendingUploadIdsKey, value: jsonEncode(next));
  }

  static Future<void> removePendingUploads(Iterable<String> videoIds) async {
    final idsToRemove = videoIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet();

    if (idsToRemove.isEmpty) {
      return;
    }

    final current = await getPendingUploadIds();
    final next = current.where((id) => !idsToRemove.contains(id)).toList();

    if (next.isEmpty) {
      await _storage.delete(key: _pendingUploadIdsKey);
      return;
    }

    await _storage.write(key: _pendingUploadIdsKey, value: jsonEncode(next));
  }

  static Future<void> clearPendingUploads() async {
    await _storage.delete(key: _pendingUploadIdsKey);
  }
}
