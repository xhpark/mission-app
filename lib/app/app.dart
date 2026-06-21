import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mission_app/l10n/app_localizations.dart';

import 'router/app_router.dart';
import 'theme/app_theme.dart';
import '../core/widgets/dev_debug_panel.dart';
import '../features/session_runtime/presentation/controllers/study_flow_controller.dart';
import '../features/session_runtime/presentation/providers/session_runtime_providers.dart';

class MissionApp extends ConsumerWidget {
  const MissionApp({super.key});

  static const _showQaDebugPanel = bool.fromEnvironment(
    'SHOW_QA_DEBUG',
    defaultValue: false,
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(speakingFallbackSyncWorkerProvider);
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      onGenerateTitle: (context) =>
          AppLocalizations.of(context)?.appTitle ?? 'Mission Language Learning',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(),
      locale: const Locale('ko'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
      builder: (context, child) {
        if (child == null) {
          return const SizedBox.shrink();
        }
        final guardedChild = _StudyLifecyclePersistenceGuard(child: child);
        if (!kDebugMode || !_showQaDebugPanel) {
          return guardedChild;
        }
        return Stack(children: [guardedChild, const DevDebugPanel()]);
      },
    );
  }
}

class _StudyLifecyclePersistenceGuard extends ConsumerStatefulWidget {
  const _StudyLifecyclePersistenceGuard({required this.child});

  final Widget child;

  @override
  ConsumerState<_StudyLifecyclePersistenceGuard> createState() =>
      _StudyLifecyclePersistenceGuardState();
}

class _StudyLifecyclePersistenceGuardState
    extends ConsumerState<_StudyLifecyclePersistenceGuard>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        unawaited(ref.read(studyFlowControllerProvider.notifier).persistNow());
        break;
      case AppLifecycleState.resumed:
        break;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
