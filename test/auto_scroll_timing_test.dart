import 'package:flutter_test/flutter_test.dart';
import 'package:mission_app/features/sentence_learning/presentation/auto_scroll_timing.dart';

void main() {
  group('computeAutoScrollDelay', () {
    test('clamps short content to the 3s minimum', () {
      // base(2000) + 0*60 = 2000 < min(3000) -> clamped to 3000.
      expect(
        computeAutoScrollDelay(contentCharCount: 0),
        const Duration(milliseconds: 3000),
      );
      // base(2000) + 10*60 = 2600 < min(3000) -> clamped to 3000.
      expect(
        computeAutoScrollDelay(contentCharCount: 10),
        const Duration(milliseconds: 3000),
      );
    });

    test('clamps very long content to the 12s maximum', () {
      // base(2000) + 1000*60 = 62000 > max(12000) -> clamped to 12000.
      expect(
        computeAutoScrollDelay(contentCharCount: 1000),
        const Duration(milliseconds: 12000),
      );
    });

    test('scales linearly in the middle range', () {
      // base(2000) + 50*60 = 5000.
      expect(
        computeAutoScrollDelay(contentCharCount: 50),
        const Duration(milliseconds: 5000),
      );
      // base(2000) + 100*60 = 8000.
      expect(
        computeAutoScrollDelay(contentCharCount: 100),
        const Duration(milliseconds: 8000),
      );
    });

    test('is monotonically non-decreasing as content grows', () {
      Duration? previous;
      for (var count = 0; count <= 400; count += 20) {
        final delay = computeAutoScrollDelay(contentCharCount: count);
        if (previous != null) {
          expect(
            delay >= previous,
            isTrue,
            reason: 'delay must not shrink as content grows (count=$count)',
          );
        }
        previous = delay;
      }
    });

    test('treats negative counts as zero (defensive)', () {
      expect(
        computeAutoScrollDelay(contentCharCount: -100),
        const Duration(milliseconds: 3000),
      );
    });
  });
}
