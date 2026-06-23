import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum StudyFlowTrack {
  sentenceLearning,
  sentenceTestChoice,
  sentenceTestSpeaking,
  flashWordLearning,
  flashWordTest,
  flashWordTestSpeaking,
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
    required this.speakingSimilarityByItemId,
    required this.completedTracks,
  });

  final String sessionId;
  final int totalItems;
  final int completedItems;
  final int correctAnswers;
  final int attemptedAnswers;
  final Map<StudyFlowTrack, int> trackIndices;
  final Map<String, int> speakingSimilarityByItemId;
  final Set<StudyFlowTrack> completedTracks;

  int indexOf(StudyFlowTrack track) => trackIndices[track] ?? 0;

  bool isTrackCompleted(StudyFlowTrack track) =>
      completedTracks.contains(track);

  int? get averageSimilarityScore {
    if (speakingSimilarityByItemId.isEmpty) {
      return null;
    }
    final total = speakingSimilarityByItemId.values.fold<int>(
      0,
      (sum, value) => sum + value,
    );
    return (total / speakingSimilarityByItemId.length).round();
  }

  StudyFlowState copyWith({
    String? sessionId,
    int? totalItems,
    int? completedItems,
    int? correctAnswers,
    int? attemptedAnswers,
    Map<StudyFlowTrack, int>? trackIndices,
    Map<String, int>? speakingSimilarityByItemId,
    Set<StudyFlowTrack>? completedTracks,
  }) {
    return StudyFlowState(
      sessionId: sessionId ?? this.sessionId,
      totalItems: totalItems ?? this.totalItems,
      completedItems: completedItems ?? this.completedItems,
      correctAnswers: correctAnswers ?? this.correctAnswers,
      attemptedAnswers: attemptedAnswers ?? this.attemptedAnswers,
      trackIndices: trackIndices ?? this.trackIndices,
      speakingSimilarityByItemId:
          speakingSimilarityByItemId ?? this.speakingSimilarityByItemId,
      completedTracks: completedTracks ?? this.completedTracks,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'sessionId': sessionId,
      'totalItems': totalItems,
      'completedItems': completedItems,
      'correctAnswers': correctAnswers,
      'attemptedAnswers': attemptedAnswers,
      'trackIndices': trackIndices.map(
        (track, index) => MapEntry(track.name, index),
      ),
      'speakingSimilarityByItemId': speakingSimilarityByItemId,
      'completedTracks': completedTracks.map((track) => track.name).toList(),
    };
  }

  static StudyFlowState fromJson(Map<String, Object?> json) {
    final rawTrackIndices = json['trackIndices'];
    final trackIndices = <StudyFlowTrack, int>{};
    if (rawTrackIndices is Map) {
      for (final entry in rawTrackIndices.entries) {
        final track = StudyFlowTrack.values.cast<StudyFlowTrack?>().firstWhere(
          (value) => value?.name == entry.key,
          orElse: () => null,
        );
        final value = entry.value;
        if (track != null && value is num) {
          trackIndices[track] = value.toInt();
        }
      }
    }

    final rawSimilarity = json['speakingSimilarityByItemId'];
    final speakingSimilarityByItemId = <String, int>{};
    if (rawSimilarity is Map) {
      for (final entry in rawSimilarity.entries) {
        final key = entry.key;
        final value = entry.value;
        if (key is String && value is num) {
          speakingSimilarityByItemId[key] = value.toInt().clamp(0, 100);
        }
      }
    }

    final rawCompletedTracks = json['completedTracks'];
    final completedTracks = <StudyFlowTrack>{};
    if (rawCompletedTracks is List) {
      for (final entry in rawCompletedTracks) {
        final track = StudyFlowTrack.values.cast<StudyFlowTrack?>().firstWhere(
          (value) => value?.name == entry,
          orElse: () => null,
        );
        if (track != null) {
          completedTracks.add(track);
        }
      }
    }

    return StudyFlowState(
      sessionId: json['sessionId'] as String? ?? '',
      totalItems: (json['totalItems'] as num?)?.toInt() ?? 0,
      completedItems: (json['completedItems'] as num?)?.toInt() ?? 0,
      correctAnswers: (json['correctAnswers'] as num?)?.toInt() ?? 0,
      attemptedAnswers: (json['attemptedAnswers'] as num?)?.toInt() ?? 0,
      trackIndices: trackIndices,
      speakingSimilarityByItemId: speakingSimilarityByItemId,
      completedTracks: completedTracks,
    );
  }

  static const empty = StudyFlowState(
    sessionId: '',
    totalItems: 0,
    completedItems: 0,
    correctAnswers: 0,
    attemptedAnswers: 0,
    trackIndices: <StudyFlowTrack, int>{},
    speakingSimilarityByItemId: <String, int>{},
    completedTracks: <StudyFlowTrack>{},
  );
}

class StudyFlowController extends Notifier<StudyFlowState> {
  static const _lastSessionIdKey = 'study_flow.last_session_id';
  static const _sessionKeyPrefix = 'study_flow.session.';

  bool _hydrated = false;
  Future<void> _persistQueue = Future<void>.value();

  @override
  StudyFlowState build() {
    if (!_hydrated) {
      _hydrated = true;
      unawaited(_hydrate());
    }
    return StudyFlowState.empty;
  }

  void startSession({required String sessionId, required int totalItems}) {
    state = StudyFlowState(
      sessionId: sessionId,
      totalItems: totalItems,
      completedItems: 0,
      correctAnswers: 0,
      attemptedAnswers: 0,
      trackIndices: const <StudyFlowTrack, int>{},
      speakingSimilarityByItemId: const <String, int>{},
      completedTracks: const <StudyFlowTrack>{},
    );
    unawaited(persistNow());
  }

  void clear() {
    final previousSessionId = state.sessionId;
    state = StudyFlowState.empty;
    unawaited(_clearPersisted(previousSessionId));
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
    final updatedCompletedTracks = Set<StudyFlowTrack>.from(
      state.completedTracks,
    );
    if (!hasNext) {
      updatedCompletedTracks.add(track);
    }

    state = state.copyWith(
      trackIndices: updatedIndices,
      completedItems: (state.completedItems + 1).clamp(0, state.totalItems),
      attemptedAnswers: countAsAttempt
          ? state.attemptedAnswers + 1
          : state.attemptedAnswers,
      correctAnswers: isCorrectAttempt
          ? state.correctAnswers + 1
          : state.correctAnswers,
      completedTracks: updatedCompletedTracks,
    );
    unawaited(persistNow());

    return hasNext;
  }

  bool retreatTrack({required StudyFlowTrack track}) {
    final current = state.indexOf(track);
    if (current <= 0) {
      return false;
    }

    final updatedIndices = Map<StudyFlowTrack, int>.from(state.trackIndices)
      ..[track] = current - 1;
    state = state.copyWith(trackIndices: updatedIndices);
    unawaited(persistNow());
    return true;
  }

  void resetTrack({required StudyFlowTrack track}) {
    final updatedIndices = Map<StudyFlowTrack, int>.from(state.trackIndices)
      ..[track] = 0;
    final updatedCompletedTracks = Set<StudyFlowTrack>.from(
      state.completedTracks,
    )..remove(track);
    state = state.copyWith(
      trackIndices: updatedIndices,
      completedTracks: updatedCompletedTracks,
    );
    unawaited(persistNow());
  }

  void recordSpeakingSimilarity({required String itemId, required int score}) {
    final normalizedScore = score.clamp(0, 100);
    final updated = Map<String, int>.from(state.speakingSimilarityByItemId)
      ..[itemId] = normalizedScore;
    state = state.copyWith(speakingSimilarityByItemId: updated);
    unawaited(persistNow());
  }

  Future<void> persistNow() {
    final snapshot = state;
    _persistQueue = _persistQueue.then((_) => _persistSnapshot(snapshot));
    return _persistQueue;
  }

  Future<void> _persistSnapshot(StudyFlowState snapshot) async {
    if (snapshot.sessionId.isEmpty) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastSessionIdKey, snapshot.sessionId);
    await prefs.setString(
      '$_sessionKeyPrefix${snapshot.sessionId}',
      jsonEncode(snapshot.toJson()),
    );
  }

  Future<void> _hydrate() async {
    final prefs = await SharedPreferences.getInstance();
    final sessionId = prefs.getString(_lastSessionIdKey);
    if (sessionId == null || sessionId.isEmpty) {
      return;
    }
    final raw = prefs.getString('$_sessionKeyPrefix$sessionId');
    if (raw == null || raw.isEmpty) {
      return;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return;
      }
      final hydratedState = StudyFlowState.fromJson(
        Map<String, Object?>.from(decoded),
      );
      if (hydratedState.sessionId.isNotEmpty) {
        state = hydratedState;
      }
    } catch (_) {
      await _clearPersisted(sessionId);
    }
  }

  Future<void> _clearPersisted(String sessionId) {
    _persistQueue = _persistQueue.then((_) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_lastSessionIdKey);
      if (sessionId.isNotEmpty) {
        await prefs.remove('$_sessionKeyPrefix$sessionId');
      }
    });
    return _persistQueue;
  }
}

final studyFlowControllerProvider =
    NotifierProvider<StudyFlowController, StudyFlowState>(
      StudyFlowController.new,
    );
