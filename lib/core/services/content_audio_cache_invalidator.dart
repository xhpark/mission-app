import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/learning_content/data/thai_content_version.dart';

/// just_audio's on-disk asset cache (`just_audio_cache/`) is keyed only by
/// asset path, not by content. Updating a bundled audio file under the same
/// path (e.g. regenerating THS_D016.mp3 with new pronunciation) leaves the
/// stale cached copy in place after an app update, so the old audio keeps
/// playing forever. Clear that cache whenever the content source changes.
///
/// See docs_content_update_checklist_2026-06-22.md for the full content
/// pipeline this protects.
class ContentAudioCacheInvalidator {
  static const _prefsKey = 'thai_content_version_for_audio_cache';

  static Future<void> invalidateIfContentChanged() async {
    final prefs = await SharedPreferences.getInstance();
    final storedVersion = prefs.getString(_prefsKey);
    if (storedVersion == thaiContentVersion) {
      return;
    }

    await _deleteIfExists('just_audio_cache');
    await _deleteIfExists('just_audio_asset_cache');
    await prefs.setString(_prefsKey, thaiContentVersion);
  }

  static Future<void> _deleteIfExists(String dirName) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final dir = Directory(p.join(tempDir.path, dirName));
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    } catch (_) {
      // Best-effort: a failed cache clear should never block app startup.
    }
  }
}
