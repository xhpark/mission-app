import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AsrPolicyMode { serverOnly, hybridWithOnDevice }

class AsrPolicyState {
  const AsrPolicyState({
    required this.hydrated,
    required this.decided,
    required this.mode,
  });

  final bool hydrated;
  final bool decided;
  final AsrPolicyMode mode;

  bool get allowOnDeviceFallback => mode == AsrPolicyMode.hybridWithOnDevice;

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
      decided: false,
      mode: AsrPolicyMode.serverOnly,
    );
  }

  Future<void> chooseServerOnly() async {
    state = state.copyWith(
      hydrated: true,
      decided: true,
      mode: AsrPolicyMode.serverOnly,
    );
    await _persist(state);
  }

  Future<void> chooseHybridWithOnDevice() async {
    state = state.copyWith(
      hydrated: true,
      decided: true,
      mode: AsrPolicyMode.hybridWithOnDevice,
    );
    await _persist(state);
  }

  Future<void> _hydrate() async {
    final prefs = await SharedPreferences.getInstance();
    final decided = prefs.getBool(_decidedKey) ?? false;
    final modeRaw = prefs.getString(_modeKey) ?? AsrPolicyMode.serverOnly.name;
    final mode = modeRaw == AsrPolicyMode.hybridWithOnDevice.name
        ? AsrPolicyMode.hybridWithOnDevice
        : AsrPolicyMode.serverOnly;
    state = AsrPolicyState(hydrated: true, decided: decided, mode: mode);
  }

  Future<void> _persist(AsrPolicyState current) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_decidedKey, current.decided);
    await prefs.setString(_modeKey, current.mode.name);
  }
}
