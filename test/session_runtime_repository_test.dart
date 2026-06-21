import 'package:flutter_test/flutter_test.dart';
import 'package:mission_app/features/session_runtime/data/repositories/session_runtime_repository.dart';

void main() {
  group('SessionRuntimeRepository offline fallback queue', () {
    test('keeps only the latest offline speaking fallback entries', () {
      final entries = List<OfflineSpeakingFallbackEntry>.generate(
        105,
        (index) => OfflineSpeakingFallbackEntry(
          userId: 'user-1',
          sessionId: 'session-1',
          itemId: 'item-$index',
          expectedText: 'expected',
          transcript: 'transcript',
          mode: 'flash_sentence_test_speaking',
          audioPath: 'audio-$index.wav',
          engine: 'sherpa_onnx',
          durationMs: 1000,
          createdAtMs: index,
        ),
      );

      final trimmed =
          SessionRuntimeRepository.trimOfflineQueueForTesting(entries);

      expect(
        trimmed,
        hasLength(SessionRuntimeRepository.offlineQueueMaxEntriesForTesting),
      );
      expect(trimmed.first.itemId, 'item-5');
      expect(trimmed.last.itemId, 'item-104');
    });

    test('does not drop entries while the queue is under the limit', () {
      final entries = List<OfflineSpeakingFallbackEntry>.generate(
        3,
        (index) => OfflineSpeakingFallbackEntry(
          userId: 'user-1',
          sessionId: 'session-1',
          itemId: 'item-$index',
          expectedText: 'expected',
          transcript: 'transcript',
          mode: 'flash_sentence_test_speaking',
          audioPath: 'audio-$index.wav',
          engine: 'sherpa_onnx',
          durationMs: 1000,
          createdAtMs: index,
        ),
      );

      final trimmed =
          SessionRuntimeRepository.trimOfflineQueueForTesting(entries);

      expect(trimmed, same(entries));
      expect(trimmed.map((entry) => entry.itemId), <String>[
        'item-0',
        'item-1',
        'item-2',
      ]);
    });
  });
}
