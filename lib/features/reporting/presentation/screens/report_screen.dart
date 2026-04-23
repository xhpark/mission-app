import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mission_app/l10n/app_localizations.dart';

import '../../../../core/firebase/firebase_providers.dart';
import '../../../../core/firebase/firebase_services.dart';
import '../../../../core/widgets/app_bottom_action_bar.dart';
import '../../../../core/widgets/app_section_card.dart';
import '../../../../core/widgets/app_status_banner.dart';
import '../../../sentence_learning/presentation/controllers/current_study_session_controller.dart';
import '../../../session_runtime/presentation/controllers/study_flow_controller.dart';
import '../../../session_runtime/presentation/providers/session_runtime_providers.dart';
import '../controllers/report_requirement_controller.dart';

class ReportScreen extends ConsumerStatefulWidget {
  const ReportScreen({super.key});

  @override
  ConsumerState<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends ConsumerState<ReportScreen> {
  final TextEditingController _reflectionController = TextEditingController();
  bool _audioCompleted = false;
  bool _speakingCompleted = false;
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    _reflectionController.addListener(_onReflectionChanged);
  }

  void _onReflectionChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _reflectionController.removeListener(_onReflectionChanged);
    _reflectionController.dispose();
    super.dispose();
  }

  Future<void> _submitReport() async {
    final user = ref.read(authStateChangesProvider).asData?.value;
    final developmentSession = ref.read(developmentSessionProvider);
    final session = ref.read(currentStudySessionProvider);

    if (session == null) {
      throw StateError('An active session is required to submit report.');
    }
    if (user == null || developmentSession || user.isAnonymous) {
      throw StateError(
        'Verified authenticated account is required for report submission.',
      );
    }

    final callable = ref
        .read(firebaseFunctionsProvider)
        .httpsCallable('completeReportSubmission');
    await callable.call(<String, dynamic>{
      'userId': user.uid,
      'sessionId': session.sessionId,
      'reflection': _reflectionController.text.trim(),
      'speakingCompleted': _speakingCompleted,
      'listeningCompleted': _audioCompleted,
    });
    await ref
        .read(sessionRuntimeRepositoryProvider)
        .discardResumeState(userId: user.uid, sessionId: session.sessionId);

    ref.read(reportRequirementProvider.notifier).markSubmitted();
    ref.read(currentStudySessionProvider.notifier).clear();
    ref.read(studyFlowControllerProvider.notifier).clear();
    setState(() => _submitted = true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final session = ref.watch(currentStudySessionProvider);
    final authUser = ref.watch(authStateChangesProvider).asData?.value;
    final developmentSession = ref.watch(developmentSessionProvider);

    final hasSession = session != null;
    final canUseBackendSubmit =
        authUser != null && !authUser.isAnonymous && !developmentSession;
    final canSubmit =
        _audioCompleted &&
        _speakingCompleted &&
        _reflectionController.text.trim().isNotEmpty &&
        hasSession &&
        canUseBackendSubmit;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n?.reportTitle ?? 'Learning Report'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          if (!hasSession) ...[
            AppStatusBanner(
              isError: true,
              icon: Icons.warning_amber_rounded,
              message: l10n?.reportNoSessionBanner ??
                  'No active session. Report submission is unavailable.',
            ),
            const SizedBox(height: 12),
          ],
          if (!canUseBackendSubmit) ...[
            AppStatusBanner(
              isError: true,
              icon: Icons.lock_outline,
              message: l10n?.reportAuthRequiredBanner ??
                  'Report submission requires an authenticated account.',
            ),
            const SizedBox(height: 12),
          ],
          AppSectionCard(
            title: l10n?.reportChecklistTitle ?? 'Session Checklist',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _audioCompleted,
                  onChanged: (value) =>
                      setState(() => _audioCompleted = value ?? false),
                  title: Text(
                    l10n?.reportChecklistListening ??
                        'I completed listening practice.',
                  ),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _speakingCompleted,
                  onChanged: (value) =>
                      setState(() => _speakingCompleted = value ?? false),
                  title: Text(
                    l10n?.reportChecklistSpeaking ??
                        'I completed speaking practice.',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          AppSectionCard(
            title: l10n?.reportReflectionTitle ?? 'Learning Reflection',
            child: TextField(
              controller: _reflectionController,
              minLines: 4,
              maxLines: 6,
              decoration: InputDecoration(
                hintText: l10n?.reportReflectionHint ??
                    'Write your reflection in 1-2 sentences.',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          if (_submitted) ...[
            const SizedBox(height: 16),
            AppStatusBanner(
              icon: Icons.check_circle_outline,
              message: l10n?.reportSubmittedMessage ??
                  'Report submitted. You can start next learning.',
            ),
          ],
        ],
      ),
      bottomNavigationBar: AppBottomActionBar(
        secondaryLabel: l10n?.reportSecondaryToSummary ?? 'Back to Summary',
        onSecondaryPressed: () => context.go('/session-summary'),
        primaryLabel: _submitted
            ? (l10n?.reportPrimaryDone ?? 'Submitted')
            : (l10n?.reportPrimarySubmit ?? 'Submit Report'),
        onPrimaryPressed: canSubmit
            ? () async {
                try {
                  await _submitReport();
                } catch (_) {
                  if (!context.mounted) {
                    return;
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        l10n?.reportSubmitFailed ??
                            'Report submission failed. Please try again.',
                      ),
                    ),
                  );
                }
              }
            : null,
      ),
    );
  }
}
