import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mission_app/l10n/app_localizations.dart';

import '../../../../core/firebase/firebase_providers.dart';
import '../../../../core/widgets/interactive_learning_screen.dart';
import '../../../learning_content/data/thai_learning_content.dart';
import '../../../sentence_learning/presentation/controllers/current_study_session_controller.dart';
import '../../../session_runtime/presentation/controllers/study_flow_controller.dart';
import '../../../session_runtime/presentation/providers/session_runtime_providers.dart';

class FlashWordLearningScreen extends ConsumerWidget {
  const FlashWordLearningScreen({super.key});

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
    final currentIndexRaw = flow.indexOf(StudyFlowTrack.flashWordLearning);
    final currentIndex = currentIndexRaw > maxIndex ? maxIndex : currentIndexRaw;
    final current = wordAt(category, currentIndex);

    return InteractiveLearningScreen(
      title: l10n?.flashWordLearningTitle ?? 'Flash Word Learning',
      subtitle: l10n?.flashWordLearningSubtitle ??
          'Build core vocabulary through short repeated cycles.',
      progress: effectiveTotal <= 0 ? 0 : ((currentIndex + 1) / effectiveTotal),
      progressLabel: l10n?.flashWordLearningProgressLabel(
            currentIndex + 1,
            effectiveTotal,
          ) ??
          'Word ${currentIndex + 1} / $effectiveTotal',
      promptTitle: l10n?.flashWordLearningPromptTitle ?? 'Today\'s Word',
      foreignText: current.thaiWord,
      nativeText: current.koreanMeaning,
      pronunciation: '${current.phonetic} / ${current.hangulPronunciation}',
      hint: current.note.isEmpty ? current.englishMeaning : current.note,
      primaryButtonLabel:
          l10n?.flashWordLearningPrimaryButton ?? 'Go to Flash Word Test',
      primaryRoute: '/flash-word-test',
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
              route: '/flash-word-learning',
            );
      },
      onPrimaryAction: (_) async {
        final hasNext = ref.read(studyFlowControllerProvider.notifier).advanceTrack(
              track: StudyFlowTrack.flashWordLearning,
              totalCount: effectiveTotal,
            );
        if (session == null || user == null || user.isAnonymous || developmentSession) {
          return hasNext ? '/flash-word-learning' : '/flash-word-test';
        }
        await ref.read(sessionRuntimeRepositoryProvider).saveResumeState(
              userId: user.uid,
              sessionId: session.sessionId,
              route: hasNext ? '/flash-word-learning' : '/flash-word-test',
            );
        return hasNext ? '/flash-word-learning' : '/flash-word-test';
      },
    );
  }
}
