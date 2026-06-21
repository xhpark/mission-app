import 'package:flutter_test/flutter_test.dart';
import 'package:mission_app/features/session_runtime/domain/test_item_order.dart';

void main() {
  test('beginner keeps the original order', () {
    final order = List<int>.generate(
      8,
      (index) => resolveTestContentIndex(
        displayIndex: index,
        itemCount: 8,
        levelName: 'beginner',
        seedKey: 'session-a',
        orderKey: 'sentence-test',
      ),
    );

    expect(order, List<int>.generate(8, (index) => index));
  });

  test('intermediate uses a deterministic shuffled permutation', () {
    final first = List<int>.generate(
      10,
      (index) => resolveTestContentIndex(
        displayIndex: index,
        itemCount: 10,
        levelName: 'intermediate',
        seedKey: 'session-a',
        orderKey: 'sentence-test',
      ),
    );
    final second = List<int>.generate(
      10,
      (index) => resolveTestContentIndex(
        displayIndex: index,
        itemCount: 10,
        levelName: 'intermediate',
        seedKey: 'session-a',
        orderKey: 'sentence-test',
      ),
    );

    expect(first, second);
    expect(first.toSet(), Set<int>.from(List<int>.generate(10, (i) => i)));
    expect(first, isNot(List<int>.generate(10, (index) => index)));
  });

  test('advanced uses seed and order key to keep test families stable', () {
    final sentenceOrder = List<int>.generate(
      10,
      (index) => resolveTestContentIndex(
        displayIndex: index,
        itemCount: 10,
        levelName: 'advanced',
        seedKey: 'session-a',
        orderKey: 'sentence-test',
      ),
    );
    final flashSentenceOrder = List<int>.generate(
      10,
      (index) => resolveTestContentIndex(
        displayIndex: index,
        itemCount: 10,
        levelName: 'advanced',
        seedKey: 'session-a',
        orderKey: 'flash-sentence-test',
      ),
    );

    expect(sentenceOrder.toSet(), flashSentenceOrder.toSet());
    expect(sentenceOrder, isNot(flashSentenceOrder));
  });

  test('out of range and empty inputs are bounded safely', () {
    expect(
      resolveTestContentIndex(
        displayIndex: 99,
        itemCount: 3,
        levelName: 'beginner',
        seedKey: 'session-a',
        orderKey: 'word-test',
      ),
      2,
    );
    expect(
      resolveTestContentIndex(
        displayIndex: 0,
        itemCount: 0,
        levelName: 'advanced',
        seedKey: 'session-a',
        orderKey: 'word-test',
      ),
      0,
    );
  });
}
