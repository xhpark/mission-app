import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mission_app/l10n/app_localizations.dart';

import '../../../../core/widgets/app_bottom_action_bar.dart';
import '../../../../core/widgets/app_section_card.dart';
import '../../../sentence_learning/presentation/controllers/current_study_session_controller.dart';
import '../../domain/study_mode_route_resolver.dart';
import '../controllers/learning_selection_controller.dart';

class LearningGuideScreen extends ConsumerWidget {
  const LearningGuideScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final session = ref.watch(currentStudySessionProvider);
    final selection = ref.watch(learningSelectionProvider);
    final startRoute = session != null
        ? routeForLearningMode(session.mode)
        : routeForSelectionOrFallback(selection);

    final principles = <String>[
      l10n?.guidePrinciple1 ??
          'Learning content uses bundled sentence/word/audio data first.',
      l10n?.guidePrinciple2 ??
          'Learning history is cumulative and preserved before report submit.',
      l10n?.guidePrinciple3 ??
          'If you choose start new, the previous active session is abandoned.',
      l10n?.guidePrinciple4 ??
          'Report submission is learner-driven and can be done anytime in session.',
      l10n?.guidePrinciple5 ??
          'Retry and sync paths are kept for network/error resilience.',
    ];

    final steps = <String>[
      l10n?.guideStep1 ?? 'Choose category, level, and mode.',
      l10n?.guideStep2 ?? 'Proceed sentence/word learning and use resume as needed.',
      l10n?.guideStep3 ?? 'Complete tests and review summary.',
      l10n?.guideStep4 ?? 'Submit cumulative report at your chosen timing.',
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n?.guideTitle ?? 'Learning Guide'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          AppSectionCard(
            title: l10n?.guidePrinciplesTitle ?? 'Learning & Report Principles',
            child: Column(
              children: List.generate(
                principles.length,
                (index) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 3),
                        child: Icon(Icons.check_circle_outline, size: 18),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          principles[index],
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          AppSectionCard(
            title: l10n?.guideStepsTitle ?? 'Flow Steps',
            child: Column(
              children: List.generate(
                steps.length,
                (index) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(radius: 14, child: Text('${index + 1}')),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          steps[index],
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: AppBottomActionBar(
        primaryLabel: l10n?.guideStart ?? 'Start Learning',
        onPrimaryPressed: () => context.go(startRoute),
      ),
    );
  }
}
