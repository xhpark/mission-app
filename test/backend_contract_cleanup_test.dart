import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('backend contract cleanup', () {
    test('deprecated sentence callable names are not exported anymore', () {
      final indexFile = File('functions/src/index.ts');
      expect(indexFile.existsSync(), isTrue);
      final source = indexFile.readAsStringSync();

      expect(source.contains('export const getSentenceLearningItem'), isFalse);
      expect(source.contains('export const completeSentenceStudy'), isFalse);
      expect(source.contains('interface GetSentenceLearningItemData'), isFalse);
      expect(source.contains('interface CompleteSentenceStudyData'), isFalse);
    });
  });
}

