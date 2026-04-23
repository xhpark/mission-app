import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/firebase/firebase_providers.dart';
import '../../../../core/firebase/firebase_services.dart';
import '../../data/repositories/session_runtime_repository.dart';

final sessionRuntimeRepositoryProvider = Provider<SessionRuntimeRepository>((
  ref,
) {
  return SessionRuntimeRepository(
    ref.watch(firebaseFunctionsProvider),
    ref.watch(firebaseStorageProvider),
  );
});

final speakingFallbackSyncWorkerProvider =
    NotifierProvider<SpeakingFallbackSyncWorker, SpeakingFallbackSyncState>(
      SpeakingFallbackSyncWorker.new,
    );

class SpeakingFallbackSyncState {
  const SpeakingFallbackSyncState({
    required this.pendingCount,
    required this.syncing,
    this.lastSyncedAt,
    this.lastError,
  });

  final int pendingCount;
  final bool syncing;
  final DateTime? lastSyncedAt;
  final String? lastError;

  SpeakingFallbackSyncState copyWith({
    int? pendingCount,
    bool? syncing,
    DateTime? lastSyncedAt,
    String? lastError,
  }) {
    return SpeakingFallbackSyncState(
      pendingCount: pendingCount ?? this.pendingCount,
      syncing: syncing ?? this.syncing,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      lastError: lastError,
    );
  }
}

class SpeakingFallbackSyncWorker extends Notifier<SpeakingFallbackSyncState> {
  static const _syncInterval = Duration(seconds: 45);
  Timer? _timer;
  bool _bootstrapped = false;

  @override
  SpeakingFallbackSyncState build() {
    if (!_bootstrapped) {
      _bootstrapped = true;
      ref.onDispose(() {
        _timer?.cancel();
      });
      unawaited(_bootstrap());
    }
    return const SpeakingFallbackSyncState(pendingCount: 0, syncing: false);
  }

  Future<void> syncNow() async {
    final user = ref.read(authStateChangesProvider).asData?.value;
    final developmentSession = ref.read(developmentSessionProvider);
    if (developmentSession || user == null || user.isAnonymous) {
      return;
    }
    if (state.syncing) {
      return;
    }
    if (state.pendingCount <= 0) {
      _stopTimer();
      return;
    }
    state = state.copyWith(syncing: true, lastError: null);
    try {
      final report = await ref
          .read(sessionRuntimeRepositoryProvider)
          .syncQueuedSpeakingFallbacks(userId: user.uid);
      state = state.copyWith(
        syncing: false,
        pendingCount: report.pendingAfterSync,
        lastSyncedAt: DateTime.now(),
        lastError: null,
      );
      _updateTimerByPending(state.pendingCount);
    } catch (error) {
      final pending = await ref
          .read(sessionRuntimeRepositoryProvider)
          .queuedSpeakingFallbackCount();
      state = state.copyWith(
        syncing: false,
        pendingCount: pending,
        lastError: error.toString(),
      );
      _updateTimerByPending(state.pendingCount);
    }
  }

  Future<void> refreshPendingCount() async {
    final user = ref.read(authStateChangesProvider).asData?.value;
    final developmentSession = ref.read(developmentSessionProvider);
    if (developmentSession || user == null || user.isAnonymous) {
      _stopTimer();
      state = state.copyWith(pendingCount: 0, lastError: null);
      return;
    }
    final pending = await ref
        .read(sessionRuntimeRepositoryProvider)
        .queuedSpeakingFallbackCount(userId: user.uid);
    state = state.copyWith(pendingCount: pending, lastError: null);
    _updateTimerByPending(pending);
    if (pending > 0) {
      unawaited(syncNow());
    }
  }

  Future<void> _bootstrap() async {
    await refreshPendingCount();
  }

  void _updateTimerByPending(int pendingCount) {
    if (pendingCount > 0) {
      _startTimerIfNeeded();
      return;
    }
    _stopTimer();
  }

  void _startTimerIfNeeded() {
    if (_timer != null) {
      return;
    }
    _timer = Timer.periodic(_syncInterval, (_) {
      unawaited(syncNow());
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }
}
