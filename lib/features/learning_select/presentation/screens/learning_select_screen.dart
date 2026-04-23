import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mission_app/l10n/app_localizations.dart';

import '../../../../core/errors/app_error_messages.dart';
import '../../../../core/firebase/firebase_providers.dart';
import '../../../../core/services/asr_policy_controller.dart';
import '../../../../core/widgets/app_bottom_action_bar.dart';
import '../../../../core/widgets/app_hero_header.dart';
import '../../../../core/widgets/app_section_card.dart';
import '../../../../core/widgets/app_status_banner.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../sentence_learning/presentation/controllers/current_study_session_controller.dart';
import '../../../session_runtime/presentation/controllers/study_flow_controller.dart';
import '../../../session_runtime/presentation/providers/session_runtime_providers.dart';
import '../../domain/study_mode_route_resolver.dart';
import '../controllers/learning_selection_controller.dart';
import '../controllers/start_study_session_controller.dart';

class LearningSelectScreen extends ConsumerWidget {
  const LearningSelectScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final selection = ref.watch(learningSelectionProvider);
    final selectionController = ref.read(learningSelectionProvider.notifier);
    final activeSession = ref.watch(currentStudySessionProvider);
    final asrPolicy = ref.watch(asrPolicyProvider);
    final syncState = ref.watch(speakingFallbackSyncWorkerProvider);
    final startState = ref.watch(startStudySessionControllerProvider);
    final isStarting = startState.isLoading;
    final startError = startState.whenOrNull(
      error: (error, _) => toUserFacingErrorMessage(error),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n?.learningSelectTitle ?? 'Learning Select'),
        actions: [
          PopupMenuButton<_SelectMenuAction>(
            icon: const Icon(Icons.settings_outlined),
            onSelected: (value) => _onMenuSelected(value, context, ref),
            itemBuilder: (_) => [
              PopupMenuItem(
                value: _SelectMenuAction.guide,
                child: Text(l10n?.menuGuide ?? 'Learning Guide'),
              ),
              PopupMenuItem(
                value: _SelectMenuAction.resume,
                child: Text(l10n?.menuResume ?? 'Resume Session'),
              ),
              PopupMenuItem(
                value: _SelectMenuAction.signOut,
                child: Text(l10n?.menuSignOut ?? 'Sign Out'),
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          AppHeroHeader(
            title: l10n?.learningSelectTitle ?? 'Learning Select',
            subtitle:
                l10n?.learningSelectSubtitle ??
                'Choose category, level, and mode to start.',
            icon: Icons.school_outlined,
          ),
          const SizedBox(height: 12),
          _QuickActionRow(
            guideLabel: l10n?.menuGuide ?? 'Learning Guide',
            resumeLabel: l10n?.menuResume ?? 'Resume Session',
          ),
          const SizedBox(height: 12),
          _SelectionSummaryCard(
            summaryText: _selectionSummary(selection, l10n),
          ),
          const SizedBox(height: 16),
          _AsrPolicyCard(
            title: l10n?.learningSelectAsrPolicyTitle ?? 'Speech Recognition Policy',
            intro: l10n?.learningSelectAsrPolicyIntro ??
                'Choose speech recognition mode. You can change it later.',
            serverOnlyLabel:
                l10n?.learningSelectAsrPolicyServerOnly ?? 'Server STT Only',
            offlineLabel:
                l10n?.learningSelectAsrPolicyOffline ?? 'Offline Support',
            serverOnlyDescription:
                l10n?.learningSelectAsrPolicyServerOnlyDesc ??
                    'No local model download. Offline evaluation is unavailable.',
            offlineDescription:
                l10n?.learningSelectAsrPolicyOfflineDesc ??
                    'With local ASR, speaking evaluation can continue offline.',
            syncNowLabel: l10n?.learningSelectAsrSyncNow ?? 'Sync Now',
            pendingSyncLabelBuilder: (count) =>
                l10n?.learningSelectAsrPendingSync(count) ??
                '$count offline results pending sync.',
            noPendingSyncLabel: l10n?.learningSelectAsrNoPendingSync ??
                'No pending offline sync.',
            policy: asrPolicy,
            pendingSyncCount: syncState.pendingCount,
            onServerOnlySelected: () {
              ref.read(asrPolicyProvider.notifier).chooseServerOnly();
            },
            onHybridSelected: () {
              ref.read(asrPolicyProvider.notifier).chooseHybridWithOnDevice();
              ref.read(speakingFallbackSyncWorkerProvider.notifier).syncNow();
            },
            onSyncPressed: () {
              ref.read(speakingFallbackSyncWorkerProvider.notifier).syncNow();
            },
          ),
          const SizedBox(height: 24),
          AppSectionCard(
            title: l10n?.categoryLabel ?? 'Category',
            child: _ChoiceChipRow<LearningCategory>(
              values: LearningCategory.values,
              selected: selection.category,
              labelBuilder: (value) => _categoryLabel(value, l10n),
              onSelected: (value) {
                selectionController.selectCategory(value);
                ref.read(startStudySessionControllerProvider.notifier).clearError();
              },
            ),
          ),
          const SizedBox(height: 16),
          AppSectionCard(
            title: l10n?.levelLabel ?? 'Level',
            child: _ChoiceChipRow<LearningLevel>(
              values: LearningLevel.values,
              selected: selection.level,
              labelBuilder: (value) => _levelLabel(value, l10n),
              onSelected: (value) {
                selectionController.selectLevel(value);
                ref.read(startStudySessionControllerProvider.notifier).clearError();
              },
            ),
          ),
          const SizedBox(height: 16),
          AppSectionCard(
            title: l10n?.modeLabel ?? 'Mode',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ChoiceChipRow<LearningMode>(
                  values: LearningMode.values,
                  selected: selection.mode,
                  labelBuilder: (value) => _modeLabel(value, l10n),
                  onSelected: (value) {
                    selectionController.selectMode(value);
                    ref.read(startStudySessionControllerProvider.notifier).clearError();
                  },
                ),
                const SizedBox(height: 12),
                AppStatusBanner(message: _modeDescription(selection.mode, l10n)),
              ],
            ),
          ),
          if (activeSession != null) ...[
            const SizedBox(height: 16),
            _ActiveSessionCard(
              title: l10n?.learningSelectActiveSessionTitle ??
                  'There is an active learning session.',
              activeSession: activeSession,
              l10n: l10n,
              onResume: () => context.go(routeForLearningMode(activeSession.mode)),
              onClear: () => _startSession(context, ref, selection, forceReplace: true),
              resumeLabel: l10n?.resumeSession ?? 'Resume Session',
              clearLabel: l10n?.learningSelectStartNewButton ?? 'Start New',
            ),
          ],
          if (startError != null) ...[
            const SizedBox(height: 16),
            AppStatusBanner(
              isError: true,
              icon: Icons.error_outline,
              message: '${l10n?.failedToStartSession ?? 'Failed to start session.'}\n$startError',
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () =>
                    ref.read(startStudySessionControllerProvider.notifier).clearError(),
                icon: const Icon(Icons.refresh),
                label: Text(l10n?.dismissError ?? 'Dismiss Error'),
              ),
            ),
          ],
        ],
      ),
      bottomNavigationBar: AppBottomActionBar(
        secondaryLabel: l10n?.menuGuide ?? 'Learning Guide',
        onSecondaryPressed: () => context.go('/guide'),
        primaryLabel: isStarting
            ? (l10n?.learningSelectStarting ?? 'Starting session...')
            : (l10n?.startSession ?? 'Start Session'),
        onPrimaryPressed:
            selection.canProceed && !isStarting ? () => _startSession(context, ref, selection) : null,
      ),
    );
  }

  void _onMenuSelected(
    _SelectMenuAction value,
    BuildContext context,
    WidgetRef ref,
  ) {
    switch (value) {
      case _SelectMenuAction.guide:
        context.go('/guide');
        return;
      case _SelectMenuAction.resume:
        context.go('/resume');
        return;
      case _SelectMenuAction.signOut:
        ref.read(authControllerProvider.notifier).signOut();
        return;
    }
  }

  Future<void> _startSession(
    BuildContext context,
    WidgetRef ref,
    LearningSelectionState selection, {
    bool forceReplace = false,
  }) async {
    final l10n = AppLocalizations.of(context);
    try {
      final activeSession = ref.read(currentStudySessionProvider);
      if (activeSession != null) {
        var shouldReplace = forceReplace;
        if (!forceReplace) {
          shouldReplace = await showDialog<bool>(
                context: context,
                builder: (dialogContext) => AlertDialog(
                  title: Text(
                    l10n?.learningSelectConfirmStartNewTitle ??
                        'Start a new learning session?',
                  ),
                  content: Text(
                    l10n?.learningSelectConfirmStartNewMessage ??
                        'Current session will be abandoned. If you want to continue it, cancel and tap resume.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(false),
                      child: Text(l10n?.learningSelectConfirmCancel ?? 'Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.of(dialogContext).pop(true),
                      child: Text(
                        l10n?.learningSelectConfirmStartNew ?? 'Start New',
                      ),
                    ),
                  ],
                ),
              ) ??
              false;
        }
        if (!shouldReplace) {
          return;
        }

        final user = ref.read(authStateChangesProvider).asData?.value;
        final developmentSession = ref.read(developmentSessionProvider);
        if (user != null && !user.isAnonymous && !developmentSession) {
          await ref.read(sessionRuntimeRepositoryProvider).abandonStudySession(
                userId: user.uid,
                sessionId: activeSession.sessionId,
              );
        }
        ref.read(currentStudySessionProvider.notifier).clear();
        ref.read(studyFlowControllerProvider.notifier).clear();
      }

      await ref.read(startStudySessionControllerProvider.notifier).start();
      final route = routeForLearningMode(
        ref.read(currentStudySessionProvider)?.mode ?? selection.mode!,
      );
      if (context.mounted) {
        context.go(route);
      }
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(toUserFacingErrorMessage(error))));
    }
  }
}

enum _SelectMenuAction { guide, resume, signOut }

class _QuickActionRow extends StatelessWidget {
  const _QuickActionRow({required this.guideLabel, required this.resumeLabel});

  final String guideLabel;
  final String resumeLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => context.go('/guide'),
            icon: const Icon(Icons.menu_book_outlined),
            label: Text(guideLabel),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => context.go('/resume'),
            icon: const Icon(Icons.history_outlined),
            label: Text(resumeLabel),
          ),
        ),
      ],
    );
  }
}

class _SelectionSummaryCard extends StatelessWidget {
  const _SelectionSummaryCard({required this.summaryText});

  final String summaryText;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.route_outlined,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                summaryText,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActiveSessionCard extends StatelessWidget {
  const _ActiveSessionCard({
    required this.title,
    required this.activeSession,
    required this.l10n,
    required this.onResume,
    required this.onClear,
    required this.resumeLabel,
    required this.clearLabel,
  });

  final String title;
  final CurrentStudySession activeSession;
  final AppLocalizations? l10n;
  final VoidCallback onResume;
  final VoidCallback onClear;
  final String resumeLabel;
  final String clearLabel;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              '${_categoryLabel(activeSession.category, l10n)} - ${_levelLabel(activeSession.level, l10n)} - ${_modeLabel(activeSession.mode, l10n)}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onResume,
                    child: Text(resumeLabel),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextButton(
                    onPressed: onClear,
                    child: Text(clearLabel),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AsrPolicyCard extends StatelessWidget {
  const _AsrPolicyCard({
    required this.title,
    required this.intro,
    required this.serverOnlyLabel,
    required this.offlineLabel,
    required this.serverOnlyDescription,
    required this.offlineDescription,
    required this.syncNowLabel,
    required this.pendingSyncLabelBuilder,
    required this.noPendingSyncLabel,
    required this.policy,
    required this.pendingSyncCount,
    required this.onServerOnlySelected,
    required this.onHybridSelected,
    required this.onSyncPressed,
  });

  final String title;
  final String intro;
  final String serverOnlyLabel;
  final String offlineLabel;
  final String serverOnlyDescription;
  final String offlineDescription;
  final String syncNowLabel;
  final String Function(int count) pendingSyncLabelBuilder;
  final String noPendingSyncLabel;

  final AsrPolicyState policy;
  final int pendingSyncCount;
  final VoidCallback onServerOnlySelected;
  final VoidCallback onHybridSelected;
  final VoidCallback onSyncPressed;

  @override
  Widget build(BuildContext context) {
    return AppSectionCard(
      title: title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!policy.decided) ...[
            AppStatusBanner(
              icon: Icons.info_outline,
              message: intro,
            ),
            const SizedBox(height: 10),
          ],
          SegmentedButton<AsrPolicyMode>(
            segments: [
              ButtonSegment<AsrPolicyMode>(
                value: AsrPolicyMode.serverOnly,
                label: Text(serverOnlyLabel),
                icon: const Icon(Icons.cloud_outlined),
              ),
              ButtonSegment<AsrPolicyMode>(
                value: AsrPolicyMode.hybridWithOnDevice,
                label: Text(offlineLabel),
                icon: const Icon(Icons.offline_bolt_outlined),
              ),
            ],
            selected: {policy.mode},
            onSelectionChanged: (selection) {
              final selected = selection.first;
              if (selected == AsrPolicyMode.hybridWithOnDevice) {
                onHybridSelected();
                return;
              }
              onServerOnlySelected();
            },
          ),
          const SizedBox(height: 8),
          Text(
            policy.mode == AsrPolicyMode.serverOnly
                ? serverOnlyDescription
                : offlineDescription,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  pendingSyncCount > 0
                      ? pendingSyncLabelBuilder(pendingSyncCount)
                      : noPendingSyncLabel,
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: onSyncPressed,
                icon: const Icon(Icons.sync),
                label: Text(syncNowLabel),
              ),
            ],
          ),
        ],
      ),
    );
  }
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

String _selectionSummary(LearningSelectionState selection, AppLocalizations? l10n) {
  final unselected = l10n?.learningSelectUnselected ?? 'Not selected';
  final category =
      selection.category != null ? _categoryLabel(selection.category!, l10n) : unselected;
  final level = selection.level != null ? _levelLabel(selection.level!, l10n) : unselected;
  final mode = selection.mode != null ? _modeLabel(selection.mode!, l10n) : unselected;
  return l10n?.learningSelectSelectionSummary(category, level, mode) ??
      'Current selection: category $category / level $level / mode $mode';
}

String _modeDescription(LearningMode? mode, AppLocalizations? l10n) =>
    switch (mode) {
      LearningMode.sentenceLearning =>
        l10n?.learningSelectModeDescSentenceLearning ??
            'Study sentence with pronunciation and hints step by step.',
      LearningMode.sentenceTest =>
        l10n?.learningSelectModeDescSentenceTest ??
            'Validate sentence understanding via choice and speaking.',
      LearningMode.flashWordLearning =>
        l10n?.learningSelectModeDescFlashWordLearning ??
            'Memorize core words quickly with flash repetition.',
      LearningMode.flashWordTest =>
        l10n?.learningSelectModeDescFlashWordTest ??
            'Check word memory quickly with short tests.',
      LearningMode.flashSentenceLearning =>
        l10n?.learningSelectModeDescFlashSentenceLearning ??
            'Practice sentences with high-tempo flash cards.',
      LearningMode.flashSentenceTest =>
        l10n?.learningSelectModeDescFlashSentenceTest ??
            'Validate sentence comprehension and speaking in quick cycles.',
      null => l10n?.learningSelectModeDescNone ?? 'Select a mode to see guidance.',
    };

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
