import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mission_app/l10n/app_localizations.dart';

import '../../../../core/firebase/firebase_providers.dart';
import '../../../../core/widgets/interactive_learning_screen.dart';
import '../../../learning_content/data/thai_learning_content.dart';
import '../../../sentence_learning/presentation/controllers/current_study_session_controller.dart';
import '../../../session_runtime/presentation/controllers/study_flow_controller.dart';
import '../../../session_runtime/presentation/providers/session_runtime_providers.dart';

class SentenceTestChoiceScreen extends ConsumerWidget {
  const SentenceTestChoiceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final session = ref.watch(currentStudySessionProvider);
    final user = ref.watch(authStateChangesProvider).asData?.value;
    final developmentSession = ref.watch(developmentSessionProvider);
    final flow = ref.watch(studyFlowControllerProvider);
    final category = session?.category.name ?? 'daily';
    final sentences = sentencesByCategory(category);
    final effectiveTotal = flow.totalItems > 0 && flow.totalItems < sentences.length
        ? flow.totalItems
        : sentences.length;
    final maxIndex = effectiveTotal > 0 ? effectiveTotal - 1 : 0;
    final targetIndexRaw = flow.indexOf(StudyFlowTrack.sentenceTestChoice);
    final targetIndex = targetIndexRaw > maxIndex ? maxIndex : targetIndexRaw;
    final target = sentenceAt(category, targetIndex);
    final options = sentenceThaiOptions(
      category: category,
      correctIndex: targetIndex,
    );

    return InteractiveLearningScreen(
      title: l10n?.sentenceTestChoiceTitle ?? 'Sentence Test - Choice',
      subtitle: l10n?.sentenceTestChoiceSubtitle ??
          'Select the Thai sentence that matches Korean.',
      progress: effectiveTotal <= 0 ? 0 : ((targetIndex + 1) / effectiveTotal),
      progressLabel: l10n?.sentenceTestChoiceProgressLabel(
            targetIndex + 1,
            effectiveTotal,
          ) ??
          'Question ${targetIndex + 1} / $effectiveTotal',
      promptTitle: l10n?.sentenceTestChoicePromptTitle ?? 'Choose from Korean prompt',
      foreignText: target.koreanText,
      nativeText: target.englishText,
      pronunciation: '${target.phonetic} / ${target.hangulPronunciation}',
      hint: target.hint,
      options: options,
      correctOptionIndex: 0,
      primaryButtonLabel:
          l10n?.sentenceTestChoicePrimaryButton ?? 'Go to Speaking Test',
      primaryRoute: '/sentence-test/speaking',
      showBackButton: true,
      backFallbackRoute: '/select',
      timeLimitSeconds: 45,
      onScreenOpened: () async {
        if (session == null || user == null || user.isAnonymous || developmentSession) {
          return;
        }
        await ref.read(sessionRuntimeRepositoryProvider).saveResumeState(
              userId: user.uid,
              sessionId: session.sessionId,
              route: '/sentence-test/choice',
            );
      },
      onPrimaryAction: (payload) async {
        final hasNext = ref.read(studyFlowControllerProvider.notifier).advanceTrack(
              track: StudyFlowTrack.sentenceTestChoice,
              totalCount: effectiveTotal,
              isCorrectAttempt:
                  (payload.selectedIndex ?? -1) == (payload.correctOptionIndex ?? -2),
              countAsAttempt: true,
            );
        if (session == null || user == null || user.isAnonymous || developmentSession) {
          return hasNext ? '/sentence-test/choice' : '/sentence-test/speaking';
        }
        await ref.read(sessionRuntimeRepositoryProvider).submitChoiceTestItem(
              userId: user.uid,
              sessionId: session.sessionId,
              itemId: target.id,
              selectedIndex: payload.selectedIndex ?? 0,
              correctIndex: payload.correctOptionIndex ?? 0,
              elapsedSeconds: payload.elapsedSeconds,
            );
        await ref.read(sessionRuntimeRepositoryProvider).saveResumeState(
              userId: user.uid,
              sessionId: session.sessionId,
              route: hasNext ? '/sentence-test/choice' : '/sentence-test/speaking',
            );
        return hasNext ? '/sentence-test/choice' : '/sentence-test/speaking';
      },
    );
  }
}
