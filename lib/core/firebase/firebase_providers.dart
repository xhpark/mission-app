import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

final authStateChangesProvider = StreamProvider<User?>((ref) {
  return ref.watch(firebaseAuthProvider).authStateChanges();
});

final idTokenChangesProvider = StreamProvider<User?>((ref) {
  return ref.watch(firebaseAuthProvider).idTokenChanges();
});

final developmentSessionProvider = NotifierProvider<DevelopmentSession, bool>(
  DevelopmentSession.new,
);

class DevelopmentSession extends Notifier<bool> {
  static const _storageKey = 'development_session.enabled';
  bool _hydrated = false;

  @override
  bool build() {
    if (!_hydrated) {
      _hydrated = true;
      unawaited(_hydrate());
    }

    return false;
  }

  void toggle() {
    state = !state;
    unawaited(_persist(state));
  }

  set value(bool v) {
    state = v;
    unawaited(_persist(v));
  }

  Future<void> _hydrate() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getBool(_storageKey) ?? false;
    state = stored;
  }

  Future<void> _persist(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_storageKey, value);
  }
}
