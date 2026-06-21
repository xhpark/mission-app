int resolveTestContentIndex({
  required int displayIndex,
  required int itemCount,
  required String? levelName,
  required String seedKey,
  required String orderKey,
}) {
  if (itemCount <= 0) {
    return 0;
  }

  final boundedDisplayIndex = displayIndex.clamp(0, itemCount - 1).toInt();
  if (!shouldShuffleTestOrder(levelName)) {
    return boundedDisplayIndex;
  }

  final order = List<int>.generate(itemCount, (index) => index)
    ..sort((left, right) {
      final leftHash = _stableHash('$seedKey|$orderKey|$left');
      final rightHash = _stableHash('$seedKey|$orderKey|$right');
      final hashComparison = leftHash.compareTo(rightHash);
      if (hashComparison != 0) {
        return hashComparison;
      }
      return left.compareTo(right);
    });

  return order[boundedDisplayIndex];
}

bool shouldShuffleTestOrder(String? levelName) {
  return levelName == 'intermediate' || levelName == 'advanced';
}

int _stableHash(String input) {
  var hash = 0x811c9dc5;
  for (final codeUnit in input.codeUnits) {
    hash ^= codeUnit;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  hash ^= hash >> 16;
  hash = (hash * 0x7feb352d) & 0xffffffff;
  hash ^= hash >> 15;
  hash = (hash * 0x846ca68b) & 0xffffffff;
  hash ^= hash >> 16;
  return hash & 0x7fffffff;
}
