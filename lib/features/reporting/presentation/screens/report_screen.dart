import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/firebase/firebase_providers.dart';
import '../../../../core/firebase/firebase_services.dart';
import '../../../../core/widgets/app_bottom_action_bar.dart';
import '../../../../core/widgets/app_section_card.dart';
import '../../../../core/widgets/app_status_banner.dart';
import '../../../learning_select/domain/study_mode_route_resolver.dart';
import '../../../learning_select/presentation/controllers/learning_selection_controller.dart';
import '../../domain/report_metrics.dart';
import '../../../sentence_learning/presentation/controllers/current_study_session_controller.dart';
import '../../../session_runtime/presentation/controllers/study_flow_controller.dart';
import '../../../session_runtime/presentation/providers/session_runtime_providers.dart';
import '../controllers/report_requirement_controller.dart';

class ReportScreen extends ConsumerStatefulWidget {
  const ReportScreen({super.key});

  @override
  ConsumerState<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends ConsumerState<ReportScreen> {
  bool _submitted = false;
  bool _submitting = false;
  String? _testSelectRouteAfterSubmit;

  Future<void> _submitReport() async {
    final user = ref.read(authStateChangesProvider).asData?.value;
    final developmentSession = ref.read(developmentSessionProvider);
    final session = ref.read(currentStudySessionProvider);
    final flow = ref.read(studyFlowControllerProvider);

    if (session == null) {
      throw StateError('보고서를 제출하려면 진행 중인 세션이 필요합니다.');
    }
    if (user == null || developmentSession || user.isAnonymous) {
      throw StateError('보고서는 인증 계정에서만 제출할 수 있습니다.');
    }

    final completedAt = DateTime.now();
    final startedAt = DateTime.tryParse(session.startedAt);
    final durationSeconds = startedAt == null
        ? 0
        : completedAt.difference(startedAt).inSeconds.clamp(0, 1 << 31);
    final metrics = buildReportMetrics(flow);
    final callable = ref
        .read(firebaseFunctionsProvider)
        .httpsCallable('completeReportSubmission');
    await callable.call(<String, dynamic>{
      'userId': user.uid,
      'sessionId': session.sessionId,
      'completedItems': flow.completedItems,
      'assessmentApplicable': metrics.hasAssessment,
      'correctAnswers': metrics.hasAssessment ? flow.correctAnswers : null,
      'attemptedAnswers': metrics.hasAssessment ? flow.attemptedAnswers : null,
      'averageSimilarity': metrics.hasSpeaking
          ? metrics.averageSimilarity
          : null,
      'completedAt': completedAt.toIso8601String(),
      'durationSeconds': durationSeconds,
    });
    await ref
        .read(sessionRuntimeRepositoryProvider)
        .discardResumeState(userId: user.uid, sessionId: session.sessionId);

    final testSelectRoute = testSelectRouteForMode(session.mode);

    ref.read(reportRequirementProvider.notifier).markSubmitted();
    ref.read(currentStudySessionProvider.notifier).clear();
    ref.read(studyFlowControllerProvider.notifier).clear();
    setState(() {
      _submitted = true;
      _testSelectRouteAfterSubmit = testSelectRoute;
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(currentStudySessionProvider);
    final flow = ref.watch(studyFlowControllerProvider);
    final authUser = ref.watch(authStateChangesProvider).asData?.value;
    final developmentSession = ref.watch(developmentSessionProvider);

    final hasSession = session != null;
    final metrics = buildReportMetrics(flow);
    final completedAt = DateTime.now();
    final startedAt = session == null
        ? null
        : DateTime.tryParse(session.startedAt);
    final durationSeconds = startedAt == null
        ? 0
        : completedAt.difference(startedAt).inSeconds.clamp(0, 1 << 31);
    final completionRate = _percentValue(flow.completedItems, flow.totalItems);
    final canUseBackendSubmit =
        authUser != null && !authUser.isAnonymous && !developmentSession;
    final canSubmit =
        hasSession && canUseBackendSubmit && !_submitted && !_submitting;

    return Scaffold(
      appBar: AppBar(title: const Text('학습 리포트')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          if (!hasSession) ...[
            const AppStatusBanner(
              isError: true,
              icon: Icons.warning_amber_rounded,
              message: '진행 중인 학습 세션이 없어 리포트를 제출할 수 없습니다.',
            ),
            const SizedBox(height: 12),
          ],
          if (!canUseBackendSubmit) ...[
            const AppStatusBanner(
              isError: true,
              icon: Icons.lock_outline,
              message: '리포트 제출은 인증 계정에서만 가능합니다.',
            ),
            const SizedBox(height: 12),
          ],
          AppSectionCard(
            title: '관리자 제출 항목',
            description:
                '학습 여부, 학습량, 진도, 정답률, 말하기 유사도, 이전 대비 향상도 산출에 필요한 항목을 서버에 제출합니다.',
            icon: Icons.analytics_outlined,
            child: Column(
              children: [
                _ReportStatRow(
                  label: '세션 ID',
                  value: session?.sessionId ?? '-',
                ),
                _ReportStatRow(
                  label: '콘텐츠 세트',
                  value: session?.contentSetId ?? '-',
                ),
                _ReportStatRow(
                  label: '학습 구분',
                  value: session == null
                      ? '-'
                      : '${_categoryLabel(session.category)} / ${_levelLabel(session.level)} / ${_modeLabel(session.mode)}',
                ),
                _ReportStatRow(
                  label: '학습 완료 항목',
                  value: '${flow.completedItems} / ${flow.totalItems}',
                ),
                _ReportStatRow(
                  label: '학습 진도율',
                  value: _percentText(completionRate),
                ),
                _ReportStatRow(
                  label: '응답 항목',
                  value: metrics.hasAssessment
                      ? '${flow.attemptedAnswers} / ${flow.totalItems}'
                      : '해당 없음',
                ),
                _ReportStatRow(
                  label: '응답률',
                  value: metrics.hasAssessment
                      ? _percentText(metrics.answerRate)
                      : '해당 없음',
                ),
                _ReportStatRow(
                  label: '정답 수',
                  value: metrics.hasAssessment
                      ? '${flow.correctAnswers} / ${flow.attemptedAnswers}'
                      : '해당 없음',
                ),
                _ReportStatRow(
                  label: '오답 수',
                  value: metrics.hasAssessment
                      ? '${metrics.missedAnswers}'
                      : '해당 없음',
                ),
                _ReportStatRow(
                  label: '정답률',
                  value: metrics.hasAssessment
                      ? _percentText(metrics.accuracy)
                      : '해당 없음',
                ),
                _ReportStatRow(
                  label: '말하기 유사도 평균',
                  value: metrics.hasSpeaking
                      ? '${metrics.averageSimilarity}%'
                      : '해당 없음',
                ),
                _ReportStatRow(
                  label: '학습 시작 시각',
                  value: startedAt == null ? '-' : _formatDateTime(startedAt),
                ),
                _ReportStatRow(
                  label: '리포트 제출 시각',
                  value: hasSession ? _formatDateTime(completedAt) : '-',
                ),
                _ReportStatRow(
                  label: '학습 소요 시간',
                  value: hasSession ? _formatDuration(durationSeconds) : '-',
                ),
              ],
            ),
          ),
          if (_submitted) ...[
            const SizedBox(height: 16),
            const AppStatusBanner(
              icon: Icons.check_circle_outline,
              message: '리포트를 제출했습니다. 다음 학습을 시작할 수 있습니다.',
            ),
          ],
        ],
      ),
      bottomNavigationBar: AppBottomActionBar(
        secondaryLabel: _submitted ? '학습 선택으로 이동' : '요약으로 돌아가기',
        onSecondaryPressed: () => context.go(_submitted ? '/select' : '/session-summary'),
        tertiaryLabel: _submitted && _testSelectRouteAfterSubmit != null
            ? '다른 테스트 선택'
            : null,
        onTertiaryPressed: _submitted && _testSelectRouteAfterSubmit != null
            ? () => context.go(_testSelectRouteAfterSubmit!)
            : null,
        primaryLabel: _submitted
            ? '제출 완료'
            : (_submitting ? '리포트 제출 중...' : '리포트 제출'),
        onPrimaryPressed: canSubmit
            ? () async {
                setState(() => _submitting = true);
                try {
                  await _submitReport();
                } catch (_) {
                  if (!context.mounted) {
                    return;
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('리포트 제출에 실패했습니다. 잠시 후 다시 시도해 주세요.'),
                    ),
                  );
                } finally {
                  if (mounted) {
                    setState(() => _submitting = false);
                  }
                }
              }
            : null,
      ),
    );
  }
}

class _ReportStatRow extends StatelessWidget {
  const _ReportStatRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 520;
          if (isCompact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: textTheme.bodyMedium),
                const SizedBox(height: 6),
                SelectableText(
                  value,
                  style: textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 150,
                child: Text(label, style: textTheme.bodyMedium),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SelectableText(
                  value,
                  style: textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

int? _percentValue(int numerator, int denominator) {
  if (denominator <= 0) {
    return null;
  }
  return ((numerator / denominator) * 100).round();
}

String _percentText(int? value) => value == null ? '-' : '$value%';

String _formatDuration(int seconds) {
  final minutes = seconds ~/ 60;
  final remainingSeconds = seconds % 60;
  if (minutes <= 0) {
    return '$remainingSeconds초';
  }
  return '$minutes분 $remainingSeconds초';
}

String _formatDateTime(DateTime value) {
  final local = value.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}:${two(local.second)}';
}

String _categoryLabel(LearningCategory category) => switch (category) {
  LearningCategory.daily => '일상 회화',
  LearningCategory.mission => '선교',
};

String _levelLabel(LearningLevel level) => switch (level) {
  LearningLevel.beginner => '초급',
  LearningLevel.intermediate => '중급',
  LearningLevel.advanced => '고급',
};

String _modeLabel(LearningMode mode) => switch (mode) {
  LearningMode.sentenceLearning => '문장 학습',
  LearningMode.sentenceTest => '문장 테스트',
  LearningMode.flashWordLearning => '플래시 단어 학습',
  LearningMode.flashWordTest => '플래시 단어 테스트',
  LearningMode.flashSentenceLearning => '플래시 문장 학습',
  LearningMode.flashSentenceTest => '플래시 문장 테스트',
};
