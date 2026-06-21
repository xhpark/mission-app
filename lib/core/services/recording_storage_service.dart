import 'dart:convert';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';

class RecordingStorageService {
  static const _storagePrefix = 'sentence_recording.bytes.';

  Future<String> saveRecording({
    required String lessonId,
    required String sentenceId,
    required Uint8List bytes,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final fileName = recordingFileName(
      lessonId: lessonId,
      sentenceId: sentenceId,
    );
    await prefs.setString(_storageKey(fileName), base64Encode(bytes));
    return fileName;
  }

  Future<String?> findRecordingPath({
    required String lessonId,
    required String sentenceId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final fileName = recordingFileName(
      lessonId: lessonId,
      sentenceId: sentenceId,
    );
    return prefs.containsKey(_storageKey(fileName)) ? fileName : null;
  }

  Future<Uint8List?> readRecording({
    required String lessonId,
    required String sentenceId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final fileName = recordingFileName(
      lessonId: lessonId,
      sentenceId: sentenceId,
    );
    final encoded = prefs.getString(_storageKey(fileName));
    if (encoded == null || encoded.isEmpty) {
      return null;
    }
    return base64Decode(encoded);
  }

  static String recordingFileName({
    required String lessonId,
    required String sentenceId,
  }) {
    return 'recording_${_safeSegment(lessonId)}_${_safeSegment(sentenceId)}.m4a';
  }

  static String _storageKey(String fileName) => '$_storagePrefix$fileName';

  static String _safeSegment(String value) {
    final sanitized = value.replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_');
    return sanitized.isEmpty ? 'unknown' : sanitized;
  }
}
