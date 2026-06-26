import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 학습 화면 동작에 대한 사용자 환경설정. 현재는 자동 스크롤(다음 버튼 자동 노출) 토글만 보유.
class LearningPreferencesState {
  const LearningPreferencesState({
    required this.hydrated,
    required this.autoScrollEnabled,
  });

  final bool hydrated;
  final bool autoScrollEnabled;

  LearningPreferencesState copyWith({
    bool? hydrated,
    bool? autoScrollEnabled,
  }) {
    return LearningPreferencesState(
      hydrated: hydrated ?? this.hydrated,
      autoScrollEnabled: autoScrollEnabled ?? this.autoScrollEnabled,
    );
  }
}

final learningPreferencesProvider =
    NotifierProvider<LearningPreferencesController, LearningPreferencesState>(
  LearningPreferencesController.new,
);

class LearningPreferencesController
    extends Notifier<LearningPreferencesState> {
  static const _autoScrollKey = 'learning.autoscroll.enabled';
  static const _defaultAutoScroll = true;
  bool _loading = false;

  @override
  LearningPreferencesState build() {
    if (!_loading) {
      _loading = true;
      unawaited(_hydrate());
    }
    // 하이드레이트 전에도 기본값(ON)으로 즉시 동작하게 한다.
    return const LearningPreferencesState(
      hydrated: false,
      autoScrollEnabled: _defaultAutoScroll,
    );
  }

  Future<void> setAutoScrollEnabled(bool enabled) async {
    state = state.copyWith(hydrated: true, autoScrollEnabled: enabled);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoScrollKey, enabled);
  }

  Future<void> _hydrate() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_autoScrollKey) ?? _defaultAutoScroll;
    state = LearningPreferencesState(
      hydrated: true,
      autoScrollEnabled: enabled,
    );
  }
}
