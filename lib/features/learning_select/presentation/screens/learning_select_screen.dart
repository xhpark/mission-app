import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/constants/app_strings.dart';
import '../controllers/learning_selection_controller.dart';
import '../controllers/start_study_session_controller.dart';

class LearningSelectScreen extends ConsumerWidget {
  const LearningSelectScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selection = ref.watch(learningSelectionProvider);
    final controller = ref.read(learningSelectionProvider.notifier);
    final startState = ref.watch(startStudySessionControllerProvider);

    ref.listen(startStudySessionControllerProvider, (previous, next) {
      next.whenOrNull(
        data: (result) {
          if (result == null) {
            return;
          }

          context.go('/sentence-learning');
        },
        error: (error, _) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not start session: $error')),
          );
        },
      );
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.learningSelectTitle),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            AppStrings.learningSelectSubtitle,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 24),
          _SectionCard(
            title: 'Category',
            children: [
              _ChoiceChipRow<LearningCategory>(
                values: LearningCategory.values,
                selected: selection.category,
                labelBuilder: (value) => switch (value) {
                  LearningCategory.daily => 'Daily',
                  LearningCategory.mission => 'Mission',
                },
                onSelected: controller.selectCategory,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Level',
            children: [
              _ChoiceChipRow<LearningLevel>(
                values: LearningLevel.values,
                selected: selection.level,
                labelBuilder: (value) => switch (value) {
                  LearningLevel.beginner => 'Beginner',
                  LearningLevel.intermediate => 'Intermediate',
                  LearningLevel.advanced => 'Advanced',
                },
                onSelected: controller.selectLevel,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Mode',
            children: [
              _ChoiceChipRow<LearningMode>(
                values: LearningMode.values,
                selected: selection.mode,
                labelBuilder: (value) => switch (value) {
                  LearningMode.sentenceLearning => 'Sentence Learning',
                  LearningMode.sentenceTest => 'Sentence Test',
                  LearningMode.flashWordLearning => 'Flash Word Learning',
                },
                onSelected: controller.selectMode,
              ),
            ],
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: ElevatedButton(
          onPressed: selection.canProceed
              ? (startState.isLoading
                  ? null
                  : () => ref
                      .read(startStudySessionControllerProvider.notifier)
                      .start())
              : null,
          child: startState.isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text(AppStrings.proceed),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _ChoiceChipRow<T> extends StatelessWidget {
  const _ChoiceChipRow({
    required this.values,
    required this.selected,
    required this.labelBuilder,
    required this.onSelected,
  });

  final List<T> values;
  final T? selected;
  final String Function(T value) labelBuilder;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: values.map((value) {
        return ChoiceChip(
          label: Text(labelBuilder(value)),
          selected: value == selected,
          onSelected: (_) => onSelected(value),
        );
      }).toList(),
    );
  }
}
