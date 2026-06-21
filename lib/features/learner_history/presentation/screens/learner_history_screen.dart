import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/firebase/firebase_providers.dart';
import '../../../../core/firebase/firebase_services.dart';
import '../../../../core/widgets/app_section_card.dart';
import '../../../../core/widgets/app_status_banner.dart';

class LearnerHistoryScreen extends ConsumerStatefulWidget {
  const LearnerHistoryScreen({super.key});

  @override
  ConsumerState<LearnerHistoryScreen> createState() =>
      _LearnerHistoryScreenState();
}

class _LearnerHistoryScreenState extends ConsumerState<LearnerHistoryScreen> {
  Future<_LearnerHistoryData>? _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_LearnerHistoryData> _load() async {
    final user = ref.read(authStateChangesProvider).asData?.value;
    final developmentSession = ref.read(developmentSessionProvider);
    if (user == null || user.isAnonymous || developmentSession) {
      throw StateError('학습 기록은 로그인 계정에서만 확인할 수 있습니다.');
    }
    final result = await ref
        .read(firebaseFunctionsProvider)
        .httpsCallable('getLearnerHistory')
        .call(<String, dynamic>{'userId': user.uid});
    return _LearnerHistoryData.fromMap(_asMap(result.data));
  }

  void _refresh() {
    setState(() {
      _future = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('내 학습 기록'),
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
      body: FutureBuilder<_LearnerHistoryData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                AppStatusBanner(
                  isError: true,
                  icon: Icons.history,
                  message: '학습 기록을 불러오지 못했습니다.\n${snapshot.error}',
                ),
              ],
            );
          }

          final data = snapshot.requireData;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _RankingCard(ranking: data.ranking),
                const SizedBox(height: 12),
                _SummaryCard(summary: data.summary),
                const SizedBox(height: 12),
                _SpeakingCard(records: data.speaking),
                const SizedBox(height: 12),
                _TrendCard(daily: data.dailyTrend, weekly: data.weeklyTrend),
                const SizedBox(height: 12),
                _ReportsCard(reports: data.reports),
                const SizedBox(height: 16),
                if (data.generatedAt.isNotEmpty)
                  Text(
                    '조회 시각: ${_formatIso(data.generatedAt)}',
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

class _RankingCard extends StatelessWidget {
  const _RankingCard({required this.ranking});

  final _Ranking ranking;

  @override
  Widget build(BuildContext context) {
    return AppSectionCard(
      title: '나의 순위',
      description: '전체 학습자 중 내 위치입니다.',
      icon: Icons.emoji_events_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _RankRow(
            label: '학습량 순위',
            rankText: _rankText(ranking.learningVolumeRank, ranking.totalLearners),
            detail: '완료 항목 ${ranking.myCompletedItems}개',
          ),
          const SizedBox(height: 10),
          _RankRow(
            label: '말하기 유사도 순위',
            rankText:
                _rankText(ranking.similarityRank, ranking.similarityRankTotal),
            detail: ranking.myAverageSimilarity == null
                ? '평가 기록 없음'
                : '평균 유사도 ${ranking.myAverageSimilarity}%',
          ),
        ],
      ),
    );
  }
}

class _RankRow extends StatelessWidget {
  const _RankRow({
    required this.label,
    required this.rankText,
    required this.detail,
  });

  final String label;
  final String rankText;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 2),
              Text(detail, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        Text(
          rankText,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: colorScheme.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.summary});

  final _Summary summary;

  @override
  Widget build(BuildContext context) {
    return AppSectionCard(
      title: '누적 통계 요약',
      icon: Icons.insights_outlined,
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          _StatChip(label: '총 세션', value: '${summary.sessions}회'),
          _StatChip(label: '완료 항목', value: '${summary.completedItems}개'),
          _StatChip(label: '누적 학습 시간', value: '${summary.durationMinutes}분'),
          _StatChip(label: '평균 정확도', value: _percent(summary.accuracy)),
          _StatChip(label: '평균 말하기 유사도', value: _percent(summary.averageSimilarity)),
          _StatChip(label: '평균 완료율', value: _percent(summary.completionAverage)),
          _StatChip(label: '말하기 통과율', value: _percent(summary.speakingPassRate)),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: 160,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 6),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SpeakingCard extends StatelessWidget {
  const _SpeakingCard({required this.records});

  final List<_SpeakingRecord> records;

  @override
  Widget build(BuildContext context) {
    return AppSectionCard(
      title: '말하기(발음) 기록',
      description: '말하기 평가가 포함된 세션의 결과입니다.',
      icon: Icons.mic_none_outlined,
      child: records.isEmpty
          ? const Text('아직 말하기 평가 기록이 없습니다.')
          : Column(
              children: [
                for (final r in records) ...[
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${r.dateKey.isNotEmpty ? r.dateKey : _formatIso(r.submittedAt)} · ${_categoryLabel(r.category)} ${_levelLabel(r.level)}',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '통과 ${r.passedCount}/${r.attemptCount} · 통과율 ${_percent(r.passRate)}'
                              '${r.sttFailureCount > 0 ? ' · 인식실패 ${r.sttFailureCount}' : ''}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      Text(
                        _percent(r.averageSimilarity),
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 18),
                ],
              ],
            ),
    );
  }
}

class _TrendCard extends StatelessWidget {
  const _TrendCard({required this.daily, required this.weekly});

  final List<_TrendEntry> daily;
  final List<_TrendEntry> weekly;

  @override
  Widget build(BuildContext context) {
    return AppSectionCard(
      title: '진도 추이',
      description: '일별 / 주별 학습량입니다.',
      icon: Icons.timeline_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('일별 (최근 ${daily.length}일)',
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 6),
          if (daily.isEmpty)
            const Text('기록이 없습니다.')
          else
            for (final e in daily)
              _TrendRow(
                label: e.key,
                detail:
                    '세션 ${e.sessions} · 항목 ${e.completedItems} · ${e.durationMinutes}분',
              ),
          const SizedBox(height: 14),
          Text('주별 (최근 ${weekly.length}주)',
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 6),
          if (weekly.isEmpty)
            const Text('기록이 없습니다.')
          else
            for (final e in weekly)
              _TrendRow(
                label: e.key,
                detail:
                    '세션 ${e.sessions} · 항목 ${e.completedItems} · ${e.durationMinutes}분',
              ),
        ],
      ),
    );
  }
}

class _TrendRow extends StatelessWidget {
  const _TrendRow({required this.label, required this.detail});

  final String label;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          Expanded(
            child: Text(detail, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}

class _ReportsCard extends StatelessWidget {
  const _ReportsCard({required this.reports});

  final List<_ReportEntry> reports;

  @override
  Widget build(BuildContext context) {
    return AppSectionCard(
      title: '지난 리포트',
      description: '최근 제출한 리포트입니다.',
      icon: Icons.description_outlined,
      child: reports.isEmpty
          ? const Text('아직 제출한 리포트가 없습니다.')
          : Column(
              children: [
                for (final r in reports) ...[
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${r.dateKey.isNotEmpty ? r.dateKey : _formatIso(r.submittedAt)} · ${_categoryLabel(r.category)} ${_levelLabel(r.level)}',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '완료 ${r.completedItems}/${r.totalItems} · 완료율 ${_percent(r.completionRate)}'
                              ' · 정확도 ${_percent(r.accuracy)}'
                              '${r.averageSimilarity != null ? ' · 유사도 ${_percent(r.averageSimilarity)}' : ''}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 18),
                ],
              ],
            ),
    );
  }
}

// ---- data models ----

class _LearnerHistoryData {
  const _LearnerHistoryData({
    required this.generatedAt,
    required this.summary,
    required this.ranking,
    required this.reports,
    required this.speaking,
    required this.dailyTrend,
    required this.weeklyTrend,
  });

  final String generatedAt;
  final _Summary summary;
  final _Ranking ranking;
  final List<_ReportEntry> reports;
  final List<_SpeakingRecord> speaking;
  final List<_TrendEntry> dailyTrend;
  final List<_TrendEntry> weeklyTrend;

  factory _LearnerHistoryData.fromMap(Map<String, dynamic> map) {
    return _LearnerHistoryData(
      generatedAt: (map['generatedAt'] ?? '').toString(),
      summary: _Summary.fromMap(_asMap(map['summary'])),
      ranking: _Ranking.fromMap(_asMap(map['ranking'])),
      reports: _asList(map['reports'])
          .map((e) => _ReportEntry.fromMap(_asMap(e)))
          .toList(),
      speaking: _asList(map['speaking'])
          .map((e) => _SpeakingRecord.fromMap(_asMap(e)))
          .toList(),
      dailyTrend: _asList(map['dailyTrend'])
          .map((e) => _TrendEntry.fromMap(_asMap(e), 'dateKey'))
          .toList(),
      weeklyTrend: _asList(map['weeklyTrend'])
          .map((e) => _TrendEntry.fromMap(_asMap(e), 'weekKey'))
          .toList(),
    );
  }
}

class _Summary {
  const _Summary({
    required this.sessions,
    required this.completedItems,
    required this.durationMinutes,
    required this.accuracy,
    required this.averageSimilarity,
    required this.completionAverage,
    required this.speakingPassRate,
  });

  final int sessions;
  final int completedItems;
  final int durationMinutes;
  final num? accuracy;
  final num? averageSimilarity;
  final num? completionAverage;
  final num? speakingPassRate;

  factory _Summary.fromMap(Map<String, dynamic> map) {
    return _Summary(
      sessions: _int(map['sessions']),
      completedItems: _int(map['completedItems']),
      durationMinutes: _int(map['durationMinutes']),
      accuracy: _numOrNull(map['accuracy']),
      averageSimilarity: _numOrNull(map['averageSimilarity']),
      completionAverage: _numOrNull(map['completionAverage']),
      speakingPassRate: _numOrNull(map['speakingPassRate']),
    );
  }
}

class _Ranking {
  const _Ranking({
    required this.totalLearners,
    required this.learningVolumeRank,
    required this.myCompletedItems,
    required this.similarityRank,
    required this.similarityRankTotal,
    required this.myAverageSimilarity,
  });

  final int totalLearners;
  final int? learningVolumeRank;
  final int myCompletedItems;
  final int? similarityRank;
  final int similarityRankTotal;
  final num? myAverageSimilarity;

  factory _Ranking.fromMap(Map<String, dynamic> map) {
    return _Ranking(
      totalLearners: _int(map['totalLearners']),
      learningVolumeRank: _intOrNull(map['learningVolumeRank']),
      myCompletedItems: _int(map['myCompletedItems']),
      similarityRank: _intOrNull(map['similarityRank']),
      similarityRankTotal: _int(map['similarityRankTotal']),
      myAverageSimilarity: _numOrNull(map['myAverageSimilarity']),
    );
  }
}

class _ReportEntry {
  const _ReportEntry({
    required this.submittedAt,
    required this.dateKey,
    required this.category,
    required this.level,
    required this.totalItems,
    required this.completedItems,
    required this.completionRate,
    required this.accuracy,
    required this.averageSimilarity,
  });

  final String submittedAt;
  final String dateKey;
  final String category;
  final String level;
  final int totalItems;
  final int completedItems;
  final num? completionRate;
  final num? accuracy;
  final num? averageSimilarity;

  factory _ReportEntry.fromMap(Map<String, dynamic> map) {
    return _ReportEntry(
      submittedAt: (map['submittedAt'] ?? '').toString(),
      dateKey: (map['dateKey'] ?? '').toString(),
      category: (map['category'] ?? '').toString(),
      level: (map['level'] ?? '').toString(),
      totalItems: _int(map['totalItems']),
      completedItems: _int(map['completedItems']),
      completionRate: _numOrNull(map['completionRate']),
      accuracy: _numOrNull(map['accuracy']),
      averageSimilarity: _numOrNull(map['averageSimilarity']),
    );
  }
}

class _SpeakingRecord {
  const _SpeakingRecord({
    required this.submittedAt,
    required this.dateKey,
    required this.category,
    required this.level,
    required this.attemptCount,
    required this.passedCount,
    required this.passRate,
    required this.averageSimilarity,
    required this.sttFailureCount,
  });

  final String submittedAt;
  final String dateKey;
  final String category;
  final String level;
  final int attemptCount;
  final int passedCount;
  final num? passRate;
  final num? averageSimilarity;
  final int sttFailureCount;

  factory _SpeakingRecord.fromMap(Map<String, dynamic> map) {
    return _SpeakingRecord(
      submittedAt: (map['submittedAt'] ?? '').toString(),
      dateKey: (map['dateKey'] ?? '').toString(),
      category: (map['category'] ?? '').toString(),
      level: (map['level'] ?? '').toString(),
      attemptCount: _int(map['attemptCount']),
      passedCount: _int(map['passedCount']),
      passRate: _numOrNull(map['passRate']),
      averageSimilarity: _numOrNull(map['averageSimilarity']),
      sttFailureCount: _int(map['sttFailureCount']),
    );
  }
}

class _TrendEntry {
  const _TrendEntry({
    required this.key,
    required this.sessions,
    required this.completedItems,
    required this.durationMinutes,
  });

  final String key;
  final int sessions;
  final int completedItems;
  final int durationMinutes;

  factory _TrendEntry.fromMap(Map<String, dynamic> map, String keyField) {
    return _TrendEntry(
      key: (map[keyField] ?? '').toString(),
      sessions: _int(map['sessions']),
      completedItems: _int(map['completedItems']),
      durationMinutes: _int(map['durationMinutes']),
    );
  }
}

// ---- helpers ----

Map<String, dynamic> _asMap(Object? value) {
  if (value is Map) {
    return value.map((key, value) => MapEntry(key.toString(), value));
  }
  return <String, dynamic>{};
}

List<Object?> _asList(Object? value) {
  if (value is List) {
    return value;
  }
  return const [];
}

int _int(Object? value) => _numOrNull(value)?.round() ?? 0;

int? _intOrNull(Object? value) => _numOrNull(value)?.round();

num? _numOrNull(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is num) {
    return value;
  }
  return num.tryParse(value.toString());
}

String _percent(num? value) => value == null ? '-' : '${value.round()}%';

String _rankText(int? rank, int total) {
  if (rank == null || total <= 0) {
    return '-';
  }
  return '$rank / $total위';
}

String _categoryLabel(String category) {
  switch (category) {
    case 'daily':
      return '일상 회화';
    case 'mission':
      return '선교';
    default:
      return category;
  }
}

String _levelLabel(String level) {
  switch (level) {
    case 'beginner':
      return '초급';
    case 'intermediate':
      return '중급';
    case 'advanced':
      return '고급';
    default:
      return level;
  }
}

String _formatIso(String iso) {
  if (iso.isEmpty) {
    return '-';
  }
  final dt = DateTime.tryParse(iso);
  if (dt == null) {
    return iso;
  }
  final local = dt.toLocal();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}';
}
