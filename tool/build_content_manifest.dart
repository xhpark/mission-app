// Generates the server-side content manifest from the single source of truth
// (lib/features/learning_content/data/thai_learning_content.dart) so that Cloud
// Functions can grade and size sessions authoritatively without trusting the
// client.
//
// Run from the project root:
//   dart run tool/build_content_manifest.dart
//
// CI calls it with --check to fail when the committed manifest has drifted from
// the Dart content source.

import 'dart:convert';
import 'dart:io';

import 'package:mission_app/features/learning_content/data/thai_learning_content.dart';

const _sourceRelativePath =
    'lib/features/learning_content/data/thai_learning_content.dart';
const _outputRelativePath = 'functions/src/generated/thai_content_manifest.ts';
const _versionOutputRelativePath =
    'lib/features/learning_content/data/thai_content_version.dart';

const _categories = <String>['daily', 'mission'];
const _levels = <String>['beginner', 'intermediate', 'advanced'];

const _sentenceModes = <String>[
  'sentence_learning',
  'sentence_test',
  'flash_sentence_learning',
  'flash_sentence_test',
];
const _wordModes = <String>['flash_word_learning', 'flash_word_test'];

void main(List<String> args) {
  final checkOnly = args.contains('--check');

  final sourceFile = File(_sourceRelativePath);
  if (!sourceFile.existsSync()) {
    stderr.writeln('Content source not found: $_sourceRelativePath');
    stderr.writeln('Run this script from the project root.');
    exitCode = 2;
    return;
  }

  final sourceBytes = sourceFile.readAsBytesSync();
  final manifest = _buildManifest(sourceBytes);
  final json = const JsonEncoder.withIndent('  ').convert(manifest);
  final encoded = _renderTsModule(json);
  final outputFile = File(_outputRelativePath);

  final versionEncoded = _renderVersionDartFile(manifest['sourceHash'] as String);
  final versionOutputFile = File(_versionOutputRelativePath);

  if (checkOnly) {
    final current = outputFile.existsSync()
        ? outputFile.readAsStringSync().replaceAll('\r\n', '\n').trim()
        : '';
    final currentVersion = versionOutputFile.existsSync()
        ? versionOutputFile.readAsStringSync().replaceAll('\r\n', '\n').trim()
        : '';
    if (current != encoded.trim() || currentVersion != versionEncoded.trim()) {
      stderr.writeln(
        'Content manifest is out of date. Run: dart run tool/build_content_manifest.dart',
      );
      exitCode = 1;
      return;
    }
    stdout.writeln('Content manifest is up to date.');
    return;
  }

  outputFile.parent.createSync(recursive: true);
  outputFile.writeAsStringSync('$encoded\n');
  stdout.writeln('Wrote $_outputRelativePath');

  versionOutputFile.parent.createSync(recursive: true);
  versionOutputFile.writeAsStringSync('$versionEncoded\n');
  stdout.writeln('Wrote $_versionOutputRelativePath');
}

// The client (app) needs to know when bundled content/audio has changed so it
// can invalidate the just_audio asset cache (which keys only by asset path,
// not content — see docs_content_update_checklist_2026-06-22.md). Expose the
// same source hash used for server drift detection as a client-readable const.
String _renderVersionDartFile(String sourceHash) {
  final buffer = StringBuffer()
    ..writeln('// GENERATED FILE — do not edit by hand.')
    ..writeln('// Source of truth: $_sourceRelativePath')
    ..writeln('// Regenerate: dart run tool/build_content_manifest.dart')
    ..writeln('//')
    ..writeln('// Bump whenever thai_learning_content.dart changes; used to')
    ..writeln('// invalidate the on-device audio cache when content/audio is updated.')
    ..writeln("const thaiContentVersion = '$sourceHash';");
  return buffer.toString();
}

String _renderTsModule(String json) {
  final buffer = StringBuffer()
    ..writeln('// GENERATED FILE — do not edit by hand.')
    ..writeln('// Source of truth: $_sourceRelativePath')
    ..writeln('// Regenerate: dart run tool/build_content_manifest.dart')
    ..writeln('/* eslint-disable */')
    ..writeln('export const thaiContentManifest = $json as const;')
    ..writeln('export type ThaiContentManifest = typeof thaiContentManifest;');
  return buffer.toString();
}

Map<String, Object?> _buildManifest(List<int> sourceBytes) {
  final contentSets = <String, Object?>{};
  for (final category in _categories) {
    final sentences = sentencesByCategory(category);
    final words = wordsByCategory(category);

    final modeTotals = <String, int>{
      for (final mode in _sentenceModes) mode: sentences.length,
      for (final mode in _wordModes) mode: words.length,
    };

    final items = <String, Object?>{};
    for (final sentence in sentences) {
      items[sentence.id] = <String, Object?>{
        'type': 'sentence',
        'expectedText': sentence.thaiText,
      };
    }
    for (final word in words) {
      items[word.id] = <String, Object?>{
        'type': 'word',
        'expectedText': word.thaiWord,
      };
    }

    for (final level in _levels) {
      contentSets['$category-$level-default'] = <String, Object?>{
        'category': category,
        'level': level,
        'modeTotals': modeTotals,
        'items': items,
      };
    }
  }

  return <String, Object?>{
    'version': 1,
    'sourceHash': 'fnv1a32:${_fnv1a32Hex(sourceBytes)}',
    'sourcePath': _sourceRelativePath,
    'contentSets': contentSets,
  };
}

// Dependency-free deterministic digest used only as a drift detector (not a
// cryptographic integrity guarantee).
String _fnv1a32Hex(List<int> bytes) {
  const offsetBasis = 0x811c9dc5;
  const prime = 0x01000193;
  const mask = 0xFFFFFFFF;
  var hash = offsetBasis;
  for (final byte in bytes) {
    hash ^= byte & 0xff;
    hash = (hash * prime) & mask;
  }
  return hash.toRadixString(16).padLeft(8, '0');
}
