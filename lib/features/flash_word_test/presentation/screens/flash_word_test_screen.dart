import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mission_app/l10n/app_localizations.dart';

import '../../../../core/firebase/firebase_providers.dart';
import '../../../../core/widgets/interactive_learning_screen.dart';
import '../../../learning_content/data/thai_learning_content.dart';
import '../../../sentence_learning/presentation/controllers/current_study_session_controller.dart';
import '../../../session_runtime/presentation/controllers/study_flow_controller.dart';
import '../../../session_runtime/presentation/providers/session_runtime_providers.dart';

class FlashWordTestScreen extends ConsumerWidget {
  const FlashWordTestScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final session = ref.watch(currentStudySessionProvider);
    final user = ref.watch(authStateChangesProvider).asData?.value;
    final developmentSession = ref.watch(developmentSessionProvider);
    final flow = ref.watch(studyFlowControllerProvider);
    final category = session?.category.name ?? 'daily';
    final words = wordsByCategory(category);
    final effectiveTotal = flow.totalItems > 0 && flow.totalItems < words.length
        ? flow.totalItems
        : words.length;
    final maxIndex = effectiveTotal > 0 ? effectiveTotal - 1 : 0;
    final targetIndexRaw = flow.indexOf(StudyFlowTrack.flashWordTest);
    final targetIndex = targetIndexRaw > maxIndex ? maxIndex : targetIndexRaw;
    final target = wordAt(category, targetIndex);
    final options = wordEnglishOptions(
      category: category,
      correctIndex: targetIndex,
    );

    return InteractiveLearningScreen(
      title: l10n?.flashWordTestTitle ?? 'Flash Word Test',
      subtitle: l10n?.flashWordTestSubtitle ??
          'Select the meaning of the Thai word.',
      progress: effectiveTotal <= 0 ? 0 : ((targetIndex + 1) / effectiveTotal),
      progressLabel: l10n?.flashWordTestProgressLabel(
            targetIndex + 1,
            effectiveTotal,
          ) ??
          'Question ${targetIndex + 1} / $effectiveTotal',
      promptTitle: l10n?.flashWordTestPromptTitle ?? 'Check Word Meaning',
      foreignText: target.thaiWord,
      nativeText: target.koreanMeaning,
      pronunciation: '${target.phonetic} / ${target.hangulPronunciation}',
      hint: target.note.isEmpty ? target.wordType : target.note,
      options: options,
      correctOptionIndex: 0,
      primaryButtonLabel: l10n?.flashWordTestPrimaryButton ?? 'Finish Test',
      primaryRoute: '/session-summary',
      showBackButton: true,
      backFallbackRoute: '/flash-word-learning',
      timeLimitSeconds: 30,
      onScreenOpened: () async {
        if (session == null || user == null || user.isAnonymous || developmentSession) {
          return;
        }
        await ref.read(sessionRuntimeRepositoryProvider).saveResumeState(
              userId: user.uid,
              sessionId: session.sessionId,
              route: '/flash-word-test',
            );
      },
      onPrimaryAction: (payload) async {
        final hasNext = ref.read(studyFlowControllerProvider.notifier).advanceTrack(
              track: StudyFlowTrack.flashWordTest,
              totalCount: effectiveTotal,
              isCorrectAttempt:
                  (payload.selectedIndex ?? -1) == (payload.correctOptionIndex ?? -2),
              countAsAttempt: true,
            );
        if (session == null || user == null || user.isAnonymous || developmentSession) {
          return hasNext ? '/flash-word-test' : '/session-summary';
        }
        await ref.read(sessionRuntimeRepositoryProvider).submitChoiceTestItem(
              userId: user.uid,
              sessionId: session.sessionId,
              itemId: target.id,
              selectedIndex: payload.selectedIndex ?? 0,
              correctIndex: payload.correctOptionIndex ?? 0,
              elapsedSeconds: payload.elapsedSeconds,
            );
        if (hasNext) {
          await ref.read(sessionRuntimeRepositoryProvider).saveResumeState(
                userId: user.uid,
                sessionId: session.sessionId,
                route: '/flash-word-test',
              );
        } else {
          await ref.read(sessionRuntimeRepositoryProvider).discardResumeState(
                userId: user.uid,
                sessionId: session.sessionId,
              );
        }
        return hasNext ? '/flash-word-test' : '/session-summary';
      },
    );
  }
}
