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

      expect(dailySentences.length, 18);
      expect(missionSentences.length, 10);
      expect(dailySentences.length + missionSentences.length, 28);

      expect(dailyWords.length, 35);
      expect(missionWords.length, 19);
      expect(dailyWords.length + missionWords.length, 54);
    });

    test('sentence IDs are unique and order is contiguous by category', () {
      final all = <ThaiSentenceContent>[
        ...sentencesByCategory('daily'),
        ...sentencesByCategory('mission'),
      ];
      final idSet = all.map((e) => e.id).toSet();
      expect(idSet.length, all.length);

      for (final category in const ['daily', 'mission']) {
        final list = sentencesByCategory(category)
          ..sort((a, b) => a.orderNo.compareTo(b.orderNo));
        for (var i = 0; i < list.length; i++) {
          expect(
            list[i].orderNo,
            i + 1,
            reason: 'orderNo must be contiguous for $category',
          );
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
        final list = wordsByCategory(category)
          ..sort((a, b) => a.orderNo.compareTo(b.orderNo));
        for (var i = 0; i < list.length; i++) {
          expect(
            list[i].orderNo,
            i + 1,
            reason: 'orderNo must be contiguous for $category',
          );
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
        expect(
          File(expectedPath).existsSync(),
          isTrue,
          reason: 'Missing audio: $expectedPath',
        );
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
        expect(
          File(expectedPath).existsSync(),
          isTrue,
          reason: 'Missing audio: $expectedPath',
        );
      }
    });

    test(
      'word -> sentence links are valid and every sentence has at least one linked word',
      () {
        final sentenceById = <String, ThaiSentenceContent>{
          for (final s in [
            ...sentencesByCategory('daily'),
            ...sentencesByCategory('mission'),
          ])
            s.id: s,
        };
        final linkedCountBySentence = <String, int>{
          for (final id in sentenceById.keys) id: 0,
        };

        for (final word in [
          ...wordsByCategory('daily'),
          ...wordsByCategory('mission'),
        ]) {
          final links = word.linkedSentenceIds
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty);
          for (final sentenceId in links) {
            final sentence = sentenceById[sentenceId];
            expect(
              sentence,
              isNotNull,
              reason: 'Invalid linked sentence ID: $sentenceId',
            );
            expect(
              sentence!.category,
              word.category,
              reason:
                  'Cross-category link is not allowed: ${word.id} -> $sentenceId',
            );
            linkedCountBySentence[sentenceId] =
                (linkedCountBySentence[sentenceId] ?? 0) + 1;
          }
        }

        for (final sentence in sentenceById.values) {
          expect(
            (linkedCountBySentence[sentence.id] ?? 0) > 0,
            isTrue,
            reason:
                'Sentence must have at least one linked word: ${sentence.id}',
          );
        }
      },
    );

    test('THS_D003 keeps both core words: ขอบคุณ and มาก', () {
      final dailyWords = wordsByCategory('daily');
      final linked = dailyWords
          .where(
            (word) => word.linkedSentenceIds
                .split(',')
                .map((e) => e.trim())
                .contains('THS_D003'),
          )
          .toList();

      expect(
        linked.any((word) => word.thaiWord == 'ขอบคุณ'),
        isTrue,
        reason: 'THS_D003 must include ขอบคุณ',
      );
      expect(
        linked.any((word) => word.thaiWord == 'มาก'),
        isTrue,
        reason: 'THS_D003 must include มาก',
      );

      final sentence = sentencesByCategory(
        'daily',
      ).firstWhere((s) => s.id == 'THS_D003');
      final formattedHint = formatThaiTokensForLearners(sentence.hint);
      expect(formattedHint.contains('콥쿤 (ขอบคุณ)'), isTrue);
      expect(formattedHint.contains('막 (มาก)'), isTrue);
    });

    test('THS_D004/THS_D008 keep core words: ไม่, เป็น, ไร', () {
      final dailyWords = wordsByCategory('daily');

      List<ThaiWordContent> linkedWordsFor(String sentenceId) => dailyWords
          .where(
            (word) => word.linkedSentenceIds
                .split(',')
                .map((e) => e.trim())
                .contains(sentenceId),
          )
          .toList();

      for (final sentenceId in const ['THS_D004', 'THS_D008']) {
        final linked = linkedWordsFor(sentenceId);
        expect(
          linked.any((word) => word.thaiWord == 'ไม่'),
          isTrue,
          reason: '$sentenceId must include ไม่',
        );
        expect(
          linked.any((word) => word.thaiWord == 'เป็น'),
          isTrue,
          reason: '$sentenceId must include เป็น',
        );
        expect(
          linked.any((word) => word.thaiWord == 'ไร'),
          isTrue,
          reason: '$sentenceId must include ไร',
        );
      }
    });

    test('single Thai tokens keep their full learner pronunciation when formatted', () {
      final singleThaiToken = RegExp(r'^[\u0E00-\u0E7F]+$');

      for (final sentence in [
        ...sentencesByCategory('daily'),
        ...sentencesByCategory('mission'),
      ]) {
        if (!singleThaiToken.hasMatch(sentence.thaiText)) {
          continue;
        }

        final hangul = sentence.hangulPronunciation.trim();
        if (hangul.split(RegExp(r'\s+')).length <= 1) {
          continue;
        }

        expect(
          formatThaiWithHangul(
            sentence.thaiText,
            fallbackHangul: sentence.hangulPronunciation,
          ),
          '$hangul (${sentence.thaiText})',
          reason:
              'Single Thai sentence token must keep full Hangul pronunciation: ${sentence.id}',
        );
        expect(
          formatThaiTokensForLearners('${sentence.thaiText}는 확인용입니다.'),
          '$hangul (${sentence.thaiText})는 확인용입니다.',
          reason:
              'Hint formatter must not trim full Hangul pronunciation: ${sentence.id}',
        );
      }

      for (final word in [
        ...wordsByCategory('daily'),
        ...wordsByCategory('mission'),
      ]) {
        if (!singleThaiToken.hasMatch(word.thaiWord)) {
          continue;
        }

        final hangul = word.hangulPronunciation.trim();
        if (hangul.split(RegExp(r'\s+')).length <= 1) {
          continue;
        }

        expect(
          formatThaiWithHangul(
            word.thaiWord,
            fallbackHangul: word.hangulPronunciation,
          ),
          '$hangul (${word.thaiWord})',
          reason:
              'Single Thai word token must keep full Hangul pronunciation: ${word.id}',
        );
        expect(
          formatThaiTokensForLearners('${word.thaiWord}는 확인용입니다.'),
          '$hangul (${word.thaiWord})는 확인용입니다.',
          reason:
              'Hint formatter must not trim full Hangul pronunciation: ${word.id}',
        );
      }
    });

    test('THS_D010 keeps core words: พบ, กัน, ใหม่', () {
      final dailyWords = wordsByCategory('daily');
      final linked = dailyWords
          .where(
            (word) => word.linkedSentenceIds
                .split(',')
                .map((e) => e.trim())
                .contains('THS_D010'),
          )
          .toList();

      expect(
        linked.any((word) => word.thaiWord == 'พบ'),
        isTrue,
        reason: 'THS_D010 must include พบ',
      );
      expect(
        linked.any((word) => word.thaiWord == 'กัน'),
        isTrue,
        reason: 'THS_D010 must include กัน',
      );
      expect(
        linked.any((word) => word.thaiWord == 'ใหม่'),
        isTrue,
        reason: 'THS_D010 must include ใหม่',
      );
    });

    test(
      'sentence test options are unique and include the correct answer exactly once',
      () {
        for (final category in const ['daily', 'mission']) {
          final sentences = sentencesByCategory(category);
          final correctIndexes = <int>[];
          for (var i = 0; i < sentences.length; i++) {
            final choice = sentenceThaiOptions(
              category: category,
              correctIndex: i,
              seedKey: 'test-seed',
            );
            final options = choice.options;
            expect(options.length, greaterThanOrEqualTo(2));
            expect(options.length, lessThanOrEqualTo(4));
            expect(
              options.where((value) => value == sentences[i].thaiText).length,
              1,
            );
            expect(options[choice.correctIndex], sentences[i].thaiText);
            correctIndexes.add(choice.correctIndex);

            final normalized = options
                .map(
                  (e) => e.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' '),
                )
                .toList();
            expect(
              normalized.toSet().length,
              normalized.length,
              reason: 'Duplicate options at $category/$i',
            );
          }
          if (correctIndexes.isNotEmpty) {
            expect(correctIndexes.toSet().length, greaterThan(1));
            var streak = 1;
            for (var i = 1; i < correctIndexes.length; i++) {
              if (correctIndexes[i] == correctIndexes[i - 1]) {
                streak += 1;
              } else {
                streak = 1;
              }
              expect(
                streak <= 3,
                isTrue,
                reason: 'Correct index streak too long at $category/$i',
              );
            }
          }
        }
      },
    );

    test('sentence choice options carry stable IDs and audio paths', () {
      for (final category in const ['daily', 'mission']) {
        final sentences = sentencesByCategory(category);
        for (var i = 0; i < sentences.length; i++) {
          final choice = sentenceThaiOptions(
            category: category,
            correctIndex: i,
            seedKey: 'audio-contract',
          );

          expect(choice.optionIds, hasLength(choice.options.length));
          expect(choice.optionAudioPaths, hasLength(choice.options.length));
          expect(choice.optionIds[choice.correctIndex], sentences[i].id);
          expect(
            choice.optionAudioPaths[choice.correctIndex],
            sentences[i].audioPath,
          );

          for (
            var optionIndex = 0;
            optionIndex < choice.options.length;
            optionIndex++
          ) {
            final optionId = choice.optionIds[optionIndex];
            final audioPath = choice.optionAudioPaths[optionIndex];
            expect(
              optionId,
              isNotEmpty,
              reason: 'Missing option id at $category/$i/$optionIndex',
            );
            expect(
              audioPath,
              isNotEmpty,
              reason: 'Missing option audio path at $category/$i/$optionIndex',
            );
            expect(
              File(audioPath).existsSync(),
              isTrue,
              reason: 'Missing option audio asset: $audioPath',
            );
          }
        }
      }
    });

    test(
      'word test options are unique and include the correct answer exactly once',
      () {
        for (final category in const ['daily', 'mission']) {
          final words = wordsByCategory(category);
          final correctIndexes = <int>[];
          for (var i = 0; i < words.length; i++) {
            final choice = wordThaiOptions(
              category: category,
              correctIndex: i,
              seedKey: 'test-seed',
            );
            final options = choice.options;
            expect(options.length, greaterThanOrEqualTo(2));
            expect(options.length, lessThanOrEqualTo(4));
            expect(
              options.where((value) => value == words[i].thaiWord).length,
              1,
            );
            expect(options[choice.correctIndex], words[i].thaiWord);
            correctIndexes.add(choice.correctIndex);

            final normalized = options
                .map(
                  (e) => e.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' '),
                )
                .toList();
            expect(
              normalized.toSet().length,
              normalized.length,
              reason: 'Duplicate options at $category/$i',
            );
          }
          if (correctIndexes.isNotEmpty) {
            expect(correctIndexes.toSet().length, greaterThan(1));
            var streak = 1;
            for (var i = 1; i < correctIndexes.length; i++) {
              if (correctIndexes[i] == correctIndexes[i - 1]) {
                streak += 1;
              } else {
                streak = 1;
              }
              expect(
                streak <= 3,
                isTrue,
                reason: 'Correct index streak too long at $category/$i',
              );
            }
          }
        }
      },
    );

    test('word choice options carry stable IDs and audio paths', () {
      // Locks the server grading contract: the correct option's item id equals
      // the question's item id, so server scoring of selectedItemId == itemId is
      // correct.
      for (final category in const ['daily', 'mission']) {
        final words = wordsByCategory(category);
        for (var i = 0; i < words.length; i++) {
          final choice = wordThaiOptions(
            category: category,
            correctIndex: i,
            seedKey: 'word-id-contract',
          );

          expect(choice.optionIds, hasLength(choice.options.length));
          expect(choice.optionAudioPaths, hasLength(choice.options.length));
          expect(choice.optionIds[choice.correctIndex], words[i].id);

          for (
            var optionIndex = 0;
            optionIndex < choice.options.length;
            optionIndex++
          ) {
            expect(
              choice.optionIds[optionIndex],
              isNotEmpty,
              reason: 'Missing option id at $category/$i/$optionIndex',
            );
          }
          expect(
            choice.optionIds.toSet().length,
            choice.optionIds.length,
            reason: 'Duplicate option ids at $category/$i',
          );
        }
      }
    });

    test(
      'word choice labels use pronunciation policy instead of meaning text',
      () {
        final maak = wordsByCategory(
          'daily',
        ).firstWhere((word) => word.id == 'THW_D003');
        final khrap = wordsByCategory(
          'daily',
        ).firstWhere((word) => word.id == 'THW_D001');

        expect(
          formatThaiSoundChoiceLabel(
            thaiText: maak.thaiWord,
            fallbackHangul: maak.hangulPronunciation,
            fallbackPhonetic: maak.phonetic,
          ),
          '막 (mâak)',
        );

        expect(
          formatThaiSoundChoiceLabel(
            thaiText: khrap.thaiWord,
            fallbackHangul: khrap.hangulPronunciation,
            fallbackPhonetic: khrap.phonetic,
          ),
          '크랍 (khráp)',
        );
      },
    );
  });
}
