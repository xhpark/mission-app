import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mission_app/l10n/app_localizations.dart';

import '../../../../core/widgets/status_state_card.dart';
import '../controllers/bootstrap_controller.dart';

class LearningBlockedScreen extends ConsumerWidget {
  const LearningBlockedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final session = ref.watch(bootstrapControllerProvider).asData?.value;

    return Scaffold(
      body: SafeArea(
        child: StatusStateCard(
          icon: Icons.report_problem_outlined,
          title: l10n?.learningBlockedTitle ?? 'Learning Temporarily Blocked',
          message:
              l10n?.learningBlockedMessage ??
              'Learning is paused until mandatory report is submitted.',
          adminContact: session?.adminContact ?? '010-0000-0000',
          primaryAction: ElevatedButton(
            onPressed: () => ref.invalidate(bootstrapControllerProvider),
            child: Text(l10n?.refreshStatus ?? 'Refresh Status'),
          ),
        ),
      ),
    );
  }
}
