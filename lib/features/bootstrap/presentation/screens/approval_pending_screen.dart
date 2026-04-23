import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mission_app/l10n/app_localizations.dart';

import '../../../../core/widgets/status_state_card.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../controllers/bootstrap_controller.dart';

class ApprovalPendingScreen extends ConsumerWidget {
  const ApprovalPendingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final session = ref.watch(bootstrapControllerProvider).asData?.value;

    return Scaffold(
      body: SafeArea(
        child: StatusStateCard(
          icon: Icons.pending_actions_outlined,
          title: l10n?.approvalPendingTitle ?? 'Approval Pending',
          message:
              l10n?.approvalPendingMessage ??
              'Login is complete. Admin approval is required before learning starts.',
          adminContact: session?.adminContact ?? '010-0000-0000',
          primaryAction: ElevatedButton(
            onPressed: () => ref.invalidate(bootstrapControllerProvider),
            child: Text(l10n?.refreshStatus ?? 'Refresh Status'),
          ),
          secondaryAction: OutlinedButton(
            onPressed: () => ref.read(authControllerProvider.notifier).signOut(),
            child: Text(l10n?.backToLogin ?? 'Back to Login'),
          ),
        ),
      ),
    );
  }
}
