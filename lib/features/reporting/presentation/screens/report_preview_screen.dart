import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mission_app/l10n/app_localizations.dart';

import '../../../../core/firebase/firebase_providers.dart';
import '../../../../core/widgets/app_bottom_action_bar.dart';
import '../../../../core/widgets/app_section_card.dart';
import '../../../learning_select/presentation/controllers/learning_selection_controller.dart';
import '../../domain/report_metrics.dart';
import '../../../sentence_learning/presentation/controllers/current_study_session_controller.dart';
import '../../../session_runtime/presentation/controllers/study_flow_controller.dart';
import '../../../session_runtime/presentation/providers/session_runtime_providers.dart';

class ReportPreviewScreen extends ConsumerStatefulWidget {
  const ReportPreviewScreen({super.key});

  @override
  ConsumerState<ReportPreviewScreen> createState() =>
      _ReportPreviewScreenState();
}

class _ReportPreviewScreenState extends ConsumerState<ReportPreviewScreen> {
  Future<Map<String, dynamic>?>? _previewFuture;
  bool _listeningChecked = false;
  bool _speakingChecked = false;

  @override
  void initState() {
    super.initState();
    _previewFuture = _loadPreview();
  }

  Future<Map<String, dynamic>?> _loadPreview() async {
    final user = ref.read(authStateChangesProvider).asData?.value;
    final developmentSession = ref.read(developmentSessionProvider);
    final session = ref.read(currentStudySessionProvider);
    if (user == null ||
        developmentSession ||
        user.isAnonymous ||
        session == null) {
      return null;
    }
    return ref
        .read(sessionRuntimeRepositoryProvider)
        .generateReportPreview(userId: user.uid, sessionId: session.sessionId);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final session = ref.watch(currentStudySessionProvider);
    final flow = ref.watch(studyFlowControllerProvider);
    final metrics = buildReportMetrics(flow);

    return Scaffold(
      appBar: AppBar(title: Text(l10n?.reportDraftTitle ?? 'Report Draft')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          FutureBuilder<Map<String, dynamic>?>(
            future: _previewFuture,
            builder: (context, snapshot) {
              final data = snapshot.data;
              final summary = data?['summary'] as String?;
              final sessionId =
                  data?['sessionId'] as String? ?? session?.sessionId ?? '-';
              final learnerName = (data?['learnerName'] as String?)?.trim();
              final learnerPhone = (data?['learnerPhone'] as String?)?.trim();
              final contentSetId =
                  data?['contentSetId'] as String? ??
                  session?.contentSetId ??
                  '-';
              final mode =
                  data?['mode'] as String? ??
                  (session == null
                      ? '-'
                      : '${_categoryLabel(session.category, l10n)} / ${_levelLabel(session.level, l10n)} / ${_modeLabel(session.mode, l10n)}');

              final draftText = _buildReportDraftText(
                l10n: l10n,
                sessionId: sessionId,
                learnerName: (learnerName == null || learnerName.isEmpty)
                    ? '-'
                    : learnerName,
                learnerPhone: (learnerPhone == null || learnerPhone.isEmpty)
                    ? '-'
                    : learnerPhone,
                contentSetId: contentSetId,
                mode: mode,
                totalItems: flow.totalItems,
                completedItems: flow.completedItems,
                assessmentApplicable: metrics.hasAssessment,
                accuracy: metrics.accuracy,
                correctAnswers: flow.correctAnswers,
                attemptedAnswers: flow.attemptedAnswers,
                averageSimilarity: metrics.hasSpeaking
                    ? metrics.averageSimilarity
                    : null,
                summary: summary,
              );

              return AppSectionCard(
                title: l10n?.reportDraftTitle ?? 'Report Draft',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (snapshot.connectionState == ConnectionState.waiting)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: LinearProgressIndicator(),
                      ),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: SelectableText(
                        draftText,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                      ),
                      child: Column(
                        children: [
                          CheckboxListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            controlAffinity: ListTileControlAffinity.trailing,
                            value: _listeningChecked,
                            onChanged: (value) {
                              setState(
                                () => _listeningChecked = value ?? false,
                              );
                            },
                            title: Text(
                              l10n?.reportChecklistListening ??
                                  'Listening completed.',
                            ),
                          ),
                          CheckboxListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            controlAffinity: ListTileControlAffinity.trailing,
                            value: _speakingChecked,
                            onChanged: (value) {
                              setState(() => _speakingChecked = value ?? false);
                            },
                            title: Text(
                              l10n?.reportChecklistSpeaking ??
                                  'Speaking completed.',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          foregroundColor: Colors.white,
                          iconColor: Colors.white,
                        ),
                        onPressed: () async {
                          await Clipboard.setData(
                            ClipboardData(text: draftText),
                          );
                          if (!context.mounted) {
                            return;
                          }
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                l10n?.reportDraftCopied ??
                                    'Report draft copied.',
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.copy_all_rounded),
                        label: Text(
                          l10n?.reportDraftCopyButton ?? 'Copy report draft',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      bottomNavigationBar: AppBottomActionBar(
        secondaryLabel:
            l10n?.reportPreviewSecondaryToSummary ?? 'Back to Summary',
        onSecondaryPressed: () => context.go('/session-summary'),
        primaryLabel: l10n?.reportPrimarySubmit ?? 'Submit Report',
        onPrimaryPressed: () => context.go('/report'),
      ),
    );
  }
}

String _buildReportDraftText({
  required AppLocalizations? l10n,
  required String sessionId,
  required String learnerName,
  required String learnerPhone,
  required String contentSetId,
  required String mode,
  required int totalItems,
  required int completedItems,
  required bool assessmentApplicable,
  required int? accuracy,
  required int correctAnswers,
  required int attemptedAnswers,
  required int? averageSimilarity,
  required String? summary,
}) {
  final resultSummary = summary?.trim().isNotEmpty == true
      ? summary!.trim()
      : (l10n?.reportDraftDefaultSummary ?? 'This session has been completed.');
  final averageLabel = averageSimilarity == null ? '-' : '$averageSimilarity%';
  final assessmentLabel = assessmentApplicable ? null : '해당 없음';

  return [
    l10n?.reportDraftLineSessionId(sessionId) ?? 'Session ID: $sessionId',
    l10n?.reportDraftLineLearnerName(learnerName) ?? '학습자 이름: $learnerName',
    l10n?.reportDraftLineLearnerPhone(learnerPhone) ??
        '학습자 전화번호: $learnerPhone',
    l10n?.reportDraftLineContentSet(contentSetId) ??
        'Content Set: $contentSetId',
    l10n?.reportDraftLineMode(mode) ?? 'Learning Mode: $mode',
    l10n?.reportDraftLineTotalItems(totalItems) ?? 'Total Items: $totalItems',
    l10n?.reportDraftLineCompletedItems(completedItems) ??
        'Completed Items: $completedItems',
    assessmentApplicable
        ? (l10n?.reportDraftLineAccuracy(accuracy ?? 0) ??
              'Accuracy: ${accuracy ?? '-'}%')
        : '정답률: $assessmentLabel',
    l10n?.reportDraftLineCorrectAnswers(
          assessmentApplicable
              ? '$correctAnswers / $attemptedAnswers'
              : assessmentLabel!,
        ) ??
        (assessmentApplicable
            ? 'Correct Answers: $correctAnswers / $attemptedAnswers'
            : 'Correct Answers: $assessmentLabel'),
    l10n?.reportDraftLineAverageSimilarity(averageLabel) ??
        'Average Similarity: $averageLabel',
    l10n?.reportDraftLineSummary(resultSummary) ??
        'Session Summary: $resultSummary',
  ].join('\n');
}

String _categoryLabel(LearningCategory category, AppLocalizations? l10n) =>
    switch (category) {
      LearningCategory.daily =>
        l10n?.learningSelectCategoryDaily ?? 'Daily Conversation',
      LearningCategory.mission =>
        l10n?.learningSelectCategoryMission ?? 'Mission',
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
