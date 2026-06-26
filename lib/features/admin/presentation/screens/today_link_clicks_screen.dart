import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/app_error_messages.dart';
import '../../../../core/firebase/firebase_providers.dart';
import '../../../../core/widgets/app_bottom_action_bar.dart';
import '../../../../core/widgets/app_section_card.dart';
import '../../../../core/widgets/app_status_banner.dart';
import '../../../learning_select/data/today_link_repository.dart';

class TodayLinkClicksScreen extends ConsumerStatefulWidget {
  const TodayLinkClicksScreen({super.key});

  @override
  ConsumerState<TodayLinkClicksScreen> createState() =>
      _TodayLinkClicksScreenState();
}

class _TodayLinkClicksScreenState extends ConsumerState<TodayLinkClicksScreen> {
  DateTime _selectedDate = DateTime.now();
  bool _loading = true;
  String? _errorMessage;
  TodayLinkClicks? _clicks;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String get _selectedDateKey {
    final y = _selectedDate.year.toString().padLeft(4, '0');
    final m = _selectedDate.month.toString().padLeft(2, '0');
    final d = _selectedDate.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  Future<void> _load() async {
    final user = ref.read(authStateChangesProvider).asData?.value;
    if (user == null) {
      return;
    }
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final clicks = await ref
          .read(todayLinkRepositoryProvider)
          .getTodayLinkClicks(adminUserId: user.uid, dateKey: _selectedDateKey);
      if (!mounted) {
        return;
      }
      setState(() {
        _clicks = clicks;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = toUserFacingErrorMessage(error);
        _loading = false;
      });
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(_selectedDate.year + 2, 12, 31),
    );
    if (picked == null) {
      return;
    }
    setState(() => _selectedDate = picked);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final clicks = _clicks;
    return Scaffold(
      appBar: AppBar(title: const Text('오늘의 학습/복습 링크')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_today_outlined),
                label: Text('날짜 선택: $_selectedDateKey'),
              ),
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (_errorMessage != null)
              AppStatusBanner(
                isError: true,
                icon: Icons.error_outline,
                message: _errorMessage!,
              )
            else if (clicks != null) ...[
              AppSectionCard(
                title: clicks.dateKey,
                description:
                    '클릭한 학습자 수: ${clicks.totalLearners}명 / 총 클릭 ${clicks.totalClicks}회 (이름 가나다순)',
                icon: Icons.touch_app_outlined,
                child: clicks.learners.isEmpty
                    ? const Text('해당 날짜에 링크를 클릭한 학습자가 없습니다.')
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final learner in clicks.learners)
                            ExpansionTile(
                              tilePadding: EdgeInsets.zero,
                              leading: const Icon(Icons.person_outline),
                              title: Text(learner.name),
                              subtitle: Text(learner.email),
                              trailing: Text('${learner.clickCount}회'),
                              children: [
                                for (final time in learner.clickedAt)
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      left: 16,
                                      bottom: 4,
                                    ),
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text(_formatTime(time)),
                                    ),
                                  ),
                              ],
                            ),
                        ],
                      ),
              ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: AppBottomActionBar(
        secondaryLabel: '뒤로가기',
        onSecondaryPressed: () {
          if (Navigator.of(context).canPop()) {
            context.pop();
          } else {
            context.go('/select');
          }
        },
        primaryLabel: '학습 선택으로 돌아가기',
        onPrimaryPressed: () => context.go('/select'),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final local = time.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
