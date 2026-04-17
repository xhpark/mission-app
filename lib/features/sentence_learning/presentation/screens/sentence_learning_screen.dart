import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/constants/app_strings.dart';
import '../../data/models/sentence_learning_item.dart';
import '../../../learning_select/presentation/controllers/learning_selection_controller.dart';
import '../controllers/current_study_session_controller.dart';
import '../controllers/sentence_learning_controller.dart';

class SentenceLearningScreen extends ConsumerWidget {
  const SentenceLearningScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(currentStudySessionProvider);
    final sentenceItemState = ref.watch(sentenceLearningControllerProvider);

    ref.listen(sentenceLearningControllerProvider, (previous, next) {
      next.whenOrNull(
        error: (error, _) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Could not advance the sentence session: $error'),
            ),
          );
        },
      );
    });

    if (session == null) {
      return const Scaffold(
        body: Center(
          child: Text('No active session found.'),
        ),
      );
    }

    final cards = <({String label, String value})>[
      (label: 'Session ID', value: session.sessionId),
      (label: 'Started At', value: session.startedAt),
      (label: 'Content Set', value: session.contentSetId),
      (label: 'Category', value: session.categoryLabel),
      (label: 'Level', value: session.levelLabel),
      (label: 'Mode', value: session.modeLabel),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.studySessionTitle),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            AppStrings.studySessionSubtitle,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppStrings.sessionOverview,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  ...cards.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 104,
                            child: Text(
                              item.label,
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              item.value,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppStrings.learningFlow,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    session.mode == LearningMode.sentenceLearning
                        ? 'The sentence learning route is connected and now requests the first sentence payload for this session.'
                        : 'This mode is started and tracked, and its dedicated learning screen can now be built on top of the shared session state.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  if (session.mode == LearningMode.sentenceLearning)
                    sentenceItemState.when(
                      data: (item) => item == null
                          ? _PlaceholderCard(
                              message: AppStrings.firstSentencePlaceholder,
                            )
                          : _SentenceItemCard(
                              item: item,
                              isLoading: sentenceItemState.isLoading,
                              onComplete: () => ref
                                  .read(
                                    sentenceLearningControllerProvider.notifier,
                                  )
                                  .completeCurrentItem(),
                            ),
                      loading: () => const _LoadingCard(),
                      error: (error, _) => _PlaceholderCard(
                        message: 'Could not load the first sentence: $error',
                      ),
                    )
                  else
                    _PlaceholderCard(
                      message: AppStrings.firstSentencePlaceholder,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SentenceItemCard extends StatelessWidget {
  const _SentenceItemCard({
    required this.item,
    required this.isLoading,
    required this.onComplete,
  });

  final SentenceLearningItem item;
  final bool isLoading;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppStrings.firstSentenceTitle,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 12),
          Text(
            item.thaiText,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            item.nativeText,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 16),
          Text(
            '${AppStrings.pronunciationLabel}: ${item.pronunciation}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          Text(
            '${AppStrings.hintLabel}: ${item.hint}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          Text(
            '${AppStrings.progressLabel}: ${item.currentStep} / ${item.totalSteps}',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 16),
          if (item.sessionCompleted)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                AppStrings.sessionCompletedMessage,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isLoading ? null : onComplete,
                child: isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text(AppStrings.completeAndContinue),
              ),
            ),
        ],
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text('Loading the first sentence...'),
          ),
        ],
      ),
    );
  }
}

class _PlaceholderCard extends StatelessWidget {
  const _PlaceholderCard({
    required this.message,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }
}
