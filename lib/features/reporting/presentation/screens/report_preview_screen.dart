import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mission_app/l10n/app_localizations.dart';

import '../../../../core/firebase/firebase_providers.dart';
import '../../../../core/widgets/app_bottom_action_bar.dart';
import '../../../../core/widgets/app_section_card.dart';
import '../../../learning_select/presentation/controllers/learning_selection_controller.dart';
import '../../../sentence_learning/presentation/controllers/current_study_session_controller.dart';
import '../../../session_runtime/presentation/providers/session_runtime_providers.dart';

class ReportPreviewScreen extends ConsumerStatefulWidget {
  const ReportPreviewScreen({super.key});

  @override
  ConsumerState<ReportPreviewScreen> createState() => _ReportPreviewScreenState();
}

class _ReportPreviewScreenState extends ConsumerState<ReportPreviewScreen> {
  Future<Map<String, dynamic>?>? _previewFuture;

  @override
  void initState() {
    super.initState();
    _previewFuture = _loadPreview();
  }

  Future<Map<String, dynamic>?> _loadPreview() async {
    final user = ref.read(authStateChangesProvider).asData?.value;
    final developmentSession = ref.read(developmentSessionProvider);
    final session = ref.read(currentStudySessionProvider);
    if (user == null || developmentSession || user.isAnonymous || session == null) {
      return null;
    }
    return ref.read(sessionRuntimeRepositoryProvider).generateReportPreview(
          userId: user.uid,
          sessionId: session.sessionId,
        );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final session = ref.watch(currentStudySessionProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n?.reportPreviewTitle ?? 'Report Preview'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          FutureBuilder<Map<String, dynamic>?>(
            future: _previewFuture,
            builder: (context, snapshot) {
              final data = snapshot.data;
              final summary = data?['summary'] as String?;
              final sessionId = data?['sessionId'] as String? ?? session?.sessionId ?? '-';
              final contentSetId =
                  data?['contentSetId'] as String? ?? session?.contentSetId ?? '-';
              final mode = data?['mode'] as String? ??
                  (session == null
                      ? '-'
                      : '${_categoryLabel(session.category, l10n)} / ${_levelLabel(session.level, l10n)} / ${_modeLabel(session.mode, l10n)}');

              return AppSectionCard(
                title: l10n?.reportPreviewSessionInfoTitle ?? 'Session Info',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (snapshot.connectionState == ConnectionState.waiting)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: LinearProgressIndicator(),
                      ),
                    Text(
                      l10n?.reportPreviewSessionId(sessionId) ??
                          'Session ID: $sessionId',
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l10n?.reportPreviewContentSet(contentSetId) ??
                          'Content Set: $contentSetId',
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l10n?.reportPreviewLearningMode(mode) ?? 'Mode: $mode',
                    ),
                    if (summary != null && summary.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        l10n?.reportPreviewSummary(summary) ?? 'Summary: $summary',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          AppSectionCard(
            title: l10n?.reportPreviewChecklistTitle ?? 'Before Submit',
            child: Text(
              l10n?.reportPreviewChecklistBody ??
                  '1) Summarize today\'s learning in 1-2 sentences.\n'
                      '2) Check listening and speaking practice completion.\n'
                      '3) After submit, you can start the next session.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ],
      ),
      bottomNavigationBar: AppBottomActionBar(
        secondaryLabel: l10n?.reportPreviewSecondaryToSummary ?? 'Back to Summary',
        onSecondaryPressed: () => context.go('/session-summary'),
        primaryLabel: l10n?.reportPreviewPrimaryToReport ?? 'Write Report',
        onPrimaryPressed: () => context.go('/report'),
      ),
    );
  }
}

String _categoryLabel(LearningCategory category, AppLocalizations? l10n) =>
    switch (category) {
      LearningCategory.daily =>
        l10n?.learningSelectCategoryDaily ?? 'Daily Conversation',
      LearningCategory.mission => l10n?.learningSelectCategoryMission ?? 'Mission',
    };

String _levelLabel(LearningLevel level, AppLocalizations? l10n) =>
    switch (level) {
      LearningLevel.beginner => l10n?.learningSelectLevelBeginner ?? 'Beginner',
      LearningLevel.intermediate =>
        l10n?.learningSelectLevelIntermediate ?? 'Intermediate',
      LearningLevel.advanced => l10n?.learningSelectLevelAdvanced ?? 'Advanced',
    };

String _modeLabel(LearningMode mode, AppLocalizations? l10n) => switch (mode) {
      LearningMode.sentenceLearning =>
        l10n?.learningSelectModeSentenceLearning ?? 'Sentence Learning',
      LearningMode.sentenceTest =>
        l10n?.learningSelectModeSentenceTest ?? 'Sentence Test',
      LearningMode.flashWordLearning =>
        l10n?.learningSelectModeFlashWordLearning ?? 'Flash Word Learning',
      LearningMode.flashWordTest =>
        l10n?.learningSelectModeFlashWordTest ?? 'Flash Word Test',
      LearningMode.flashSentenceLearning =>
        l10n?.learningSelectModeFlashSentenceLearning ?? 'Flash Sentence Learning',
      LearningMode.flashSentenceTest =>
        l10n?.learningSelectModeFlashSentenceTest ?? 'Flash Sentence Test',
    };
