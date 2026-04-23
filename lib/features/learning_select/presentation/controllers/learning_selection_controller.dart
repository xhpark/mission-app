import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum LearningCategory { daily, mission }

enum LearningLevel { beginner, intermediate, advanced }

enum LearningMode {
  sentenceLearning,
  sentenceTest,
  flashWordLearning,
  flashWordTest,
  flashSentenceLearning,
  flashSentenceTest,
}

const _selectionKeyCategory = 'learning_selection.category';
const _selectionKeyLevel = 'learning_selection.level';
const _selectionKeyMode = 'learning_selection.mode';

class LearningSelectionState {
  const LearningSelectionState({
    this.category,
    this.level,
    this.mode,
  });

  final LearningCategory? category;
  final LearningLevel? level;
  final LearningMode? mode;

  bool get canProceed => category != null && level != null && mode != null;

  LearningSelectionState copyWith({
    LearningCategory? category,
    LearningLevel? level,
    LearningMode? mode,
  }) {
    return LearningSelectionState(
      category: category ?? this.category,
      level: level ?? this.level,
      mode: mode ?? this.mode,
    );
  }
}

class LearningSelectionController extends Notifier<LearningSelectionState> {
  bool _hydrated = false;

  @override
  LearningSelectionState build() {
    if (!_hydrated) {
      _hydrated = true;
      unawaited(_hydrate());
    }

    return const LearningSelectionState();
  }

  void selectCategory(LearningCategory value) {
    state = state.copyWith(category: value);
    unawaited(_persist());
  }

  void selectLevel(LearningLevel value) {
    state = state.copyWith(level: value);
    unawaited(_persist());
  }

  void selectMode(LearningMode value) {
    state = state.copyWith(mode: value);
    unawaited(_persist());
  }

  Future<void> _hydrate() async {
    final prefs = await SharedPreferences.getInstance();
    final categoryRaw = prefs.getString(_selectionKeyCategory);
    final levelRaw = prefs.getString(_selectionKeyLevel);
    final modeRaw = prefs.getString(_selectionKeyMode);

    state = LearningSelectionState(
      category: _parseCategory(categoryRaw),
      level: _parseLevel(levelRaw),
      mode: _parseMode(modeRaw),
    );
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _selectionKeyCategory,
      state.category?.name ?? '',
    );
    await prefs.setString(
      _selectionKeyLevel,
      state.level?.name ?? '',
    );
    await prefs.setString(
      _selectionKeyMode,
      state.mode?.name ?? '',
    );
  }

  LearningCategory? _parseCategory(String? raw) {
    if (raw == null || raw.isEmpty) {
      return null;
    }

    for (final value in LearningCategory.values) {
      if (value.name == raw) {
        return value;
      }
    }

    return null;
  }

  LearningLevel? _parseLevel(String? raw) {
    if (raw == null || raw.isEmpty) {
      return null;
    }

    for (final value in LearningLevel.values) {
      if (value.name == raw) {
        return value;
      }
    }

    return null;
  }

  LearningMode? _parseMode(String? raw) {
    if (raw == null || raw.isEmpty) {
      return null;
    }

    for (final value in LearningMode.values) {
      if (value.name == raw) {
        return value;
      }
    }

    return null;
  }
}

final learningSelectionProvider =
    NotifierProvider<LearningSelectionController, LearningSelectionState>(
      LearningSelectionController.new,
    );
