import 'package:flutter_riverpod/flutter_riverpod.dart';

enum StudyFlowTrack {
  sentenceLearning,
  sentenceTestChoice,
  sentenceTestSpeaking,
  flashWordLearning,
  flashWordTest,
  flashSentenceLearning,
  flashSentenceTestChoice,
  flashSentenceTestSpeaking,
}

class StudyFlowState {
  const StudyFlowState({
    required this.sessionId,
    required this.totalItems,
    required this.completedItems,
    required this.correctAnswers,
    required this.attemptedAnswers,
    required this.trackIndices,
  });

  final String sessionId;
  final int totalItems;
  final int completedItems;
  final int correctAnswers;
  final int attemptedAnswers;
  final Map<StudyFlowTrack, int> trackIndices;

  int indexOf(StudyFlowTrack track) => trackIndices[track] ?? 0;

  StudyFlowState copyWith({
    String? sessionId,
    int? totalItems,
    int? completedItems,
    int? correctAnswers,
    int? attemptedAnswers,
    Map<StudyFlowTrack, int>? trackIndices,
  }) {
    return StudyFlowState(
      sessionId: sessionId ?? this.sessionId,
      totalItems: totalItems ?? this.totalItems,
      completedItems: completedItems ?? this.completedItems,
      correctAnswers: correctAnswers ?? this.correctAnswers,
      attemptedAnswers: attemptedAnswers ?? this.attemptedAnswers,
      trackIndices: trackIndices ?? this.trackIndices,
    );
  }

  static const empty = StudyFlowState(
    sessionId: '',
    totalItems: 0,
    completedItems: 0,
    correctAnswers: 0,
    attemptedAnswers: 0,
    trackIndices: <StudyFlowTrack, int>{},
  );
}

class StudyFlowController extends Notifier<StudyFlowState> {
  @override
  StudyFlowState build() => StudyFlowState.empty;

  void startSession({
    required String sessionId,
    required int totalItems,
  }) {
    state = StudyFlowState(
      sessionId: sessionId,
      totalItems: totalItems,
      completedItems: 0,
      correctAnswers: 0,
      attemptedAnswers: 0,
      trackIndices: const <StudyFlowTrack, int>{},
    );
  }

  void clear() {
    state = StudyFlowState.empty;
  }

  int indexOf(StudyFlowTrack track) => state.indexOf(track);

  bool advanceTrack({
    required StudyFlowTrack track,
    required int totalCount,
    bool isCorrectAttempt = false,
    bool countAsAttempt = false,
  }) {
    if (totalCount <= 0) {
      return false;
    }
    final current = state.indexOf(track);
    final next = current + 1;
    final hasNext = next < totalCount;

    final updatedIndices = Map<StudyFlowTrack, int>.from(state.trackIndices)
      ..[track] = hasNext ? next : current;

    state = state.copyWith(
      trackIndices: updatedIndices,
      completedItems: (state.completedItems + 1).clamp(0, state.totalItems),
      attemptedAnswers: countAsAttempt
          ? state.attemptedAnswers + 1
          : state.attemptedAnswers,
      correctAnswers:
          isCorrectAttempt ? state.correctAnswers + 1 : state.correctAnswers,
    );

    return hasNext;
  }
}

final studyFlowControllerProvider =
    NotifierProvider<StudyFlowController, StudyFlowState>(
  StudyFlowController.new,
);
