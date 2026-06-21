import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/firebase/firebase_providers.dart';
import '../../../../core/firebase/firebase_services.dart';
import '../../../../core/widgets/app_section_card.dart';
import '../../../../core/widgets/app_status_banner.dart';

enum _DashboardDetail {
  today,
  week,
  pendingApprovals,
  allLearners,
  topLearners,
  needsAttention,
  recentReports,
  accuracy,
  speaking,
}

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() =>
      _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  Future<_AdminDashboardData>? _future;
  _DashboardDetail _selectedDetail = _DashboardDetail.today;
  String? _actionMessage;
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _detailPanelKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _future = _loadDashboard();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<_AdminDashboardData> _loadDashboard() async {
    final user = ref.read(authStateChangesProvider).asData?.value;
    final developmentSession = ref.read(developmentSessionProvider);
    if (user == null || user.isAnonymous || developmentSession) {
      throw StateError('관리자 인증 계정으로 로그인해야 합니다.');
    }

    final result = await ref
        .read(firebaseFunctionsProvider)
        .httpsCallable('getAdminDashboard')
        .call(<String, dynamic>{'adminUserId': user.uid});
    return _AdminDashboardData.fromMap(_asMap(result.data));
  }

  Future<void> _approveLearner(String targetUserId) async {
    final user = ref.read(authStateChangesProvider).asData?.value;
    if (user == null) {
      return;
    }

    await ref
        .read(firebaseFunctionsProvider)
        .httpsCallable('approveLearnerAccount')
        .call(<String, dynamic>{
          'adminUserId': user.uid,
          'targetUserId': targetUserId,
        });
    setState(() {
      _actionMessage = '학습자 승인이 완료되었습니다.';
      _future = _loadDashboard();
      _selectedDetail = _DashboardDetail.pendingApprovals;
    });
  }

  void _refresh() {
    setState(() {
      _actionMessage = null;
      _future = _loadDashboard();
    });
  }

  void _selectDetail(_DashboardDetail detail) {
    setState(() {
      _selectedDetail = detail;
    });
    // The detail panel sits below a tall list of metric tiles, so bring it into
    // view to make the tap feel responsive instead of silently updating off-screen.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = _detailPanelKey.currentContext;
      if (context != null) {
        Scrollable.ensureVisible(
          context,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          alignment: 0.05,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('관리자 대시보드'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/select'),
        ),
        actions: [
          IconButton(
            tooltip: '새로고침',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<_AdminDashboardData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                AppStatusBanner(
                  isError: true,
                  icon: Icons.admin_panel_settings_outlined,
                  message:
                      '관리자 대시보드를 불러오지 못했습니다. 관리자 권한 또는 서버 로그를 확인해 주세요.\n${snapshot.error}',
                ),
              ],
            );
          }

          final data = snapshot.requireData;
          // SingleChildScrollView + Column (not ListView) so every section is
          // eagerly built. The detail panel must always be laid out for the
          // tap-to-scroll (_selectDetail -> ensureVisible) to work even when the
          // tapped tile is at the top and the panel is far below.
          return SingleChildScrollView(
            controller: _scrollController,
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_actionMessage != null) ...[
                  AppStatusBanner(
                    icon: Icons.check_circle_outline,
                    message: _actionMessage!,
                  ),
                  const SizedBox(height: 16),
                ],
                _SummarySection(
                  data: data,
                  selectedDetail: _selectedDetail,
                  onSelect: _selectDetail,
                ),
                const SizedBox(height: 16),
                _DetailPanel(
                  key: _detailPanelKey,
                  data: data,
                  selectedDetail: _selectedDetail,
                  onApprove: _approveLearner,
                ),
                const SizedBox(height: 16),
                _LearnerStatisticsSection(
                  topLearners: data.topLearners,
                  needsAttentionLearners: data.needsAttentionLearners,
                  learnerSummaries: data.learnerSummaries,
                ),
                const SizedBox(height: 16),
                _RecentReportsSection(reports: data.recentReports),
                const SizedBox(height: 24),
                Text(
                  '생성 시각: ${data.generatedAt}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SummarySection extends StatelessWidget {
  const _SummarySection({
    required this.data,
    required this.selectedDetail,
    required this.onSelect,
  });

  final _AdminDashboardData data;
  final _DashboardDetail selectedDetail;
  final ValueChanged<_DashboardDetail> onSelect;

  @override
  Widget build(BuildContext context) {
    final summary = data.summary;
    final todayReports = data.todayReports.length;
    final todayLearners = data.todayLearnerCount;
    final weekReports = data.weekReports.length;
    final weekLearners = data.weekLearnerCount;

    return AppSectionCard(
      title: '전체 요약',
      description: '각 카드를 누르면 아래 상세 패널에서 학습자, 리포트, 주의 사유를 바로 확인할 수 있습니다.',
      icon: Icons.query_stats_outlined,
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          _MetricTile(
            label: '오늘 학습자',
            value: '$todayLearners명',
            selected: selectedDetail == _DashboardDetail.today,
            onTap: () => onSelect(_DashboardDetail.today),
          ),
          _MetricTile(
            label: '오늘 리포트',
            value: '$todayReports건',
            selected: selectedDetail == _DashboardDetail.today,
            onTap: () => onSelect(_DashboardDetail.today),
          ),
          _MetricTile(
            label: '이번 주 학습자',
            value: '$weekLearners명',
            selected: selectedDetail == _DashboardDetail.week,
            onTap: () => onSelect(_DashboardDetail.week),
          ),
          _MetricTile(
            label: '이번 주 리포트',
            value: '$weekReports건',
            selected: selectedDetail == _DashboardDetail.week,
            onTap: () => onSelect(_DashboardDetail.week),
          ),
          _MetricTile(
            label: '전체 학습자',
            value: '${summary.totalLearners}명',
            selected: selectedDetail == _DashboardDetail.allLearners,
            onTap: () => onSelect(_DashboardDetail.allLearners),
          ),
          _MetricTile(
            label: '활성 학습자',
            value: '${summary.activeLearners}명',
            selected: selectedDetail == _DashboardDetail.allLearners,
            onTap: () => onSelect(_DashboardDetail.allLearners),
          ),
          _MetricTile(
            label: '최근 7일 활동',
            value: '${summary.activeLearnersLast7Days}명',
            selected: selectedDetail == _DashboardDetail.week,
            onTap: () => onSelect(_DashboardDetail.week),
          ),
          _MetricTile(
            label: '완료 세션',
            value: '${summary.totalSessions}건',
            selected: selectedDetail == _DashboardDetail.recentReports,
            onTap: () => onSelect(_DashboardDetail.recentReports),
          ),
          _MetricTile(
            label: '완료 항목',
            value: '${summary.totalCompletedItems}개',
            selected: selectedDetail == _DashboardDetail.recentReports,
            onTap: () => onSelect(_DashboardDetail.recentReports),
          ),
          _MetricTile(
            label: '누적 학습 시간',
            value: '${summary.totalDurationMinutes}분',
            selected: selectedDetail == _DashboardDetail.recentReports,
            onTap: () => onSelect(_DashboardDetail.recentReports),
          ),
          _MetricTile(
            label: '평균 진도율',
            value: _percent(summary.averageCompletionRate),
            selected: selectedDetail == _DashboardDetail.recentReports,
            onTap: () => onSelect(_DashboardDetail.recentReports),
          ),
          _MetricTile(
            label: '평균 정답률',
            value: _percent(summary.averageAccuracy),
            selected: selectedDetail == _DashboardDetail.accuracy,
            onTap: () => onSelect(_DashboardDetail.accuracy),
          ),
          _MetricTile(
            label: '평균 말하기',
            value: _percent(summary.averageSimilarity),
            selected: selectedDetail == _DashboardDetail.speaking,
            onTap: () => onSelect(_DashboardDetail.speaking),
          ),
          _MetricTile(
            label: '승인 대기',
            value: '${summary.pendingApprovalCount}명',
            selected: selectedDetail == _DashboardDetail.pendingApprovals,
            onTap: () => onSelect(_DashboardDetail.pendingApprovals),
          ),
          _MetricTile(
            label: '우수 학습자',
            value: '${data.topLearners.length}명',
            selected: selectedDetail == _DashboardDetail.topLearners,
            onTap: () => onSelect(_DashboardDetail.topLearners),
          ),
          _MetricTile(
            label: '관리 필요',
            value: '${data.needsAttentionLearners.length}명',
            selected: selectedDetail == _DashboardDetail.needsAttention,
            onTap: () => onSelect(_DashboardDetail.needsAttention),
          ),
          _MetricTile(
            label: '최근 리포트',
            value: '${summary.recentReportCount}건',
            selected: selectedDetail == _DashboardDetail.recentReports,
            onTap: () => onSelect(_DashboardDetail.recentReports),
          ),
        ],
      ),
    );
  }
}

class _DetailPanel extends StatelessWidget {
  const _DetailPanel({
    super.key,
    required this.data,
    required this.selectedDetail,
    required this.onApprove,
  });

  final _AdminDashboardData data;
  final _DashboardDetail selectedDetail;
  final Future<void> Function(String userId) onApprove;

  @override
  Widget build(BuildContext context) {
    final title = switch (selectedDetail) {
      _DashboardDetail.today => '오늘 학습 상세',
      _DashboardDetail.week => '이번 주 학습 상세',
      _DashboardDetail.pendingApprovals => '승인 대기 상세',
      _DashboardDetail.allLearners => '전체 학습자 상세',
      _DashboardDetail.topLearners => '우수 학습자 상세',
      _DashboardDetail.needsAttention => '관리 필요 학습자 상세',
      _DashboardDetail.recentReports => '최근 리포트 상세',
      _DashboardDetail.accuracy => '정답률 상세',
      _DashboardDetail.speaking => '말하기 유사도 상세',
    };
    final description = switch (selectedDetail) {
      _DashboardDetail.today => '오늘 제출된 리포트와 오늘 활동한 학습자를 확인합니다.',
      _DashboardDetail.week => '최근 7일 제출 리포트와 주간 활동 학습자를 확인합니다.',
      _DashboardDetail.pendingApprovals => '계정 생성 후 승인 대기 중인 학습자를 처리합니다.',
      _DashboardDetail.allLearners => '학습자별 누적 세션, 학습량, 최근 학습일을 확인합니다.',
      _DashboardDetail.topLearners => '관리 점수가 높은 학습자를 확인합니다.',
      _DashboardDetail.needsAttention =>
        '참여 부족, 낮은 진도율, 낮은 정답률, 낮은 말하기 유사도 학습자를 확인합니다.',
      _DashboardDetail.recentReports => '최근 제출된 세션 리포트의 진도, 정답률, 유사도를 확인합니다.',
      _DashboardDetail.accuracy => '정답률이 낮은 순서로 학습자를 확인합니다.',
      _DashboardDetail.speaking => '말하기 유사도가 낮은 순서로 학습자를 확인합니다.',
    };

    return AppSectionCard(
      title: title,
      description: description,
      icon: Icons.manage_search_outlined,
      child: _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    return switch (selectedDetail) {
      _DashboardDetail.today => _PeriodDetail(
        reports: data.todayReports,
        learners: data.todayLearners,
        emptyText: '오늘 제출된 리포트가 없습니다.',
      ),
      _DashboardDetail.week => _PeriodDetail(
        reports: data.weekReports,
        learners: data.weekLearners,
        emptyText: '최근 7일 제출된 리포트가 없습니다.',
      ),
      _DashboardDetail.pendingApprovals => _PendingApprovalList(
        learners: data.pendingApprovals,
        onApprove: onApprove,
      ),
      _DashboardDetail.allLearners => _LearnerList(
        learners: data.learnerSummaries,
        emptyText: '아직 학습자 통계가 없습니다.',
      ),
      _DashboardDetail.topLearners => _LearnerList(
        learners: data.topLearners,
        emptyText: '아직 우수 학습자를 계산할 데이터가 없습니다.',
      ),
      _DashboardDetail.needsAttention => _LearnerList(
        learners: data.needsAttentionLearners,
        emptyText: '관리 필요 학습자가 없습니다.',
      ),
      _DashboardDetail.recentReports => _ReportList(
        reports: data.recentReports,
        emptyText: '최근 리포트가 없습니다.',
      ),
      _DashboardDetail.accuracy => _LearnerList(
        learners: data.learnersByLowAccuracy,
        emptyText: '정답률 통계가 없습니다.',
      ),
      _DashboardDetail.speaking => _LearnerList(
        learners: data.learnersByLowSimilarity,
        emptyText: '말하기 유사도 통계가 없습니다.',
      ),
    };
  }
}

class _PeriodDetail extends StatelessWidget {
  const _PeriodDetail({
    required this.reports,
    required this.learners,
    required this.emptyText,
  });

  final List<_RecentReport> reports;
  final List<_LearnerSummary> learners;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    if (reports.isEmpty && learners.isEmpty) {
      return Text(emptyText);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _InlineMetrics(
          items: [
            ('활동 학습자', '${learners.length}명'),
            ('제출 리포트', '${reports.length}건'),
            (
              '완료 항목',
              '${reports.fold<int>(0, (sum, r) => sum + r.completedItems)}개',
            ),
            (
              '학습 시간',
              '${reports.fold<int>(0, (sum, r) => sum + r.durationMinutes)}분',
            ),
            ('평균 정답률', _averagePercent(reports.map((r) => r.accuracy))),
            (
              '평균 말하기',
              _averagePercent(reports.map((r) => r.averageSimilarity)),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text('활동 학습자', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (learners.isEmpty)
          const Text('활동 학습자가 없습니다.')
        else
          _LearnerList(learners: learners, emptyText: ''),
        const SizedBox(height: 16),
        Text('제출 리포트', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        _ReportList(reports: reports, emptyText: emptyText),
      ],
    );
  }
}

class _PendingApprovalList extends StatelessWidget {
  const _PendingApprovalList({required this.learners, required this.onApprove});

  final List<_PendingApproval> learners;
  final Future<void> Function(String userId) onApprove;

  @override
  Widget build(BuildContext context) {
    if (learners.isEmpty) {
      return const Text('승인 대기 중인 학습자가 없습니다.');
    }

    return Column(
      children: learners
          .map(
            (learner) => _AdminListTile(
              title: learner.email.isEmpty ? learner.userId : learner.email,
              subtitle:
                  '이름: ${learner.name} / 전화: ${learner.phone} / 기기: ${learner.deviceId}\n가입: ${learner.createdAt}',
              trailing: FilledButton(
                onPressed: () => onApprove(learner.userId),
                child: const Text('승인'),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _LearnerStatisticsSection extends StatelessWidget {
  const _LearnerStatisticsSection({
    required this.topLearners,
    required this.needsAttentionLearners,
    required this.learnerSummaries,
  });

  final List<_LearnerSummary> topLearners;
  final List<_LearnerSummary> needsAttentionLearners;
  final List<_LearnerSummary> learnerSummaries;

  @override
  Widget build(BuildContext context) {
    return AppSectionCard(
      title: '학습자 통계',
      description: '학습량, 진도, 정답률, 말하기 유사도, 최근 학습일을 학습자별로 확인합니다.',
      icon: Icons.groups_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('우수 학습자', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          _LearnerList(
            learners: topLearners,
            emptyText: '아직 우수 학습자를 계산할 데이터가 없습니다.',
          ),
          const SizedBox(height: 20),
          Text('관리 필요 학습자', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          _LearnerList(
            learners: needsAttentionLearners,
            emptyText: '관리 필요 학습자가 없습니다.',
          ),
          const SizedBox(height: 20),
          Text('전체 학습자', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          _LearnerList(
            learners: learnerSummaries,
            emptyText: '아직 제출된 리포트가 없습니다.',
          ),
        ],
      ),
    );
  }
}

class _RecentReportsSection extends StatelessWidget {
  const _RecentReportsSection({required this.reports});

  final List<_RecentReport> reports;

  @override
  Widget build(BuildContext context) {
    return AppSectionCard(
      title: '리포트 현황',
      description: '최근 제출된 학습 리포트의 세션별 관리 지표를 확인합니다.',
      icon: Icons.assignment_turned_in_outlined,
      child: _ReportList(reports: reports, emptyText: '제출된 리포트가 없습니다.'),
    );
  }
}

class _LearnerList extends StatelessWidget {
  const _LearnerList({required this.learners, required this.emptyText});

  final List<_LearnerSummary> learners;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    if (learners.isEmpty) {
      return Text(emptyText);
    }

    return Column(
      children: learners
          .map((learner) => _LearnerSummaryTile(learner))
          .toList(),
    );
  }
}

class _ReportList extends StatelessWidget {
  const _ReportList({required this.reports, required this.emptyText});

  final List<_RecentReport> reports;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    if (reports.isEmpty) {
      return Text(emptyText);
    }

    return Column(
      children: reports
          .map(
            (report) => _AdminListTile(
              title: report.learnerName,
              subtitle:
                  '${report.learnerEmail}\n'
                  '${report.category} / ${report.level} / ${report.mode}\n'
                  '진도 ${report.completedItems}/${report.totalItems}개(${_percent(report.completionRate)}) / '
                  '응답 ${report.attemptedAnswers}개 / 정답률 ${_percent(report.accuracy)} / '
                  '말하기 ${_percent(report.averageSimilarity)} / 소요 ${report.durationMinutes}분\n'
                  '향상도: 정답률 ${_signedPercent(report.accuracyDelta)}, 말하기 ${_signedPercent(report.similarityDelta)} / '
                  '제출: ${report.submittedAt}',
            ),
          )
          .toList(),
    );
  }
}

class _LearnerSummaryTile extends StatelessWidget {
  const _LearnerSummaryTile(this.learner);

  final _LearnerSummary learner;

  @override
  Widget build(BuildContext context) {
    return _AdminListTile(
      title: learner.name == '-' ? learner.email : learner.name,
      subtitle:
          '${learner.email} / ${learner.phone}\n'
          '관리 점수 ${learner.managementScore}점 / ${learner.riskReason}\n'
          '완료 세션 ${learner.sessions}건 / 완료 항목 ${learner.completedItems}개 / 누적 학습 ${learner.durationMinutes}분\n'
          '평균 진도 ${_percent(learner.cumulativeCompletionAverage)} / '
          '정답률 ${_percent(learner.accuracy)} / 말하기 ${_percent(learner.averageSimilarity)} / '
          '말하기 통과율 ${_percent(learner.cumulativeSpeakingPassRate)}\n'
          '최근 학습: ${learner.latestDateKey.isEmpty ? learner.updatedAt : learner.latestDateKey} / '
          '${learner.latestCategory} / ${learner.latestLevel} / ${learner.latestMode}',
    );
  }
}

class _InlineMetrics extends StatelessWidget {
  const _InlineMetrics({required this.items});

  final List<(String, String)> items;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items
          .map(
            (item) => Chip(
              label: Text('${item.$1}: ${item.$2}'),
              side: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
          )
          .toList(),
    );
  }
}

class _AdminListTile extends StatelessWidget {
  const _AdminListTile({
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 520;
          final content = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(subtitle),
            ],
          );

          if (trailing == null) {
            return content;
          }

          if (isCompact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                content,
                const SizedBox(height: 10),
                Align(alignment: Alignment.centerLeft, child: trailing!),
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: content),
              const SizedBox(width: 12),
              trailing!,
            ],
          );
        },
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.onTap,
    required this.selected,
  });

  final String label;
  final String value;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 170,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          decoration: BoxDecoration(
            color: selected
                ? colorScheme.primaryContainer
                : colorScheme.surfaceContainerHighest,
            border: Border.all(
              color: selected
                  ? colorScheme.primary
                  : colorScheme.outlineVariant,
              width: selected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 8),
              Text(
                value,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '상세 보기',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminDashboardData {
  const _AdminDashboardData({
    required this.generatedAt,
    required this.summary,
    required this.pendingApprovals,
    required this.learnerSummaries,
    required this.topLearners,
    required this.needsAttentionLearners,
    required this.recentReports,
  });

  final String generatedAt;
  final _DashboardSummary summary;
  final List<_PendingApproval> pendingApprovals;
  final List<_LearnerSummary> learnerSummaries;
  final List<_LearnerSummary> topLearners;
  final List<_LearnerSummary> needsAttentionLearners;
  final List<_RecentReport> recentReports;

  String get todayKey =>
      DateTime.now().toUtc().toIso8601String().substring(0, 10);

  DateTime get _sevenDaysAgo =>
      DateTime.now().toUtc().subtract(const Duration(days: 7));

  List<_RecentReport> get todayReports =>
      recentReports.where((report) => report.dateKey == todayKey).toList();

  List<_RecentReport> get weekReports => recentReports
      .where(
        (report) => report.submittedAtDate?.isAfter(_sevenDaysAgo) ?? false,
      )
      .toList();

  Set<String> get _todayLearnerIds => todayReports
      .map((report) => report.userId)
      .where((userId) => userId.isNotEmpty)
      .toSet();

  Set<String> get _weekLearnerIds => weekReports
      .map((report) => report.userId)
      .where((userId) => userId.isNotEmpty)
      .toSet();

  int get todayLearnerCount => _todayLearnerIds.length;

  int get weekLearnerCount => _weekLearnerIds.length;

  List<_LearnerSummary> get todayLearners => learnerSummaries
      .where((learner) => _todayLearnerIds.contains(learner.userId))
      .toList();

  List<_LearnerSummary> get weekLearners => learnerSummaries
      .where((learner) => _weekLearnerIds.contains(learner.userId))
      .toList();

  List<_LearnerSummary> get learnersByLowAccuracy {
    final learners = learnerSummaries
        .where((learner) => learner.accuracy != null)
        .toList();
    learners.sort((a, b) => a.accuracy!.compareTo(b.accuracy!));
    return learners;
  }

  List<_LearnerSummary> get learnersByLowSimilarity {
    final learners = learnerSummaries
        .where((learner) => learner.averageSimilarity != null)
        .toList();
    learners.sort(
      (a, b) => a.averageSimilarity!.compareTo(b.averageSimilarity!),
    );
    return learners;
  }

  factory _AdminDashboardData.fromMap(Map<String, dynamic> map) {
    return _AdminDashboardData(
      generatedAt: map['generatedAt'] as String? ?? '-',
      summary: _DashboardSummary.fromMap(_asMap(map['summary'])),
      pendingApprovals: _asList(
        map['pendingApprovals'],
      ).map((item) => _PendingApproval.fromMap(_asMap(item))).toList(),
      learnerSummaries: _asList(
        map['learnerSummaries'],
      ).map((item) => _LearnerSummary.fromMap(_asMap(item))).toList(),
      topLearners: _asList(
        map['topLearners'],
      ).map((item) => _LearnerSummary.fromMap(_asMap(item))).toList(),
      needsAttentionLearners: _asList(
        map['needsAttentionLearners'],
      ).map((item) => _LearnerSummary.fromMap(_asMap(item))).toList(),
      recentReports: _asList(
        map['recentReports'],
      ).map((item) => _RecentReport.fromMap(_asMap(item))).toList(),
    );
  }
}

class _DashboardSummary {
  const _DashboardSummary({
    required this.totalLearners,
    required this.activeLearners,
    required this.activeLearnersLast7Days,
    required this.totalSessions,
    required this.totalCompletedItems,
    required this.totalDurationMinutes,
    required this.averageCompletionRate,
    required this.averageAccuracy,
    required this.averageSimilarity,
    required this.pendingApprovalCount,
    required this.recentReportCount,
    required this.recentSevenDayReportCount,
    required this.recentThirtyDayReportCount,
  });

  final int totalLearners;
  final int activeLearners;
  final int activeLearnersLast7Days;
  final int totalSessions;
  final int totalCompletedItems;
  final int totalDurationMinutes;
  final int? averageCompletionRate;
  final int? averageAccuracy;
  final int? averageSimilarity;
  final int pendingApprovalCount;
  final int recentReportCount;
  final int recentSevenDayReportCount;
  final int recentThirtyDayReportCount;

  factory _DashboardSummary.fromMap(Map<String, dynamic> map) {
    return _DashboardSummary(
      totalLearners: _asInt(map['totalLearners']),
      activeLearners: _asInt(map['activeLearners']),
      activeLearnersLast7Days: _asInt(map['activeLearnersLast7Days']),
      totalSessions: _asInt(map['totalSessions']),
      totalCompletedItems: _asInt(map['totalCompletedItems']),
      totalDurationMinutes: _asInt(map['totalDurationMinutes']),
      averageCompletionRate: _asNullableInt(map['averageCompletionRate']),
      averageAccuracy: _asNullableInt(map['averageAccuracy']),
      averageSimilarity: _asNullableInt(map['averageSimilarity']),
      pendingApprovalCount: _asInt(map['pendingApprovalCount']),
      recentReportCount: _asInt(map['recentReportCount']),
      recentSevenDayReportCount: _asInt(map['recentSevenDayReportCount']),
      recentThirtyDayReportCount: _asInt(map['recentThirtyDayReportCount']),
    );
  }
}

class _PendingApproval {
  const _PendingApproval({
    required this.userId,
    required this.email,
    required this.name,
    required this.phone,
    required this.deviceId,
    required this.createdAt,
  });

  final String userId;
  final String email;
  final String name;
  final String phone;
  final String deviceId;
  final String createdAt;

  factory _PendingApproval.fromMap(Map<String, dynamic> map) {
    return _PendingApproval(
      userId: map['userId'] as String? ?? '',
      email: map['email'] as String? ?? '',
      name: map['name'] as String? ?? '-',
      phone: map['phone'] as String? ?? '-',
      deviceId: map['deviceId'] as String? ?? '-',
      createdAt: map['createdAt'] as String? ?? '-',
    );
  }
}

class _LearnerSummary {
  const _LearnerSummary({
    required this.userId,
    required this.email,
    required this.name,
    required this.phone,
    required this.sessions,
    required this.completedItems,
    required this.durationMinutes,
    required this.accuracy,
    required this.averageSimilarity,
    required this.cumulativeCompletionAverage,
    required this.cumulativeSpeakingPassRate,
    required this.latestCategory,
    required this.latestLevel,
    required this.latestMode,
    required this.latestDateKey,
    required this.managementScore,
    required this.riskReason,
    required this.updatedAt,
  });

  final String userId;
  final String email;
  final String name;
  final String phone;
  final int sessions;
  final int completedItems;
  final int durationMinutes;
  final int? accuracy;
  final int? averageSimilarity;
  final int? cumulativeCompletionAverage;
  final int? cumulativeSpeakingPassRate;
  final String latestCategory;
  final String latestLevel;
  final String latestMode;
  final String latestDateKey;
  final int managementScore;
  final String riskReason;
  final String updatedAt;

  factory _LearnerSummary.fromMap(Map<String, dynamic> map) {
    return _LearnerSummary(
      userId: map['userId'] as String? ?? '',
      email: map['email'] as String? ?? '-',
      name: map['name'] as String? ?? '-',
      phone: map['phone'] as String? ?? '-',
      sessions: _asInt(map['sessions']),
      completedItems: _asInt(map['completedItems']),
      durationMinutes: _asInt(map['durationMinutes']),
      accuracy: _asNullableInt(map['accuracy']),
      averageSimilarity: _asNullableInt(map['averageSimilarity']),
      cumulativeCompletionAverage: _asNullableInt(
        map['cumulativeCompletionAverage'],
      ),
      cumulativeSpeakingPassRate: _asNullableInt(
        map['cumulativeSpeakingPassRate'],
      ),
      latestCategory: map['latestCategory'] as String? ?? '-',
      latestLevel: map['latestLevel'] as String? ?? '-',
      latestMode: map['latestMode'] as String? ?? '-',
      latestDateKey: map['latestDateKey'] as String? ?? '',
      managementScore: _asInt(map['managementScore']),
      riskReason: map['riskReason'] as String? ?? '-',
      updatedAt: map['updatedAt'] as String? ?? '-',
    );
  }
}

class _RecentReport {
  const _RecentReport({
    required this.reportId,
    required this.userId,
    required this.learnerName,
    required this.learnerEmail,
    required this.category,
    required this.mode,
    required this.level,
    required this.completedItems,
    required this.totalItems,
    required this.completionRate,
    required this.attemptedAnswers,
    required this.accuracy,
    required this.averageSimilarity,
    required this.durationMinutes,
    required this.accuracyDelta,
    required this.similarityDelta,
    required this.dateKey,
    required this.submittedAt,
  });

  final String reportId;
  final String userId;
  final String learnerName;
  final String learnerEmail;
  final String category;
  final String mode;
  final String level;
  final int completedItems;
  final int totalItems;
  final int? completionRate;
  final int attemptedAnswers;
  final int? accuracy;
  final int? averageSimilarity;
  final int durationMinutes;
  final int? accuracyDelta;
  final int? similarityDelta;
  final String dateKey;
  final String submittedAt;

  DateTime? get submittedAtDate => DateTime.tryParse(submittedAt)?.toUtc();

  factory _RecentReport.fromMap(Map<String, dynamic> map) {
    return _RecentReport(
      reportId: map['reportId'] as String? ?? '',
      userId: map['userId'] as String? ?? '',
      learnerName: map['learnerName'] as String? ?? '-',
      learnerEmail: map['learnerEmail'] as String? ?? '-',
      category: map['category'] as String? ?? '-',
      mode: map['mode'] as String? ?? '-',
      level: map['level'] as String? ?? '-',
      completedItems: _asInt(map['completedItems']),
      totalItems: _asInt(map['totalItems']),
      completionRate: _asNullableInt(map['completionRate']),
      attemptedAnswers: _asInt(map['attemptedAnswers']),
      accuracy: _asNullableInt(map['accuracy']),
      averageSimilarity: _asNullableInt(map['averageSimilarity']),
      durationMinutes: _asInt(map['durationMinutes']),
      accuracyDelta: _asNullableInt(map['accuracyDelta']),
      similarityDelta: _asNullableInt(map['similarityDelta']),
      dateKey: map['dateKey'] as String? ?? '',
      submittedAt: map['submittedAt'] as String? ?? '-',
    );
  }
}

Map<String, dynamic> _asMap(Object? value) {
  if (value is Map) {
    return value.map((key, value) => MapEntry(key.toString(), value));
  }
  return <String, dynamic>{};
}

List<Object?> _asList(Object? value) {
  return value is List ? value : const <Object?>[];
}

int _asInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.round();
  }
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

int? _asNullableInt(Object? value) {
  if (value == null) {
    return null;
  }
  return _asInt(value);
}

String _percent(int? value) => value == null ? '-' : '$value%';

String _signedPercent(int? value) {
  if (value == null) {
    return '-';
  }
  return value >= 0 ? '+$value%' : '$value%';
}

String _averagePercent(Iterable<int?> values) {
  final valid = values.whereType<int>().toList();
  if (valid.isEmpty) {
    return '-';
  }
  final sum = valid.fold<int>(0, (previous, value) => previous + value);
  return '${(sum / valid.length).round()}%';
}
