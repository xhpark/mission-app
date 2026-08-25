import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/app_error_messages.dart';
import '../../../../core/firebase/firebase_providers.dart';
import '../../../../core/firebase/firebase_services.dart';
import '../../../../core/widgets/app_section_card.dart';
import '../../../../core/widgets/app_status_banner.dart';
import '../../../learning_content/data/thai_learning_content.dart';
import '../../../learning_select/data/today_link_repository.dart';

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
                const _TodayLinkAdminSection(),
                const SizedBox(height: 16),
                const _SimilarityEventSection(),
                const SizedBox(height: 16),
                const _DailyActivityReportSection(),
                const SizedBox(height: 16),
                const _Thai25DayBulkSeedSection(),
                const SizedBox(height: 16),
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
                  '생성 시각: ${_toKstDisplay(data.generatedAt)}',
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

class _TodayLinkAdminSection extends ConsumerStatefulWidget {
  const _TodayLinkAdminSection();

  @override
  ConsumerState<_TodayLinkAdminSection> createState() =>
      _TodayLinkAdminSectionState();
}

class _TodayLinkAdminSectionState
    extends ConsumerState<_TodayLinkAdminSection> {
  final _titleController = TextEditingController();
  final _urlController = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  bool _loadingStats = false;
  String? _message;
  bool _messageIsError = false;
  DateTime? _selectedDate; // null = today KST
  TodayLinkClicks? _clickStats;

  String get _dateKey {
    final kst = DateTime.now().toUtc().add(const Duration(hours: 9));
    final d = _selectedDate ?? kst;
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  bool get _isToday {
    if (_selectedDate == null) return true;
    final kst = DateTime.now().toUtc().add(const Duration(hours: 9));
    final d = _selectedDate!;
    return d.year == kst.year && d.month == kst.month && d.day == kst.day;
  }

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final kst = DateTime.now().toUtc().add(const Duration(hours: 9));
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? kst,
      firstDate: DateTime(2026, 1, 1),
      lastDate: DateTime(kst.year + 1, 12, 31),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _selectedDate = picked;
      _loading = true;
      _clickStats = null;
      _message = null;
    });
    _loadAll();
  }

  void _resetToToday() {
    setState(() {
      _selectedDate = null;
      _loading = true;
      _clickStats = null;
      _message = null;
    });
    _loadAll();
  }

  Future<void> _loadAll() async {
    await Future.wait([_loadExisting(), _loadClickStats()]);
  }

  Future<void> _loadExisting() async {
    try {
      final link = await ref
          .read(todayLinkRepositoryProvider)
          .getTodayLink(dateKey: _dateKey);
      if (!mounted) return;
      setState(() {
        _titleController.text = link.title ?? '';
        _urlController.text = link.url ?? '';
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _loadClickStats() async {
    final user = ref.read(authStateChangesProvider).asData?.value;
    if (user == null) return;
    setState(() => _loadingStats = true);
    try {
      final stats = await ref
          .read(todayLinkRepositoryProvider)
          .getTodayLinkClicks(adminUserId: user.uid, dateKey: _dateKey);
      if (!mounted) return;
      setState(() {
        _clickStats = stats;
        _loadingStats = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingStats = false);
    }
  }

  Future<void> _save() async {
    final user = ref.read(authStateChangesProvider).asData?.value;
    if (user == null) return;

    setState(() {
      _saving = true;
      _message = null;
    });
    try {
      await ref
          .read(todayLinkRepositoryProvider)
          .setTodayLink(
            adminUserId: user.uid,
            url: _urlController.text.trim(),
            title: _titleController.text.trim(),
            dateKey: _dateKey,
          );
      if (!mounted) return;
      setState(() {
        _message = '$_dateKey 링크를 저장했습니다.';
        _messageIsError = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _message = _todayLinkErrorMessage(error);
        _messageIsError = true;
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _todayLinkErrorMessage(Object error) {
    if (error is FirebaseFunctionsException &&
        error.code == 'invalid-argument') {
      return '제목과 URL을 올바르게 입력해 주세요. URL은 http:// 또는 https://로 시작해야 합니다.';
    }
    return toUserFacingErrorMessage(error);
  }

  @override
  Widget build(BuildContext context) {
    final stats = _clickStats;
    return AppSectionCard(
      title: '링크 관리',
      description: '학습자가 "오늘의 학습과 복습"을 누르면 열리는 외부 페이지 링크를 날짜별로 등록합니다.',
      icon: Icons.link,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _isToday ? '오늘 ($_dateKey)' : _dateKey,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              OutlinedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_today_outlined, size: 16),
                label: const Text('날짜 선택'),
              ),
              if (!_isToday) ...[
                const SizedBox(width: 8),
                TextButton(onPressed: _resetToToday, child: const Text('오늘로')),
              ],
            ],
          ),
          const SizedBox(height: 8),
          if (_loadingStats)
            const LinearProgressIndicator()
          else if (stats != null)
            Chip(
              avatar: const Icon(Icons.touch_app, size: 16),
              label: Text(
                '학습자 ${stats.totalLearners}명 접속 / 총 ${stats.totalClicks}회 클릭',
              ),
            ),
          const SizedBox(height: 8),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else ...[
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: '제목'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _urlController,
              decoration: const InputDecoration(
                labelText: 'URL',
                hintText: 'https://...',
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 12),
            if (_message != null) ...[
              AppStatusBanner(
                isError: _messageIsError,
                icon: _messageIsError
                    ? Icons.error_outline
                    : Icons.check_circle_outline,
                message: _message!,
              ),
              const SizedBox(height: 12),
            ],
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(_saving ? '저장 중...' : '$_dateKey 링크 저장'),
              ),
            ),
          ],
          if (stats != null && stats.learners.isNotEmpty) ...[
            const Divider(height: 24),
            Text('접속 학습자', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 4),
            ...stats.learners.map(
              (l) => _AdminListTile(
                title: l.name,
                subtitle: '${l.clickCount}회 클릭',
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DailyActivityReportSection extends ConsumerStatefulWidget {
  const _DailyActivityReportSection();

  @override
  ConsumerState<_DailyActivityReportSection> createState() =>
      _DailyActivityReportSectionState();
}

class _DailyActivityReportSectionState
    extends ConsumerState<_DailyActivityReportSection> {
  bool _loading = false;
  String? _message;
  bool _messageIsError = false;
  Map<String, dynamic>? _reportData;
  String? _reportDateKey;
  DateTime? _selectedDate; // null = yesterday KST

  String get _selectedDateKey {
    final kst = DateTime.now().toUtc().add(const Duration(hours: 9));
    final d = _selectedDate ?? kst.subtract(const Duration(days: 1));
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  Future<void> _pickDate() async {
    final kst = DateTime.now().toUtc().add(const Duration(hours: 9));
    final yesterday = kst.subtract(const Duration(days: 1));
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? yesterday,
      firstDate: DateTime(2026, 1, 1),
      lastDate: kst,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _selectedDate = picked;
      _reportData = null;
      _message = null;
    });
  }

  Future<void> _loadReport() async {
    final user = ref.read(authStateChangesProvider).asData?.value;
    if (user == null) return;
    final dateKey = _selectedDateKey;

    setState(() {
      _loading = true;
      _message = null;
      _reportData = null;
    });
    try {
      final result = await ref
          .read(firebaseFunctionsProvider)
          .httpsCallable('getDailyActivityReport')
          .call<Map<String, dynamic>>(<String, dynamic>{
            'adminUserId': user.uid,
            'dateKey': dateKey,
          });
      final data = _asMap(result.data);
      if (!(data['exists'] as bool? ?? false)) {
        setState(() {
          _message = '${data['dateKey'] ?? dateKey} 보고서가 아직 생성되지 않았습니다.';
          _messageIsError = false;
          _loading = false;
        });
        return;
      }
      setState(() {
        _reportData = _asMap(data['report']);
        _reportDateKey = (data['dateKey'] as String?) ?? dateKey;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _message = toUserFacingErrorMessage(error);
        _messageIsError = true;
        _loading = false;
      });
    }
  }

  Future<void> _generateReport() async {
    final user = ref.read(authStateChangesProvider).asData?.value;
    if (user == null) return;
    final dateKey = _selectedDateKey;

    setState(() {
      _loading = true;
      _message = null;
      _reportData = null;
    });
    try {
      final result = await ref
          .read(firebaseFunctionsProvider)
          .httpsCallable('generateDailyActivityReportForDate')
          .call<Map<String, dynamic>>(<String, dynamic>{
            'adminUserId': user.uid,
            'dateKey': dateKey,
          });
      final data = _asMap(result.data);
      setState(() {
        _reportData = data;
        _reportDateKey = data['dateKey'] as String? ?? dateKey;
        _message = '$dateKey 보고서가 생성되었습니다.';
        _messageIsError = false;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _message = toUserFacingErrorMessage(error);
        _messageIsError = true;
        _loading = false;
      });
    }
  }

  String _fmtDuration(int seconds) {
    if (seconds <= 0) return '-';
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (h > 0) return '$h시간 $m분 $s초';
    if (m > 0) return '$m분 $s초';
    return '$s초';
  }

  @override
  Widget build(BuildContext context) {
    final report = _reportData;
    return AppSectionCard(
      title: '일별 학습 활동 현황',
      description: '매일 06:20 자동 생성 또는 수동 생성.',
      icon: Icons.bar_chart,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _selectedDateKey,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              OutlinedButton.icon(
                onPressed: _loading ? null : _pickDate,
                icon: const Icon(Icons.calendar_today_outlined, size: 16),
                label: const Text('날짜 선택'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_message != null) ...[
            AppStatusBanner(
              isError: _messageIsError,
              icon: _messageIsError ? Icons.error_outline : Icons.info_outline,
              message: _message!,
            ),
            const SizedBox(height: 12),
          ],
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (report != null) ...[
            Text(
              '${_reportDateKey ?? ''} 보고서 — 활동 ${report['activeCount'] ?? 0}명 / 전체 ${report['totalApproved'] ?? 0}명',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            if ((report['generatedAtKst'] as String?)?.isNotEmpty ?? false) ...[
              const SizedBox(height: 4),
              Text(
                '생성 시각: ${report['generatedAtKst']}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ] else if ((report['generatedAt'] as String?)?.isNotEmpty ??
                false) ...[
              const SizedBox(height: 4),
              Text(
                '생성 시각: ${_toKstDisplay(report['generatedAt'] as String?)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 8),
            _buildTopLearners(context, report),
            const SizedBox(height: 8),
            _buildInactive(context, report),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _loading ? null : _loadReport,
                icon: const Icon(Icons.download_outlined),
                label: Text('$_selectedDateKey 보고서 불러오기'),
              ),
              FilledButton.icon(
                onPressed: _loading ? null : _generateReport,
                icon: const Icon(Icons.refresh),
                label: Text('$_selectedDateKey 보고서 재생성'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTopLearners(BuildContext context, Map<String, dynamic> report) {
    final learners = (report['activeLearners'] as List<dynamic>? ?? [])
        .map((e) => _asMap(e))
        .toList();
    if (learners.isEmpty) {
      return const Text('활동한 학습자 없음');
    }
    final byDuration = [...learners]
      ..sort(
        (a, b) => ((b['durationSeconds'] as num?) ?? 0).compareTo(
          (a['durationSeconds'] as num?) ?? 0,
        ),
      );
    final bySession = [...learners]
      ..sort(
        (a, b) => ((b['sessionCount'] as num?) ?? 0).compareTo(
          (a['sessionCount'] as num?) ?? 0,
        ),
      );
    final withSim = learners.where((l) => l['avgSimilarity'] != null).toList()
      ..sort(
        (a, b) => ((b['avgSimilarity'] as num?) ?? 0).compareTo(
          (a['avgSimilarity'] as num?) ?? 0,
        ),
      );

    final rows = <Widget>[];

    void addTop(
      String label,
      List<Map<String, dynamic>> list,
      String Function(Map<String, dynamic>) detail,
    ) {
      rows.add(
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          child: Text(label, style: Theme.of(context).textTheme.labelLarge),
        ),
      );
      for (final (i, l) in list.take(3).indexed) {
        final approx = (l['durationSource'] as String?) == 'proxy' ? '~' : '';
        rows.add(
          _AdminListTile(
            title: '${i + 1}위  ${l['name'] ?? '-'}  (${l['phone'] ?? '-'})',
            subtitle: detail(l).replaceFirst('{approx}', approx),
          ),
        );
      }
    }

    addTop(
      '학습 시간 상위',
      byDuration,
      (l) =>
          '{approx}${_fmtDuration((l['durationSeconds'] as num?)?.toInt() ?? 0)}  |  세션 ${l['sessionCount'] ?? 0}회',
    );
    addTop(
      '세션 수 상위',
      bySession,
      (l) => '${l['sessionCount'] ?? 0}회  |  말하기 ${l['speakingItems'] ?? 0}건',
    );
    if (withSim.isNotEmpty) {
      addTop(
        '발음 유사도 상위',
        withSim,
        (l) =>
            '${l['avgSimilarity'] ?? 0}%  |  말하기 ${l['speakingItems'] ?? 0}건',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: rows,
    );
  }

  Widget _buildInactive(BuildContext context, Map<String, dynamic> report) {
    final names = (report['inactiveLearnerNames'] as List<dynamic>? ?? [])
        .map((e) => e.toString())
        .toList();
    if (names.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          child: Text(
            '미활동 ${names.length}명',
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ),
        Text(names.join(' · '), style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _SimilarityEventSection extends ConsumerStatefulWidget {
  const _SimilarityEventSection();

  @override
  ConsumerState<_SimilarityEventSection> createState() =>
      _SimilarityEventSectionState();
}

class _SimilarityEventSectionState
    extends ConsumerState<_SimilarityEventSection> {
  static const _refreshInterval = Duration(seconds: 5);
  Timer? _timer;
  bool _loading = false;
  bool _saving = false;
  String? _message;
  bool _messageIsError = false;
  _SimilarityEventDashboard? _dashboard;
  ThaiSentenceContent _selectedSentence = thaiSentenceContents.first;

  String get _selectedContentSetId =>
      '${_selectedSentence.category}-beginner-default';

  ThaiSentenceContent get _displaySentence {
    final event = _dashboard?.event;
    if (event?.status != 'active') return _selectedSentence;
    final eventItemId = event?.itemId ?? '';
    if (eventItemId.isEmpty) return _selectedSentence;
    for (final sentence in thaiSentenceContents) {
      if (sentence.id == eventItemId) return sentence;
    }
    return _selectedSentence;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _syncTimer() {
    final active = _dashboard?.event?.status == 'active';
    if (!active) {
      _timer?.cancel();
      _timer = null;
      return;
    }
    _timer ??= Timer.periodic(_refreshInterval, (_) => _load(silent: true));
  }

  Future<void> _load({bool silent = false}) async {
    final user = ref.read(authStateChangesProvider).asData?.value;
    if (user == null) return;
    if (!silent) {
      setState(() {
        _loading = true;
        _message = null;
      });
    }
    try {
      final result = await ref
          .read(firebaseFunctionsProvider)
          .httpsCallable('getSimilarityEventDashboard')
          .call<Map<String, dynamic>>(<String, dynamic>{
            'adminUserId': user.uid,
          });
      if (!mounted) return;
      setState(() {
        _dashboard = _SimilarityEventDashboard.fromMap(_asMap(result.data));
        _loading = false;
      });
      _syncTimer();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _message = toUserFacingErrorMessage(error);
        _messageIsError = true;
        _loading = false;
      });
      _syncTimer();
    }
  }

  Future<void> _start() async {
    final user = ref.read(authStateChangesProvider).asData?.value;
    if (user == null) return;
    setState(() {
      _saving = true;
      _message = null;
    });
    try {
      final result = await ref
          .read(firebaseFunctionsProvider)
          .httpsCallable('startSimilarityEvent')
          .call<Map<String, dynamic>>(<String, dynamic>{
            'adminUserId': user.uid,
            'contentSetId': _selectedContentSetId,
            'itemId': _selectedSentence.id,
          });
      if (!mounted) return;
      setState(() {
        _dashboard = _SimilarityEventDashboard.fromMap(_asMap(result.data));
        _message = '유사도 시상 이벤트를 시작했습니다.';
        _messageIsError = false;
        _saving = false;
      });
      _syncTimer();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _message = toUserFacingErrorMessage(error);
        _messageIsError = true;
        _saving = false;
      });
    }
  }

  Future<void> _end() async {
    final user = ref.read(authStateChangesProvider).asData?.value;
    final eventId = _dashboard?.event?.eventId;
    if (user == null || eventId == null || eventId.isEmpty) return;
    setState(() {
      _saving = true;
      _message = null;
    });
    try {
      final result = await ref
          .read(firebaseFunctionsProvider)
          .httpsCallable('endSimilarityEvent')
          .call<Map<String, dynamic>>(<String, dynamic>{
            'adminUserId': user.uid,
            'eventId': eventId,
          });
      if (!mounted) return;
      setState(() {
        _dashboard = _SimilarityEventDashboard.fromMap(_asMap(result.data));
        _message = '유사도 시상 이벤트를 종료했습니다.';
        _messageIsError = false;
        _saving = false;
      });
      _syncTimer();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _message = toUserFacingErrorMessage(error);
        _messageIsError = true;
        _saving = false;
      });
    }
  }

  Future<void> _selectSentence() async {
    final selected = await showModalBottomSheet<ThaiSentenceContent>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView.separated(
          shrinkWrap: true,
          itemCount: thaiSentenceContents.length,
          separatorBuilder: (context, index) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final sentence = thaiSentenceContents[index];
            return ListTile(
              selected: sentence.id == _selectedSentence.id,
              title: Text(
                sentence.koreanText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: sentence.hangulPronunciation.isEmpty
                  ? null
                  : Text(
                      sentence.hangulPronunciation,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
              onTap: () => Navigator.of(context).pop(sentence),
            );
          },
        ),
      ),
    );
    if (!mounted || selected == null) return;
    setState(() => _selectedSentence = selected);
  }

  @override
  Widget build(BuildContext context) {
    final dashboard = _dashboard;
    final event = dashboard?.event;
    final active = event?.status == 'active';
    final selectionDisabled = active || _saving;
    final displaySentence = _displaySentence;
    return AppSectionCard(
      title: '유사도 시상 이벤트',
      description:
          '강사가 문장을 지정해 시작하면, 서버 우선/폰 전용 말하기 결과가 클라우드 저장 시 이벤트에 자동 집계됩니다.',
      icon: Icons.emoji_events_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: selectionDisabled ? null : _selectSentence,
            borderRadius: BorderRadius.circular(8),
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: '시상 문장',
                enabled: !selectionDisabled,
                border: const OutlineInputBorder(),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      displaySentence.koreanText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_drop_down),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('한글 발음 표기', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 2),
              Text(
                displaySentence.hangulPronunciation.isEmpty
                    ? displaySentence.koreanText
                    : displaySentence.hangulPronunciation,
                softWrap: true,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: active || _saving ? null : _start,
                icon: const Icon(Icons.play_arrow),
                label: Text(_saving && !active ? '시작 중...' : '이벤트 시작'),
              ),
              OutlinedButton.icon(
                onPressed: !active || _saving ? null : _end,
                icon: const Icon(Icons.stop),
                label: Text(_saving && active ? '종료 중...' : '이벤트 종료'),
              ),
              OutlinedButton.icon(
                onPressed: _loading ? null : () => _load(),
                icon: const Icon(Icons.refresh),
                label: Text(active ? '수동 새로고침' : '결과 불러오기'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            active
                ? '진행 중: ${_refreshInterval.inSeconds}초마다 자동 새로고침'
                : '대기 중: 이벤트 시작 후 자동 새로고침',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (_message != null) ...[
            const SizedBox(height: 12),
            AppStatusBanner(
              isError: _messageIsError,
              icon: _messageIsError ? Icons.error_outline : Icons.info_outline,
              message: _message!,
            ),
          ],
          const Divider(height: 24),
          if (_loading && dashboard == null)
            const Center(child: CircularProgressIndicator())
          else if (dashboard == null || event == null)
            const Text('아직 생성된 유사도 시상 이벤트가 없습니다.')
          else
            _SimilarityEventRankings(dashboard: dashboard),
        ],
      ),
    );
  }
}

class _SimilarityEventRankings extends StatelessWidget {
  const _SimilarityEventRankings({required this.dashboard});

  final _SimilarityEventDashboard dashboard;

  @override
  Widget build(BuildContext context) {
    final event = dashboard.event!;
    final rankings = dashboard.rankings;
    final averageRankings = dashboard.averageRankings;
    final reportRankings = dashboard.reportRankings;
    final sentence = _sentenceContentById(event.itemId);
    final sentenceTitle = sentence?.koreanText ?? '선택한 문장';
    final sentencePronunciation = sentence?.hangulPronunciation ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _InlineMetrics(
          items: [
            ('상태', event.status == 'active' ? '진행 중' : '종료'),
            ('문장', sentenceTitle),
            ('문장 참여', '${dashboard.totalLearners}명'),
            ('문장 보고', '${dashboard.totalAttempts}건'),
            ('평균 참여', '${dashboard.averageTotalLearners}명'),
            ('전체 보고', '${dashboard.averageTotalAttempts}건'),
            ('리포트 참여', '${dashboard.reportTotalLearners}명'),
            ('리포트 수', '${dashboard.reportTotalReports}건'),
            ('시작', _toKstDisplay(event.startedAt)),
          ],
        ),
        const SizedBox(height: 12),
        Text(sentenceTitle, style: Theme.of(context).textTheme.titleMedium),
        if (sentencePronunciation.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            sentencePronunciation,
            softWrap: true,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
        const SizedBox(height: 8),
        Text('시상 문장 최고점 TOP 5', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 6),
        if (rankings.isEmpty)
          const Text('아직 시상 문장 유사도 결과가 없습니다.')
        else
          for (final (index, ranking) in rankings.indexed)
            _AdminListTile(
              title: '${index + 1}위  ${ranking.learnerName}',
              subtitle:
                  '최고 점수 ${ranking.similarityScore}% / ${ranking.passed ? '통과' : '재시도 필요'} / ${ranking.sourceLabel}\n'
                  '전화: ${ranking.learnerPhone} / 제출: ${ranking.evaluatedAtKst}',
            ),
        const SizedBox(height: 16),
        Text(
          '접수 기간 종합 평균 TOP 5',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 6),
        if (averageRankings.isEmpty)
          const Text('아직 접수 기간 평균을 계산할 유사도 결과가 없습니다.')
        else
          for (final (index, ranking) in averageRankings.indexed)
            _AdminListTile(
              title: '${index + 1}위  ${ranking.learnerName}',
              subtitle:
                  '평균 ${ranking.averageSimilarity}% / 보고 ${ranking.attemptCount}건\n'
                  '전화: ${ranking.learnerPhone} / 최근 제출: ${ranking.latestEvaluatedAtKst}',
            ),
        const SizedBox(height: 16),
        Text(
          '리포트 기준 전체 유사도 평균 TOP 10',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 6),
        if (reportRankings.isEmpty)
          const Text('이벤트 기간 중 제출된 리포트가 없습니다.')
        else
          for (final (index, ranking) in reportRankings.indexed)
            _AdminListTile(
              title: '${index + 1}위  ${ranking.learnerName}',
              subtitle:
                  '평균 ${ranking.averageSimilarity}% / 리포트 ${ranking.reportCount}건\n'
                  '전화: ${ranking.learnerPhone} / 최근 리포트: ${ranking.latestSubmittedAtKst}',
            ),
      ],
    );
  }
}

ThaiSentenceContent? _sentenceContentById(String itemId) {
  for (final sentence in thaiSentenceContents) {
    if (sentence.id == itemId) return sentence;
  }
  return null;
}

/// One-time bulk seed for the "태국어 25일 일별 학습계획" curriculum: weekday-only
/// dates (Sat/Sun skipped, per the plan's Mon-Fri schedule) starting
/// 2026-06-29, each pointing at https://xhpark.github.io/Thai_25day/?day=N.
/// Reuses the same `setTodayLink` callable as the manual single-day form
/// above — no new backend/schema. Safe to leave in place; re-running just
/// overwrites the same 25 dates with the same data (merge:true).
const _thai25DayPlan = <({String dateKey, String title, String url})>[
  (
    dateKey: '2026-06-29',
    title: '1일차 첫 인사 시작하기',
    url: 'https://xhpark.github.io/Thai_25day/?day=1',
  ),
  (
    dateKey: '2026-06-30',
    title: '2일차 시간대 인사 익히기',
    url: 'https://xhpark.github.io/Thai_25day/?day=2',
  ),
  (
    dateKey: '2026-07-01',
    title: '3일차 감사와 응답',
    url: 'https://xhpark.github.io/Thai_25day/?day=3',
  ),
  (
    dateKey: '2026-07-02',
    title: '4일차 짧게 대답하기',
    url: 'https://xhpark.github.io/Thai_25day/?day=4',
  ),
  (
    dateKey: '2026-07-03',
    title: '5일차 예수님 믿으세요',
    url: 'https://xhpark.github.io/Thai_25day/?day=5',
  ),
  (
    dateKey: '2026-07-06',
    title: '6일차 정중하게 말 걸기',
    url: 'https://xhpark.github.io/Thai_25day/?day=6',
  ),
  (
    dateKey: '2026-07-07',
    title: '7일차 이름 묻기',
    url: 'https://xhpark.github.io/Thai_25day/?day=7',
  ),
  (
    dateKey: '2026-07-08',
    title: '8일차 자기소개하기',
    url: 'https://xhpark.github.io/Thai_25day/?day=8',
  ),
  (
    dateKey: '2026-07-09',
    title: '9일차 나이 묻기',
    url: 'https://xhpark.github.io/Thai_25day/?day=9',
  ),
  (
    dateKey: '2026-07-10',
    title: '10일차 우리는 당신들을 사랑해요',
    url: 'https://xhpark.github.io/Thai_25day/?day=10',
  ),
  (
    dateKey: '2026-07-13',
    title: '11일차 화장실 묻기',
    url: 'https://xhpark.github.io/Thai_25day/?day=11',
  ),
  (
    dateKey: '2026-07-14',
    title: '12일차 식사 대화',
    url: 'https://xhpark.github.io/Thai_25day/?day=12',
  ),
  (
    dateKey: '2026-07-15',
    title: '13일차 격려하기',
    url: 'https://xhpark.github.io/Thai_25day/?day=13',
  ),
  (
    dateKey: '2026-07-16',
    title: '14일차 작별 인사',
    url: 'https://xhpark.github.io/Thai_25day/?day=14',
  ),
  (
    dateKey: '2026-07-17',
    title: '15일차 기도해 드릴게요',
    url: 'https://xhpark.github.io/Thai_25day/?day=15',
  ),
  (
    dateKey: '2026-07-20',
    title: '16일차 예수님의 사랑 전하기',
    url: 'https://xhpark.github.io/Thai_25day/?day=16',
  ),
  (
    dateKey: '2026-07-21',
    title: '17일차 하나님의 사랑 전하기',
    url: 'https://xhpark.github.io/Thai_25day/?day=17',
  ),
  (
    dateKey: '2026-07-22',
    title: '18일차 축복하기',
    url: 'https://xhpark.github.io/Thai_25day/?day=18',
  ),
  (
    dateKey: '2026-07-23',
    title: '19일차 하나님은 사랑이십니다',
    url: 'https://xhpark.github.io/Thai_25day/?day=19',
  ),
  (
    dateKey: '2026-07-24',
    title: '20일차 함께 찬양해요',
    url: 'https://xhpark.github.io/Thai_25day/?day=20',
  ),
  (
    dateKey: '2026-07-27',
    title: '21일차 인사와 감사 전체 복습',
    url: 'https://xhpark.github.io/Thai_25day/?day=21',
  ),
  (
    dateKey: '2026-07-28',
    title: '22일차 새 친구와 자기소개 복습',
    url: 'https://xhpark.github.io/Thai_25day/?day=22',
  ),
  (
    dateKey: '2026-07-29',
    title: '23일차 생활 대화와 돌봄 복습',
    url: 'https://xhpark.github.io/Thai_25day/?day=23',
  ),
  (
    dateKey: '2026-07-30',
    title: '24일차 사랑·축복·믿음·찬양 복습',
    url: 'https://xhpark.github.io/Thai_25day/?day=24',
  ),
  (
    dateKey: '2026-07-31',
    title: '25일차 전체 24문장 종합 리허설',
    url: 'https://xhpark.github.io/Thai_25day/?day=25',
  ),
];

class _Thai25DayBulkSeedSection extends ConsumerStatefulWidget {
  const _Thai25DayBulkSeedSection();

  @override
  ConsumerState<_Thai25DayBulkSeedSection> createState() =>
      _Thai25DayBulkSeedSectionState();
}

class _Thai25DayBulkSeedSectionState
    extends ConsumerState<_Thai25DayBulkSeedSection> {
  bool _running = false;
  String? _resultMessage;
  bool _resultIsError = false;

  Future<void> _runBulkSeed() async {
    final user = ref.read(authStateChangesProvider).asData?.value;
    if (user == null) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('25일치 링크를 일괄 등록할까요?'),
        content: Text(
          '${_thai25DayPlan.first.dateKey} ~ ${_thai25DayPlan.last.dateKey} '
          '(평일만, 총 ${_thai25DayPlan.length}일) 동안 매일 다른 링크가 등록됩니다. '
          '이미 등록된 날짜가 있으면 덮어씁니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('등록'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }

    setState(() {
      _running = true;
      _resultMessage = null;
    });

    var successCount = 0;
    final failures = <String>[];
    for (final entry in _thai25DayPlan) {
      try {
        await ref
            .read(todayLinkRepositoryProvider)
            .setTodayLink(
              adminUserId: user.uid,
              url: entry.url,
              title: entry.title,
              dateKey: entry.dateKey,
            );
        successCount++;
      } catch (_) {
        failures.add(entry.dateKey);
      }
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _running = false;
      _resultIsError = failures.isNotEmpty;
      _resultMessage = failures.isEmpty
          ? '$successCount일치 링크를 모두 등록했습니다.'
          : '$successCount일치 등록 성공, 실패: ${failures.join(', ')}';
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppSectionCard(
      title: '태국어 25일 학습계획 일괄 등록',
      description:
          '${_thai25DayPlan.first.dateKey} ~ ${_thai25DayPlan.last.dateKey} '
          '(평일만) 1~25일차 링크를 한 번에 등록합니다. 위 "오늘의 링크 관리" 폼과 같은 저장 경로를 사용합니다.',
      icon: Icons.playlist_add_check_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_resultMessage != null) ...[
            AppStatusBanner(
              isError: _resultIsError,
              icon: _resultIsError
                  ? Icons.error_outline
                  : Icons.check_circle_outline,
              message: _resultMessage!,
            ),
            const SizedBox(height: 12),
          ],
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: _running ? null : _runBulkSeed,
              child: Text(_running ? '등록 중...' : '25일치 일괄 등록'),
            ),
          ),
        ],
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
    final notStartedLearners = summary.totalLearners - summary.activeLearners;

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
            label: '학습 시작',
            value: '${summary.activeLearners}명',
            selected: selectedDetail == _DashboardDetail.allLearners,
            onTap: () => onSelect(_DashboardDetail.allLearners),
          ),
          _MetricTile(
            label: '미시작',
            value: '$notStartedLearners명',
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
                  '이름: ${learner.name} / 전화: ${learner.phone} / 기기: ${learner.deviceId}\n가입: ${learner.createdAtKst}',
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
                  '제출: ${report.submittedAtKst}',
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
          '최근 학습: ${learner.latestDateKey.isEmpty ? learner.updatedAtKst : learner.latestDateKey} / '
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

  String get todayKey {
    final nowKst = DateTime.now().toUtc().add(const Duration(hours: 9));
    return '${nowKst.year}-${nowKst.month.toString().padLeft(2, '0')}-${nowKst.day.toString().padLeft(2, '0')}';
  }

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

  String get createdAtKst => _toKstDisplay(createdAt);

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

  String get updatedAtKst => _toKstDisplay(updatedAt);

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
  String get submittedAtKst => _toKstDisplay(submittedAt);

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

class _SimilarityEventDashboard {
  const _SimilarityEventDashboard({
    required this.event,
    required this.totalLearners,
    required this.totalAttempts,
    required this.rankings,
    required this.averageTotalLearners,
    required this.averageTotalAttempts,
    required this.averageRankings,
    required this.reportTotalLearners,
    required this.reportTotalReports,
    required this.reportRankings,
  });

  final _SimilarityEventInfo? event;
  final int totalLearners;
  final int totalAttempts;
  final List<_SimilarityEventRanking> rankings;
  final int averageTotalLearners;
  final int averageTotalAttempts;
  final List<_SimilarityEventAverageRanking> averageRankings;
  final int reportTotalLearners;
  final int reportTotalReports;
  final List<_SimilarityEventReportRanking> reportRankings;

  factory _SimilarityEventDashboard.fromMap(Map<String, dynamic> map) {
    final eventMap = _asMap(map['event']);
    return _SimilarityEventDashboard(
      event: eventMap.isEmpty ? null : _SimilarityEventInfo.fromMap(eventMap),
      totalLearners: _asInt(map['totalLearners']),
      totalAttempts: _asInt(map['totalAttempts']),
      rankings: _asList(map['rankings'])
          .map((ranking) => _SimilarityEventRanking.fromMap(_asMap(ranking)))
          .toList(),
      averageTotalLearners: _asInt(map['averageTotalLearners']),
      averageTotalAttempts: _asInt(map['averageTotalAttempts']),
      averageRankings: _asList(map['averageRankings'])
          .map(
            (ranking) =>
                _SimilarityEventAverageRanking.fromMap(_asMap(ranking)),
          )
          .toList(),
      reportTotalLearners: _asInt(map['reportTotalLearners']),
      reportTotalReports: _asInt(map['reportTotalReports']),
      reportRankings: _asList(map['reportRankings'])
          .map((r) => _SimilarityEventReportRanking.fromMap(_asMap(r)))
          .toList(),
    );
  }
}

class _SimilarityEventInfo {
  const _SimilarityEventInfo({
    required this.eventId,
    required this.status,
    required this.contentSetId,
    required this.itemId,
    required this.expectedText,
    required this.startedAt,
    required this.endedAt,
  });

  final String eventId;
  final String status;
  final String contentSetId;
  final String itemId;
  final String expectedText;
  final String startedAt;
  final String endedAt;

  factory _SimilarityEventInfo.fromMap(Map<String, dynamic> map) {
    return _SimilarityEventInfo(
      eventId: map['eventId'] as String? ?? '',
      status: map['status'] as String? ?? '',
      contentSetId: map['contentSetId'] as String? ?? '',
      itemId: map['itemId'] as String? ?? '',
      expectedText: map['expectedText'] as String? ?? '',
      startedAt: map['startedAt'] as String? ?? '',
      endedAt: map['endedAt'] as String? ?? '',
    );
  }
}

class _SimilarityEventRanking {
  const _SimilarityEventRanking({
    required this.userId,
    required this.learnerName,
    required this.learnerPhone,
    required this.similarityScore,
    required this.passed,
    required this.evaluatedAt,
    required this.onDeviceFallback,
  });

  final String userId;
  final String learnerName;
  final String learnerPhone;
  final int similarityScore;
  final bool passed;
  final String evaluatedAt;
  final bool onDeviceFallback;

  String get evaluatedAtKst => _toKstDisplay(evaluatedAt);
  String get sourceLabel => onDeviceFallback ? '폰 전용' : '서버 우선';

  factory _SimilarityEventRanking.fromMap(Map<String, dynamic> map) {
    return _SimilarityEventRanking(
      userId: map['userId'] as String? ?? '',
      learnerName: map['learnerName'] as String? ?? '-',
      learnerPhone: map['learnerPhone'] as String? ?? '-',
      similarityScore: _asInt(map['similarityScore']),
      passed: map['passed'] as bool? ?? false,
      evaluatedAt: map['evaluatedAt'] as String? ?? '',
      onDeviceFallback: map['onDeviceFallback'] as bool? ?? false,
    );
  }
}

class _SimilarityEventAverageRanking {
  const _SimilarityEventAverageRanking({
    required this.userId,
    required this.learnerName,
    required this.learnerPhone,
    required this.averageSimilarity,
    required this.attemptCount,
    required this.latestEvaluatedAt,
  });

  final String userId;
  final String learnerName;
  final String learnerPhone;
  final int averageSimilarity;
  final int attemptCount;
  final String latestEvaluatedAt;

  String get latestEvaluatedAtKst => _toKstDisplay(latestEvaluatedAt);

  factory _SimilarityEventAverageRanking.fromMap(Map<String, dynamic> map) {
    return _SimilarityEventAverageRanking(
      userId: map['userId'] as String? ?? '',
      learnerName: map['learnerName'] as String? ?? '-',
      learnerPhone: map['learnerPhone'] as String? ?? '-',
      averageSimilarity: _asInt(map['averageSimilarity']),
      attemptCount: _asInt(map['attemptCount']),
      latestEvaluatedAt: map['latestEvaluatedAt'] as String? ?? '',
    );
  }
}

class _SimilarityEventReportRanking {
  const _SimilarityEventReportRanking({
    required this.userId,
    required this.learnerName,
    required this.learnerPhone,
    required this.averageSimilarity,
    required this.reportCount,
    required this.latestSubmittedAt,
  });

  final String userId;
  final String learnerName;
  final String learnerPhone;
  final int averageSimilarity;
  final int reportCount;
  final String latestSubmittedAt;

  String get latestSubmittedAtKst => _toKstDisplay(latestSubmittedAt);

  factory _SimilarityEventReportRanking.fromMap(Map<String, dynamic> map) {
    return _SimilarityEventReportRanking(
      userId: map['userId'] as String? ?? '',
      learnerName: map['learnerName'] as String? ?? '-',
      learnerPhone: map['learnerPhone'] as String? ?? '-',
      averageSimilarity: _asInt(map['averageSimilarity']),
      reportCount: _asInt(map['reportCount']),
      latestSubmittedAt: map['latestSubmittedAt'] as String? ?? '',
    );
  }
}

String _toKstDisplay(String? isoUtc) {
  if (isoUtc == null || isoUtc == '-' || isoUtc.isEmpty) return isoUtc ?? '-';
  final dt = DateTime.tryParse(isoUtc)?.toUtc();
  if (dt == null) return isoUtc;
  final kst = dt.add(const Duration(hours: 9));
  final mo = kst.month.toString().padLeft(2, '0');
  final d = kst.day.toString().padLeft(2, '0');
  final h = kst.hour.toString().padLeft(2, '0');
  final mi = kst.minute.toString().padLeft(2, '0');
  return '${kst.year}-$mo-$d $h:$mi (KST)';
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
