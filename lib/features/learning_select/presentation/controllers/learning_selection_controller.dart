import 'package:flutter_riverpod/flutter_riverpod.dart';

enum LearningCategory { daily, mission }

enum LearningLevel { beginner, intermediate, advanced }

enum LearningMode { sentenceLearning, sentenceTest, flashWordLearning }

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
  @override
  LearningSelectionState build() {
    return const LearningSelectionState();
  }

  void selectCategory(LearningCategory value) {
    state = state.copyWith(category: value);
  }

  void selectLevel(LearningLevel value) {
    state = state.copyWith(level: value);
  }

  void selectMode(LearningMode value) {
    state = state.copyWith(mode: value);
  }
}

final learningSelectionProvider =
    NotifierProvider<LearningSelectionController, LearningSelectionState>(
      LearningSelectionController.new,
    );
