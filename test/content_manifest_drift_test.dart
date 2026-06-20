import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mission_app/features/learning_content/data/thai_learning_content.dart';

/// Guards against drift between the Dart content source of truth and the
/// generated server manifest (functions/src/generated/thai_content_manifest.ts).
/// If this fails, regenerate with: dart run tool/build_content_manifest.dart
void main() {
  const manifestPath = 'functions/src/generated/thai_content_manifest.ts';
  const sentenceModes = <String>[
    'sentence_learning',
    'sentence_test',
    'flash_sentence_learning',
    'flash_sentence_test',
  ];
  const wordModes = <String>['flash_word_learning', 'flash_word_test'];

  Map<String, dynamic> loadManifest() {
    final raw = File(manifestPath).readAsStringSync();
    const startMarker = 'export const thaiContentManifest = ';
    const endMarker = ' as const;';
    final start = raw.indexOf(startMarker);
    expect(start, isNonNegative, reason: 'manifest export not found');
    final jsonStart = start + startMarker.length;
    final jsonEnd = raw.indexOf(endMarker, jsonStart);
    expect(jsonEnd, greaterThan(jsonStart), reason: 'manifest end not found');
    final jsonText = raw.substring(jsonStart, jsonEnd);
    return Map<String, dynamic>.from(jsonDecode(jsonText) as Map);
  }

  test('generated manifest matches Dart content source', () {
    final manifest = loadManifest();
    final contentSets = Map<String, dynamic>.from(
      manifest['contentSets'] as Map,
    );

    for (final category in const ['daily', 'mission']) {
      final sentences = sentencesByCategory(category);
      final words = wordsByCategory(category);

      for (final level in const ['beginner', 'intermediate', 'advanced']) {
        final contentSetId = '$category-$level-default';
        final set = contentSets[contentSetId];
        expect(set, isNotNull, reason: 'missing content set $contentSetId');
        final setMap = Map<String, dynamic>.from(set as Map);

        final modeTotals = Map<String, dynamic>.from(
          setMap['modeTotals'] as Map,
        );
        for (final mode in sentenceModes) {
          expect(modeTotals[mode], sentences.length, reason: '$mode total');
        }
        for (final mode in wordModes) {
          expect(modeTotals[mode], words.length, reason: '$mode total');
        }

        final items = Map<String, dynamic>.from(setMap['items'] as Map);
        expect(items.length, sentences.length + words.length);
        for (final sentence in sentences) {
          final item = Map<String, dynamic>.from(items[sentence.id] as Map);
          expect(item['type'], 'sentence');
          expect(item['expectedText'], sentence.thaiText);
        }
        for (final word in words) {
          final item = Map<String, dynamic>.from(items[word.id] as Map);
          expect(item['type'], 'word');
          expect(item['expectedText'], word.thaiWord);
        }
      }
    }
  });
}
