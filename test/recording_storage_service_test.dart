import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mission_app/core/services/recording_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test(
    'stores and reads recordings independently by lesson and sentence',
    () async {
      final storage = RecordingStorageService();
      final sentenceA = Uint8List.fromList(<int>[1, 2, 3]);
      final sentenceB = Uint8List.fromList(<int>[7, 8, 9]);

      final pathA = await storage.saveRecording(
        lessonId: 'lesson01',
        sentenceId: 'sentence03',
        bytes: sentenceA,
      );
      final pathB = await storage.saveRecording(
        lessonId: 'lesson01',
        sentenceId: 'sentence04',
        bytes: sentenceB,
      );

      expect(pathA, 'recording_lesson01_sentence03.m4a');
      expect(pathB, 'recording_lesson01_sentence04.m4a');
      expect(pathA, isNot(pathB));
      expect(
        await storage.readRecording(
          lessonId: 'lesson01',
          sentenceId: 'sentence03',
        ),
        sentenceA,
      );
      expect(
        await storage.readRecording(
          lessonId: 'lesson01',
          sentenceId: 'sentence04',
        ),
        sentenceB,
      );
    },
  );

  test(
    'does not return a previous sentence recording for a missing sentence',
    () async {
      final storage = RecordingStorageService();

      await storage.saveRecording(
        lessonId: 'lesson01',
        sentenceId: 'sentence03',
        bytes: Uint8List.fromList(<int>[1, 2, 3]),
      );

      expect(
        await storage.findRecordingPath(
          lessonId: 'lesson01',
          sentenceId: 'sentence04',
        ),
        isNull,
      );
      expect(
        await storage.readRecording(
          lessonId: 'lesson01',
          sentenceId: 'sentence04',
        ),
        isNull,
      );
    },
  );
}
