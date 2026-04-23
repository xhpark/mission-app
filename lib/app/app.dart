import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mission_app/l10n/app_localizations.dart';

import 'router/app_router.dart';
import 'theme/app_theme.dart';
import '../core/widgets/dev_debug_panel.dart';
import '../features/session_runtime/presentation/providers/session_runtime_providers.dart';

class MissionApp extends ConsumerWidget {
  const MissionApp({super.key});

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
        return Stack(children: [child, const DevDebugPanel()]);
      },
    );
  }
}
