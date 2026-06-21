import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mission_app/l10n/app_localizations.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/errors/app_error_messages.dart';
import '../../../../core/firebase/firebase_providers.dart';
import '../../../../core/services/asr_policy_controller.dart';
import '../../../../core/widgets/app_bottom_action_bar.dart';
import '../../../../core/widgets/app_section_card.dart';
import '../../../../core/widgets/app_status_banner.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../bootstrap/presentation/controllers/bootstrap_controller.dart';
import '../../../sentence_learning/presentation/controllers/current_study_session_controller.dart';
import '../../../session_runtime/presentation/controllers/study_flow_controller.dart';
import '../../../session_runtime/presentation/providers/session_runtime_providers.dart';
import '../../domain/study_mode_route_resolver.dart';
import '../controllers/learning_selection_controller.dart';
import '../controllers/start_study_session_controller.dart';

final _startActionChoiceProvider =
    NotifierProvider<_StartActionChoiceController, _StartActionChoice>(
      _StartActionChoiceController.new,
    );

class LearningSelectScreen extends ConsumerWidget {
  const LearningSelectScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final selection = ref.watch(learningSelectionProvider);
    final selectionController = ref.read(learningSelectionProvider.notifier);
    final activeSession = ref.watch(currentStudySessionProvider);
    final startActionChoice = ref.watch(_startActionChoiceProvider);
    final asrPolicy = ref.watch(asrPolicyProvider);
    final syncState = ref.watch(speakingFallbackSyncWorkerProvider);
    final startState = ref.watch(startStudySessionControllerProvider);
    final bootstrapSession = ref
        .watch(bootstrapControllerProvider)
        .asData
        ?.value;
    final currentUser = ref.watch(authStateChangesProvider).asData?.value;
    final debugAdminOverride =
        kDebugMode &&
        currentUser?.email?.trim().toLowerCase() == 'xhpark65@gmail.com';
    final isAdmin = bootstrapSession?.isAdmin == true || debugAdminOverride;
    final isStarting = startState.isLoading;
    final startError = startState.whenOrNull(
      error: (error, _) => toUserFacingErrorMessage(error),
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          return;
        }
        _returnToLogin(context, ref);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n?.learningSelectTitle ?? '학습 선택'),
          actions: [
            PopupMenuButton<_SelectMenuAction>(
              icon: const Icon(Icons.settings_outlined),
              onSelected: (value) => _onMenuSelected(value, context, ref),
              itemBuilder: (_) => [
                if (isAdmin)
                  const PopupMenuItem(
                    value: _SelectMenuAction.adminDashboard,
                    child: Text('관리자 대시보드'),
                  ),
                const PopupMenuItem(
                  value: _SelectMenuAction.myHistory,
                  child: Text('내 학습 기록'),
                ),
                PopupMenuItem(
                  value: _SelectMenuAction.guide,
                  child: Text(l10n?.menuGuide ?? '학습 가이드'),
                ),
                PopupMenuItem(
                  value: _SelectMenuAction.resume,
                  child: Text(l10n?.menuResume ?? '이어하기'),
                ),
                PopupMenuItem(
                  value: _SelectMenuAction.signOut,
                  child: Text(l10n?.menuSignOut ?? '로그아웃'),
                ),
              ],
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          children: [
            if (isAdmin) ...[
              AppSectionCard(
                title: '관리자 메뉴',
                description: '학습자 승인, 리포트 현황, 일간/주간 학습 통계를 확인할 수 있습니다.',
                icon: Icons.admin_panel_settings_outlined,
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.icon(
                    onPressed: () => context.go('/admin-dashboard'),
                    icon: const Icon(Icons.dashboard_outlined),
                    label: const Text('관리자 대시보드 열기'),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: AppSectionCard(
                    title: l10n?.categoryLabel ?? '학습 선택',
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                    child: _ChoiceChipRow<LearningCategory>(
                      values: LearningCategory.values,
                      selected: selection.category,
                      labelBuilder: (value) => _categoryLabel(value, l10n),
                      onSelected: (value) {
                        selectionController.selectCategory(value);
                        ref
                            .read(startStudySessionControllerProvider.notifier)
                            .clearError();
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: AppSectionCard(
                    title: l10n?.levelLabel ?? '난이도 선택',
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                    child: _ChoiceChipRow<LearningLevel>(
                      values: LearningLevel.values,
                      selected: selection.level,
                      labelBuilder: (value) => _levelLabel(value, l10n),
                      onSelected: (value) {
                        selectionController.selectLevel(value);
                        ref
                            .read(startStudySessionControllerProvider.notifier)
                            .clearError();
                      },
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            AppSectionCard(
              title: l10n?.modeLabel ?? '학습모드 선택',
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: _ChoiceChipRow<LearningMode>(
                values: LearningMode.values,
                selected: selection.mode,
                labelBuilder: (value) => _modeLabel(value, l10n),
                onSelected: (value) {
                  selectionController.selectMode(value);
                  ref
                      .read(startStudySessionControllerProvider.notifier)
                      .clearError();
                },
              ),
            ),
            const SizedBox(height: 8),
            _StartActionChoiceCard(
              title: '시작 방식 선택',
              selected: startActionChoice,
              resumeLabel: l10n?.resumeSession ?? '이어 학습',
              startNewLabel: l10n?.learningSelectStartNewButton ?? '새 학습 시작',
              onSelected: (value) =>
                  ref.read(_startActionChoiceProvider.notifier).select(value),
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 6,
                  child: _AsrPolicyCard(
                    title: l10n?.learningSelectAsrPolicyTitle ?? '음성 인식 선택',
                    serverFirstLabel:
                        l10n?.learningSelectAsrPolicyServerOnly ?? '서버 우선 인식',
                    offlineLabel: '폰\n전용\n인식',
                    policy: asrPolicy,
                    onServerFirstSelected: () {
                      ref.read(asrPolicyProvider.notifier).chooseServerFirst();
                    },
                    onOnDeviceOnlySelected: () {
                      ref.read(asrPolicyProvider.notifier).chooseOnDeviceOnly();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 4,
                  child: _SyncStatusCard(
                    title: '동기화',
                    syncNowLabel: l10n?.learningSelectAsrSyncNow ?? '동기화',
                    pendingSyncLabelBuilder: (count) =>
                        l10n?.learningSelectAsrPendingSync(count) ??
                        '오프라인 동기화 대기 항목 $count건',
                    noPendingSyncLabel:
                        l10n?.learningSelectAsrNoPendingSync ?? '항목 없음',
                    pendingSyncCount: syncState.pendingCount,
                    onSyncPressed: () {
                      ref
                          .read(speakingFallbackSyncWorkerProvider.notifier)
                          .syncNow();
                    },
                  ),
                ),
              ],
            ),
            if (startError != null) ...[
              const SizedBox(height: 8),
              AppStatusBanner(
                isError: true,
                icon: Icons.error_outline,
                message:
                    '${l10n?.failedToStartSession ?? '학습 세션 시작에 실패했습니다.'}\n$startError',
              ),
            ],
          ],
        ),
        bottomNavigationBar: AppBottomActionBar(
          secondaryLabel: null,
          onSecondaryPressed: null,
          primaryLabel: isStarting
              ? (l10n?.learningSelectStarting ?? '세션 시작 중...')
              : (l10n?.startSession ?? '학습 시작'),
          primaryMinHeight: 66,
          primaryTextStyle: Theme.of(context).textTheme.headlineMedium
              ?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.3),
          primaryBackgroundColor: AppColors.primary.withValues(alpha: 0.78),
          primaryForegroundColor: Colors.white,
          primaryIcon: Icons.play_arrow_rounded,
          onPrimaryPressed: !isStarting && selection.canProceed
              ? () => _onPrimaryStart(
                  context,
                  ref,
                  selection,
                  startActionChoice,
                  activeSession,
                )
              : null,
        ),
      ),
    );
  }

  void _onMenuSelected(
    _SelectMenuAction value,
    BuildContext context,
    WidgetRef ref,
  ) {
    switch (value) {
      case _SelectMenuAction.adminDashboard:
        context.go('/admin-dashboard');
      case _SelectMenuAction.myHistory:
        context.go('/my-history');
      case _SelectMenuAction.guide:
        context.go('/guide');
      case _SelectMenuAction.resume:
        context.go('/resume');
      case _SelectMenuAction.signOut:
        _returnToLogin(context, ref);
    }
  }

  Future<void> _returnToLogin(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(authControllerProvider.notifier).signOut();
      if (context.mounted) {
        context.go('/login');
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

  Future<void> _onPrimaryStart(
    BuildContext context,
    WidgetRef ref,
    LearningSelectionState selection,
    _StartActionChoice startActionChoice,
    CurrentStudySession? activeSession,
  ) async {
    if (startActionChoice == _StartActionChoice.resume &&
        activeSession != null) {
      context.go(routeForLearningMode(activeSession.mode));
      return;
    }

    await _startSession(
      context,
      ref,
      selection,
      forceReplace: startActionChoice == _StartActionChoice.startNew,
    );
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
          shouldReplace =
              await showDialog<bool>(
                context: context,
                builder: (dialogContext) => AlertDialog(
                  title: Text(
                    l10n?.learningSelectConfirmStartNewTitle ??
                        '새 학습 세션을 시작할까요?',
                  ),
                  content: Text(
                    l10n?.learningSelectConfirmStartNewMessage ??
                        '현재 세션은 포기 처리됩니다. 이어서 학습하려면 취소 후 이어하기를 누르세요.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(false),
                      child: Text(l10n?.learningSelectConfirmCancel ?? '취소'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.of(dialogContext).pop(true),
                      child: Text(
                        l10n?.learningSelectConfirmStartNew ?? '새로 시작',
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
          await ref
              .read(sessionRuntimeRepositoryProvider)
              .abandonStudySession(
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

enum _SelectMenuAction { adminDashboard, myHistory, guide, resume, signOut }

enum _StartActionChoice { resume, startNew }

class _StartActionChoiceController extends Notifier<_StartActionChoice> {
  @override
  _StartActionChoice build() => _StartActionChoice.resume;

  void select(_StartActionChoice value) => state = value;
}

class _AsrPolicyCard extends StatelessWidget {
  const _AsrPolicyCard({
    required this.title,
    required this.serverFirstLabel,
    required this.offlineLabel,
    required this.policy,
    required this.onServerFirstSelected,
    required this.onOnDeviceOnlySelected,
  });

  final String title;
  final String serverFirstLabel;
  final String offlineLabel;
  final AsrPolicyState policy;
  final VoidCallback onServerFirstSelected;
  final VoidCallback onOnDeviceOnlySelected;

  @override
  Widget build(BuildContext context) {
    final segmentTextStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
      fontWeight: FontWeight.w800,
      height: 1.12,
      letterSpacing: -0.4,
    );

    return AppSectionCard(
      title: title,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: SegmentedButton<AsrPolicyMode>(
        segments: [
          ButtonSegment<AsrPolicyMode>(
            value: AsrPolicyMode.serverFirst,
            label: Text(
              serverFirstLabel.replaceAll(' ', '\n'),
              textAlign: TextAlign.center,
              style: segmentTextStyle,
            ),
          ),
          ButtonSegment<AsrPolicyMode>(
            value: AsrPolicyMode.onDeviceOnly,
            label: Text(
              offlineLabel,
              textAlign: TextAlign.center,
              style: segmentTextStyle,
            ),
          ),
        ],
        selected: {policy.mode},
        onSelectionChanged: (selection) {
          final selected = selection.first;
          if (selected == AsrPolicyMode.onDeviceOnly) {
            onOnDeviceOnlySelected();
          } else {
            onServerFirstSelected();
          }
        },
      ),
    );
  }
}

class _SyncStatusCard extends StatelessWidget {
  const _SyncStatusCard({
    required this.title,
    required this.syncNowLabel,
    required this.pendingSyncLabelBuilder,
    required this.noPendingSyncLabel,
    required this.pendingSyncCount,
    required this.onSyncPressed,
  });

  final String title;
  final String syncNowLabel;
  final String Function(int count) pendingSyncLabelBuilder;
  final String noPendingSyncLabel;
  final int pendingSyncCount;
  final VoidCallback onSyncPressed;

  @override
  Widget build(BuildContext context) {
    final pendingLabel = pendingSyncCount > 0
        ? pendingSyncLabelBuilder(pendingSyncCount)
        : noPendingSyncLabel;
    final canSync = pendingSyncCount > 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final titleWidget = Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
            );
            final syncButton = TextButton.icon(
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 32),
                padding: const EdgeInsets.symmetric(horizontal: 6),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
              onPressed: canSync ? onSyncPressed : null,
              icon: const Icon(Icons.sync, size: 15),
              label: Text(
                syncNowLabel,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            );

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(child: titleWidget),
                    Flexible(child: syncButton),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  pendingLabel,
                  style: Theme.of(context).textTheme.bodyMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _StartActionChoiceCard extends StatelessWidget {
  const _StartActionChoiceCard({
    required this.title,
    required this.selected,
    required this.resumeLabel,
    required this.startNewLabel,
    required this.onSelected,
  });

  final String title;
  final _StartActionChoice selected;
  final String resumeLabel;
  final String startNewLabel;
  final ValueChanged<_StartActionChoice> onSelected;

  @override
  Widget build(BuildContext context) {
    return AppSectionCard(
      title: title,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: SegmentedButton<_StartActionChoice>(
        segments: [
          ButtonSegment<_StartActionChoice>(
            value: _StartActionChoice.resume,
            icon: const Icon(Icons.history_outlined, size: 20),
            label: Text(resumeLabel),
          ),
          ButtonSegment<_StartActionChoice>(
            value: _StartActionChoice.startNew,
            icon: const Icon(Icons.play_arrow_rounded, size: 20),
            label: Text(startNewLabel),
          ),
        ],
        selected: {selected},
        onSelectionChanged: (selection) => onSelected(selection.first),
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
    final labelStyle = Theme.of(context).textTheme.bodyLarge?.copyWith(
      fontWeight: FontWeight.w800,
      letterSpacing: -0.2,
    );

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: values.map((value) {
        final isSelected = value == selected;
        return ChoiceChip(
          label: Text(labelBuilder(value)),
          selected: isSelected,
          onSelected: (_) => onSelected(value),
          backgroundColor: AppColors.surface,
          selectedColor: AppColors.primary,
          checkmarkColor: Colors.white,
          side: BorderSide(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: 1.4,
          ),
          labelStyle: labelStyle?.copyWith(
            color: isSelected ? Colors.white : AppColors.textStrong,
          ),
        );
      }).toList(),
    );
  }
}

String _categoryLabel(LearningCategory category, AppLocalizations? l10n) =>
    switch (category) {
      LearningCategory.daily => l10n?.learningSelectCategoryDaily ?? '일상 회화',
      LearningCategory.mission => l10n?.learningSelectCategoryMission ?? '선교',
    };

String _levelLabel(LearningLevel level, AppLocalizations? l10n) =>
    switch (level) {
      LearningLevel.beginner => l10n?.learningSelectLevelBeginner ?? '초급',
      LearningLevel.intermediate =>
        l10n?.learningSelectLevelIntermediate ?? '중급',
      LearningLevel.advanced => l10n?.learningSelectLevelAdvanced ?? '고급',
    };

String _modeLabel(LearningMode mode, AppLocalizations? l10n) => switch (mode) {
  LearningMode.sentenceLearning =>
    l10n?.learningSelectModeSentenceLearning ?? '문장 학습',
  LearningMode.sentenceTest => l10n?.learningSelectModeSentenceTest ?? '문장 테스트',
  LearningMode.flashWordLearning =>
    l10n?.learningSelectModeFlashWordLearning ?? '플래시 단어 학습',
  LearningMode.flashWordTest =>
    l10n?.learningSelectModeFlashWordTest ?? '플래시 단어 테스트',
  LearningMode.flashSentenceLearning =>
    l10n?.learningSelectModeFlashSentenceLearning ?? '플래시 문장 학습',
  LearningMode.flashSentenceTest =>
    l10n?.learningSelectModeFlashSentenceTest ?? '플래시 문장 테스트',
};
