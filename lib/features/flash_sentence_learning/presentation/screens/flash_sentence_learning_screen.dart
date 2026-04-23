import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mission_app/l10n/app_localizations.dart';

import '../../../../core/firebase/firebase_providers.dart';
import '../../../../core/widgets/interactive_learning_screen.dart';
import '../../../learning_content/data/thai_learning_content.dart';
import '../../../sentence_learning/presentation/controllers/current_study_session_controller.dart';
import '../../../session_runtime/presentation/controllers/study_flow_controller.dart';
import '../../../session_runtime/presentation/providers/session_runtime_providers.dart';

class FlashSentenceLearningScreen extends ConsumerWidget {
  const FlashSentenceLearningScreen({super.key});

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
    final targetIndexRaw = flow.indexOf(StudyFlowTrack.flashSentenceLearning);
    final targetIndex = targetIndexRaw > maxIndex ? maxIndex : targetIndexRaw;
    final target = sentenceAt(category, targetIndex);

    return InteractiveLearningScreen(
      title: l10n?.flashSentenceLearningTitle ?? 'Flash Sentence Learning',
      subtitle: l10n?.flashSentenceLearningSubtitle ??
          'Build sentence fluency through short repeated cycles.',
      progress: effectiveTotal <= 0 ? 0 : ((targetIndex + 1) / effectiveTotal),
      progressLabel: l10n?.flashSentenceLearningProgressLabel(
            targetIndex + 1,
            effectiveTotal,
          ) ??
          'Sentence ${targetIndex + 1} / $effectiveTotal',
      promptTitle: l10n?.flashSentenceLearningPromptTitle ?? 'Today\'s Sentence',
      foreignText: target.thaiText,
      nativeText: target.koreanText,
      pronunciation: '${target.phonetic} / ${target.hangulPronunciation}',
      hint: target.hint,
      primaryButtonLabel: l10n?.flashSentenceLearningPrimaryButton ??
          'Go to Flash Sentence Test',
      primaryRoute: '/flash-sentence-test/choice',
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
              route: '/flash-sentence-learning',
            );
      },
      onPrimaryAction: (_) async {
        final hasNext = ref.read(studyFlowControllerProvider.notifier).advanceTrack(
              track: StudyFlowTrack.flashSentenceLearning,
              totalCount: effectiveTotal,
            );
        if (session == null || user == null || user.isAnonymous || developmentSession) {
          return hasNext ? '/flash-sentence-learning' : '/flash-sentence-test/choice';
        }
        await ref.read(sessionRuntimeRepositoryProvider).saveResumeState(
              userId: user.uid,
              sessionId: session.sessionId,
              route: hasNext ? '/flash-sentence-learning' : '/flash-sentence-test/choice',
            );
        return hasNext ? '/flash-sentence-learning' : '/flash-sentence-test/choice';
      },
    );
  }
}
