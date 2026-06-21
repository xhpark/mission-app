import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AsrPolicyMode { serverFirst, onDeviceOnly }

class AsrPolicyState {
  const AsrPolicyState({
    required this.hydrated,
    required this.decided,
    required this.mode,
  });

  final bool hydrated;
  final bool decided;
  final AsrPolicyMode mode;

  bool get useServerFirst => mode == AsrPolicyMode.serverFirst;
  bool get useOnDeviceOnly => mode == AsrPolicyMode.onDeviceOnly;
  bool get allowOnDeviceFallback => useServerFirst;

  AsrPolicyState copyWith({
    bool? hydrated,
    bool? decided,
    AsrPolicyMode? mode,
  }) {
    return AsrPolicyState(
      hydrated: hydrated ?? this.hydrated,
      decided: decided ?? this.decided,
      mode: mode ?? this.mode,
    );
  }
}

final asrPolicyProvider = NotifierProvider<AsrPolicyController, AsrPolicyState>(
  AsrPolicyController.new,
);

class AsrPolicyController extends Notifier<AsrPolicyState> {
  static const _modeKey = 'asr.policy.mode';
  static const _decidedKey = 'asr.policy.decided';
  bool _loading = false;

  @override
  AsrPolicyState build() {
    if (!_loading) {
      _loading = true;
      unawaited(_hydrate());
    }
    return const AsrPolicyState(
      hydrated: false,
      decided: true,
      mode: AsrPolicyMode.serverFirst,
    );
  }

  Future<void> chooseServerFirst() async {
    state = state.copyWith(
      hydrated: true,
      decided: true,
      mode: AsrPolicyMode.serverFirst,
    );
    await _persist(state);
  }

  Future<void> chooseOnDeviceOnly() async {
    state = state.copyWith(
      hydrated: true,
      decided: true,
      mode: AsrPolicyMode.onDeviceOnly,
    );
    await _persist(state);
  }

  Future<void> _hydrate() async {
    final prefs = await SharedPreferences.getInstance();
    final modeRaw = prefs.getString(_modeKey) ?? AsrPolicyMode.serverFirst.name;
    final mode = switch (modeRaw) {
      'hybridWithOnDevice' => AsrPolicyMode.onDeviceOnly,
      'onDeviceOnly' => AsrPolicyMode.onDeviceOnly,
      _ => AsrPolicyMode.serverFirst,
    };
    state = AsrPolicyState(hydrated: true, decided: true, mode: mode);
    await _persist(state);
  }

  Future<void> _persist(AsrPolicyState current) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_decidedKey, current.decided);
    await prefs.setString(_modeKey, current.mode.name);
  }
}
