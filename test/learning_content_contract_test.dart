import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mission_app/features/learning_content/data/thai_learning_content.dart';

void main() {
  group('learning content contract', () {
    test('sentence/word counts match source-of-truth baseline', () {
      final dailySentences = sentencesByCategory('daily');
      final missionSentences = sentencesByCategory('mission');
      final dailyWords = wordsByCategory('daily');
      final missionWords = wordsByCategory('mission');

      expect(dailySentences.length, 15);
      expect(missionSentences.length, 10);
      expect(dailySentences.length + missionSentences.length, 25);

      expect(dailyWords.length, 30);
      expect(missionWords.length, 16);
      expect(dailyWords.length + missionWords.length, 46);
    });

    test('sentence IDs are unique and order is contiguous by category', () {
      final all = <ThaiSentenceContent>[
        ...sentencesByCategory('daily'),
        ...sentencesByCategory('mission'),
      ];
      final idSet = all.map((e) => e.id).toSet();
      expect(idSet.length, all.length);

      for (final category in const ['daily', 'mission']) {
        final list = sentencesByCategory(category)..sort((a, b) => a.orderNo.compareTo(b.orderNo));
        for (var i = 0; i < list.length; i++) {
          expect(list[i].orderNo, i + 1, reason: 'orderNo must be contiguous for $category');
        }
      }
    });

    test('word IDs are unique and order is contiguous by category', () {
      final all = <ThaiWordContent>[
        ...wordsByCategory('daily'),
        ...wordsByCategory('mission'),
      ];
      final idSet = all.map((e) => e.id).toSet();
      expect(idSet.length, all.length);

      for (final category in const ['daily', 'mission']) {
        final list = wordsByCategory(category)..sort((a, b) => a.orderNo.compareTo(b.orderNo));
        for (var i = 0; i < list.length; i++) {
          expect(list[i].orderNo, i + 1, reason: 'orderNo must be contiguous for $category');
        }
      }
    });

    test('all sentence audio files are present and mapped by ID', () {
      final all = <ThaiSentenceContent>[
        ...sentencesByCategory('daily'),
        ...sentencesByCategory('mission'),
      ];
      for (final sentence in all) {
        final expectedPath = 'assets/audio/sentence/${sentence.id}.mp3';
        expect(sentence.audioPath, expectedPath);
        expect(File(expectedPath).existsSync(), isTrue, reason: 'Missing audio: $expectedPath');
      }
    });

    test('all word audio files are present and mapped by ID', () {
      final all = <ThaiWordContent>[
        ...wordsByCategory('daily'),
        ...wordsByCategory('mission'),
      ];
      for (final word in all) {
        final expectedPath = 'assets/audio/word/${word.id}.mp3';
        expect(word.audioPath, expectedPath);
        expect(File(expectedPath).existsSync(), isTrue, reason: 'Missing audio: $expectedPath');
      }
    });

    test('word -> sentence links are valid and every sentence has at least one linked word', () {
      final sentenceById = <String, ThaiSentenceContent>{
        for (final s in [...sentencesByCategory('daily'), ...sentencesByCategory('mission')]) s.id: s,
      };
      final linkedCountBySentence = <String, int>{for (final id in sentenceById.keys) id: 0};

      for (final word in [...wordsByCategory('daily'), ...wordsByCategory('mission')]) {
        final links = word.linkedSentenceIds
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty);
        for (final sentenceId in links) {
          final sentence = sentenceById[sentenceId];
          expect(sentence, isNotNull, reason: 'Invalid linked sentence ID: $sentenceId');
          expect(
            sentence!.category,
            word.category,
            reason: 'Cross-category link is not allowed: ${word.id} -> $sentenceId',
          );
          linkedCountBySentence[sentenceId] = (linkedCountBySentence[sentenceId] ?? 0) + 1;
        }
      }

      for (final sentence in sentenceById.values) {
        expect(
          (linkedCountBySentence[sentence.id] ?? 0) > 0,
          isTrue,
          reason: 'Sentence must have at least one linked word: ${sentence.id}',
        );
      }
    });

    test('sentence test options are unique per question and include the correct answer at index 0', () {
      for (final category in const ['daily', 'mission']) {
        final sentences = sentencesByCategory(category);
        for (var i = 0; i < sentences.length; i++) {
          final options = sentenceThaiOptions(category: category, correctIndex: i);
          expect(options.length, greaterThanOrEqualTo(2));
          expect(options.length, lessThanOrEqualTo(4));
          expect(options.first, sentences[i].thaiText);

          final normalized = options
              .map((e) => e.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' '))
              .toList();
          expect(normalized.toSet().length, normalized.length, reason: 'Duplicate options at $category/$i');
        }
      }
    });

    test('word test options are unique per question and include the correct answer at index 0', () {
      for (final category in const ['daily', 'mission']) {
        final words = wordsByCategory(category);
        for (var i = 0; i < words.length; i++) {
          final options = wordEnglishOptions(category: category, correctIndex: i);
          expect(options.length, greaterThanOrEqualTo(2));
          expect(options.length, lessThanOrEqualTo(4));
          expect(options.first, words[i].englishMeaning.trim().isNotEmpty ? words[i].englishMeaning : words[i].koreanMeaning);

          final normalized = options
              .map((e) => e.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' '))
              .toList();
          expect(normalized.toSet().length, normalized.length, reason: 'Duplicate options at $category/$i');
        }
      }
    });
  });
}

