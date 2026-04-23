import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../learning_select/data/models/study_session_result.dart';
import '../../../learning_select/presentation/controllers/learning_selection_controller.dart';

final currentStudySessionHydratedProvider = StateProvider<bool>((ref) => false);

class CurrentStudySession {
  const CurrentStudySession({
    required this.sessionId,
    required this.startedAt,
    required this.contentSetId,
    required this.category,
    required this.level,
    required this.mode,
  });

  final String sessionId;
  final String startedAt;
  final String contentSetId;
  final LearningCategory category;
  final LearningLevel level;
  final LearningMode mode;

  factory CurrentStudySession.fromSelection({
    required StudySessionResult result,
    required LearningSelectionState selection,
    required String contentSetId,
  }) {
    return CurrentStudySession(
      sessionId: result.sessionId,
      startedAt: result.startedAt,
      contentSetId: contentSetId,
      category: selection.category!,
      level: selection.level!,
      mode: selection.mode!,
    );
  }
}

class CurrentStudySessionController extends Notifier<CurrentStudySession?> {
  static const _sessionIdKey = 'current_study_session.id';
  static const _startedAtKey = 'current_study_session.started_at';
  static const _contentSetIdKey = 'current_study_session.content_set_id';
  static const _categoryKey = 'current_study_session.category';
  static const _levelKey = 'current_study_session.level';
  static const _modeKey = 'current_study_session.mode';

  bool _hydrated = false;

  @override
  CurrentStudySession? build() {
    if (!_hydrated) {
      _hydrated = true;
      unawaited(_hydrate());
    }

    return null;
  }

  void setSession(CurrentStudySession session) {
    state = session;
    ref.read(currentStudySessionHydratedProvider.notifier).state = true;
    unawaited(_persist(session));
  }

  void clear() {
    state = null;
    ref.read(currentStudySessionHydratedProvider.notifier).state = true;
    unawaited(_clearPersisted());
  }

  Future<void> _hydrate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sessionId = prefs.getString(_sessionIdKey);
      final startedAt = prefs.getString(_startedAtKey);
      final contentSetId = prefs.getString(_contentSetIdKey);
      final categoryRaw = prefs.getString(_categoryKey);
      final levelRaw = prefs.getString(_levelKey);
      final modeRaw = prefs.getString(_modeKey);

      if (state != null) {
        return;
      }

      if (sessionId == null ||
          sessionId.isEmpty ||
          startedAt == null ||
          startedAt.isEmpty ||
          contentSetId == null ||
          contentSetId.isEmpty) {
        return;
      }

      final category = _parseCategory(categoryRaw);
      final level = _parseLevel(levelRaw);
      final mode = _parseMode(modeRaw);
      if (category == null || level == null || mode == null) {
        await _clearPersisted();
        return;
      }

      state = CurrentStudySession(
        sessionId: sessionId,
        startedAt: startedAt,
        contentSetId: contentSetId,
        category: category,
        level: level,
        mode: mode,
      );
    } finally {
      ref.read(currentStudySessionHydratedProvider.notifier).state = true;
    }
  }

  Future<void> _persist(CurrentStudySession session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionIdKey, session.sessionId);
    await prefs.setString(_startedAtKey, session.startedAt);
    await prefs.setString(_contentSetIdKey, session.contentSetId);
    await prefs.setString(_categoryKey, session.category.name);
    await prefs.setString(_levelKey, session.level.name);
    await prefs.setString(_modeKey, session.mode.name);
  }

  Future<void> _clearPersisted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionIdKey);
    await prefs.remove(_startedAtKey);
    await prefs.remove(_contentSetIdKey);
    await prefs.remove(_categoryKey);
    await prefs.remove(_levelKey);
    await prefs.remove(_modeKey);
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

final currentStudySessionProvider =
    NotifierProvider<CurrentStudySessionController, CurrentStudySession?>(
      CurrentStudySessionController.new,
    );
