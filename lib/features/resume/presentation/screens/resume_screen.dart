import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mission_app/l10n/app_localizations.dart';

import '../../../../core/firebase/firebase_providers.dart';
import '../../../../core/widgets/app_bottom_action_bar.dart';
import '../../../../core/widgets/app_section_card.dart';
import '../../../learning_select/domain/study_mode_route_resolver.dart';
import '../../../learning_select/presentation/controllers/learning_selection_controller.dart';
import '../../../session_runtime/presentation/controllers/study_flow_controller.dart';
import '../../../session_runtime/presentation/providers/session_runtime_providers.dart';
import '../../../sentence_learning/presentation/controllers/current_study_session_controller.dart';

class ResumeScreen extends ConsumerWidget {
  const ResumeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final session = ref.watch(currentStudySessionProvider);
    final user = ref.watch(authStateChangesProvider).asData?.value;
    final developmentSession = ref.watch(developmentSessionProvider);
    final selection = ref.watch(learningSelectionProvider);
    final flow = ref.watch(studyFlowControllerProvider);
    final resumeRoute = session != null
        ? resumeRouteForSession(session.mode, flow)
        : routeForSelectionOrFallback(selection);
    final sessionText = session == null
        ? '진행 중인 세션이 없습니다.\n학습 모드를 선택하고 학습을 시작해 주세요.'
        : '최근 세션: '
            '${_categoryLabel(session.category, l10n)} ${_modeLabel(session.mode, l10n)}\n'
            '콘텐츠 세트: ${session.contentSetId}\n'
            '시작 시각: ${session.startedAt}';

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n?.resumeTitle ?? 'Resume Learning'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          AppSectionCard(
            title: l10n?.resumeHeader ?? 'Current Session Info',
            child: Text(
              sessionText,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ],
      ),
      bottomNavigationBar: AppBottomActionBar(
        secondaryLabel: l10n?.resumeStartNew ?? 'Start New Session',
        onSecondaryPressed: () async {
          if (session != null &&
              user != null &&
              !user.isAnonymous &&
              !developmentSession) {
            await ref.read(sessionRuntimeRepositoryProvider).discardResumeState(
                  userId: user.uid,
                  sessionId: session.sessionId,
                );
          }
          if (context.mounted) {
            context.go('/select');
          }
        },
        primaryLabel: session == null
            ? (l10n?.resumeGoToMode ?? 'Go to Selection')
            : (l10n?.resumeSession ?? 'Resume Session'),
        onPrimaryPressed: () async {
          if (session != null &&
              user != null &&
              !user.isAnonymous &&
              !developmentSession) {
            await ref.read(sessionRuntimeRepositoryProvider).saveResumeState(
                  userId: user.uid,
                  sessionId: session.sessionId,
                  route: resumeRoute,
                );
          }
          if (context.mounted) {
            context.go(resumeRoute);
          }
        },
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
