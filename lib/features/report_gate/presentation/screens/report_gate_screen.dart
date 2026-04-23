import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mission_app/l10n/app_localizations.dart';

import '../../../../core/firebase/firebase_providers.dart';
import '../../../../core/widgets/app_bottom_action_bar.dart';
import '../../../../core/widgets/app_section_card.dart';
import '../../../../core/widgets/app_status_banner.dart';
import '../../../reporting/presentation/controllers/report_requirement_controller.dart';
import '../../../session_runtime/presentation/providers/session_runtime_providers.dart';

class ReportGateScreen extends ConsumerStatefulWidget {
  const ReportGateScreen({super.key});

  @override
  ConsumerState<ReportGateScreen> createState() => _ReportGateScreenState();
}

class _ReportGateScreenState extends ConsumerState<ReportGateScreen> {
  bool _loading = false;
  String _gateStage = 'none';

  @override
  void initState() {
    super.initState();
    _refreshGateStatus();
  }

  Future<void> _refreshGateStatus() async {
    final user = ref.read(authStateChangesProvider).asData?.value;
    final developmentSession = ref.read(developmentSessionProvider);
    if (user == null || user.isAnonymous || developmentSession) {
      return;
    }

    setState(() => _loading = true);
    try {
      final result = await ref.read(sessionRuntimeRepositoryProvider).checkWeeklyReportGate(
            userId: user.uid,
          );
      if (!mounted) {
        return;
      }
      setState(() {
        _gateStage = result['reportGateStage'] as String? ?? 'none';
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final reportRequired = ref.watch(reportRequirementProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n?.reportGateTitle ?? 'Report Gate'),
        actions: [
          IconButton(
            tooltip: l10n?.reportGateRefreshTooltip ?? 'Refresh status',
            onPressed: _loading ? null : _refreshGateStatus,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          if (_loading) const LinearProgressIndicator(),
          AppStatusBanner(
            isError: reportRequired,
            icon: reportRequired
                ? Icons.report_problem_outlined
                : Icons.check_circle_outline,
            message: reportRequired
                ? (l10n?.reportGateBlockedMessage ??
                    'Learning is blocked until this week\'s report is submitted.')
                : (l10n?.reportGateOpenMessage ??
                    'No report requirement now. You can continue learning.'),
          ),
          const SizedBox(height: 16),
          AppSectionCard(
            title: l10n?.reportGateStatusTitle ?? 'Gate Status',
            child: Text(
              l10n?.reportGateCurrentStage(_gateStage) ??
                  'Current gate stage: $_gateStage',
            ),
          ),
          const SizedBox(height: 16),
          AppSectionCard(
            title: l10n?.reportGateNextStepsTitle ?? 'Next Steps',
            child: Text(
              l10n?.reportGateNextStepsBody ??
                  '1) Review session summary.\n'
                      '2) Write your reflection.\n'
                      '3) Submit report and wait for admin check.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ],
      ),
      bottomNavigationBar: AppBottomActionBar(
        primaryLabel: reportRequired
            ? (l10n?.reportGatePrimaryToPreview ?? 'Go to Report Preview')
            : (l10n?.reportGatePrimaryToSelect ?? 'Go to Selection'),
        onPrimaryPressed: () => context.go(reportRequired ? '/report-preview' : '/select'),
      ),
    );
  }
}
