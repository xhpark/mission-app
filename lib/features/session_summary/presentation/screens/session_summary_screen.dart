import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mission_app/l10n/app_localizations.dart';

import '../../../../core/widgets/app_bottom_action_bar.dart';
import '../../../../core/widgets/app_section_card.dart';
import '../../../../core/widgets/app_status_banner.dart';
import '../../../../core/widgets/word_wrap_text.dart';
import '../../../learning_select/presentation/controllers/learning_selection_controller.dart';
import '../../../reporting/presentation/controllers/report_requirement_controller.dart';
import '../../../session_runtime/presentation/controllers/study_flow_controller.dart';
import '../../../sentence_learning/presentation/controllers/current_study_session_controller.dart';

class SessionSummaryScreen extends ConsumerWidget {
  const SessionSummaryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = _resolveL10n(context);
    final session = ref.watch(currentStudySessionProvider);
    final flow = ref.watch(studyFlowControllerProvider);
    final accuracy = flow.attemptedAnswers == 0
        ? 0
        : ((flow.correctAnswers / flow.attemptedAnswers) * 100).round();
    final averageSimilarity = flow.averageSimilarityScore;
    final stats = <({String label, String value})>[
      (label: l10n.sessionSummaryStatTotalItems, value: '${flow.totalItems}'),
      (
        label: l10n.sessionSummaryStatCompletedItems,
        value: '${flow.completedItems}',
      ),
      (label: l10n.sessionSummaryStatAccuracy, value: '$accuracy%'),
      (
        label: l10n.sessionSummaryStatCorrectAnswers,
        value: '${flow.correctAnswers} / ${flow.attemptedAnswers}',
      ),
      (
        label: l10n.sessionSummaryStatAverageSimilarity,
        value: averageSimilarity == null ? '-' : '$averageSimilarity%',
      ),
      (
        label: l10n.sessionSummaryStatSessionId,
        value: flow.sessionId.isEmpty ? '-' : flow.sessionId,
      ),
    ];

    final subtitle = session == null
        ? l10n.sessionSummarySubtitleNoSession
        : l10n.sessionSummarySubtitleWithMode(_modeLabel(session.mode, l10n));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.sessionSummaryTitle)),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          AppStatusBanner(
            tone: AppStatusTone.info,
            icon: Icons.celebration_outlined,
            message: subtitle,
          ),
          const SizedBox(height: 12),
          AppSectionCard(
            title: l10n.sessionSummaryResultTitle,
            description: l10n.sessionSummaryResultDescription,
            icon: Icons.insights_outlined,
            titleStyle: Theme.of(context).textTheme.headlineSmall,
            child: Column(
              children: stats
                  .map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final isCompact = constraints.maxWidth < 520;
                          if (isCompact) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.label,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  item.value,
                                  style: Theme.of(context).textTheme.bodyLarge,
                                ),
                              ],
                            );
                          }

                          return Row(
                            children: [
                              Expanded(
                                child: Text(
                                  item.label,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                item.value,
                                style: Theme.of(context).textTheme.bodyLarge,
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 16),
          AppSectionCard(
            title: l10n.sessionSummaryReportRecommendationTitle,
            icon: Icons.recommend_outlined,
            child: WordWrapText(
              l10n.sessionSummaryReportRecommendationBody,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.red,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: AppBottomActionBar(
        secondaryLabel: '처음부터 다시 학습',
        onSecondaryPressed: () => context.go('/select'),
        primaryLabel: l10n.reportPrimarySubmit,
        onPrimaryPressed: () {
          ref.read(reportRequirementProvider.notifier).requireReport();
          context.go('/report');
        },
      ),
    );
  }
}

AppLocalizations _resolveL10n(BuildContext context) {
  return AppLocalizations.of(context) ??
      lookupAppLocalizations(const Locale('ko'));
}

String _modeLabel(LearningMode mode, AppLocalizations l10n) => switch (mode) {
  LearningMode.sentenceLearning => l10n.learningSelectModeSentenceLearning,
  LearningMode.sentenceTest => l10n.learningSelectModeSentenceTest,
  LearningMode.flashWordLearning => l10n.learningSelectModeFlashWordLearning,
  LearningMode.flashWordTest => l10n.learningSelectModeFlashWordTest,
  LearningMode.flashSentenceLearning =>
    l10n.learningSelectModeFlashSentenceLearning,
  LearningMode.flashSentenceTest => l10n.learningSelectModeFlashSentenceTest,
};
