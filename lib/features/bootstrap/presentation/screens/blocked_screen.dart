import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mission_app/l10n/app_localizations.dart';

import '../../../../core/widgets/status_state_card.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../controllers/bootstrap_controller.dart';

class BlockedScreen extends ConsumerWidget {
  const BlockedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final session = ref.watch(bootstrapControllerProvider).asData?.value;

    return Scaffold(
      body: SafeArea(
        child: StatusStateCard(
          icon: Icons.lock_outline,
          title: l10n?.blockedTitle ?? 'Access Restricted',
          message:
              l10n?.blockedMessage ??
              'This account is currently restricted. Please contact admin.',
          adminContact: session?.adminContact ?? '010-0000-0000',
          primaryAction: ElevatedButton(
            onPressed: () => ref.read(authControllerProvider.notifier).signOut(),
            child: Text(l10n?.backToLogin ?? 'Back to Login'),
          ),
        ),
      ),
    );
  }
}
