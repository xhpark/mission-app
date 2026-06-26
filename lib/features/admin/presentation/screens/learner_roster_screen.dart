import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/app_error_messages.dart';
import '../../../../core/firebase/firebase_providers.dart';
import '../../../../core/widgets/app_bottom_action_bar.dart';
import '../../../../core/widgets/app_section_card.dart';
import '../../../../core/widgets/app_status_banner.dart';
import '../../data/learner_roster_repository.dart';

class LearnerRosterScreen extends ConsumerStatefulWidget {
  const LearnerRosterScreen({super.key});

  @override
  ConsumerState<LearnerRosterScreen> createState() =>
      _LearnerRosterScreenState();
}

class _LearnerRosterScreenState extends ConsumerState<LearnerRosterScreen> {
  final _bulkInputController = TextEditingController();
  bool _loading = true;
  bool _adding = false;
  String? _errorMessage;
  String? _actionMessage;
  List<LearnerRosterEntry> _entries = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _bulkInputController.dispose();
    super.dispose();
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
      final entries = await ref
          .read(learnerRosterRepositoryProvider)
          .getRoster(adminUserId: user.uid);
      if (!mounted) {
        return;
      }
      setState(() {
        _entries = entries;
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

  Future<void> _addEntries() async {
    final user = ref.read(authStateChangesProvider).asData?.value;
    if (user == null) {
      return;
    }
    final parsed = <({String name, String phone})>[];
    for (final rawLine in _bulkInputController.text.split('\n')) {
      final line = rawLine.trim();
      if (line.isEmpty) {
        continue;
      }
      final parts = line.split(',');
      if (parts.length < 2) {
        continue;
      }
      final name = parts[0].trim();
      final phone = parts.sublist(1).join(',').trim();
      if (name.isEmpty || phone.isEmpty) {
        continue;
      }
      parsed.add((name: name, phone: phone));
    }
    if (parsed.isEmpty) {
      setState(() {
        _actionMessage = null;
        _errorMessage = '"이름,전화번호" 형식으로 한 줄에 한 명씩 입력해 주세요.';
      });
      return;
    }

    setState(() {
      _adding = true;
      _errorMessage = null;
      _actionMessage = null;
    });
    try {
      final result = await ref
          .read(learnerRosterRepositoryProvider)
          .addEntries(adminUserId: user.uid, entries: parsed);
      if (!mounted) {
        return;
      }
      _bulkInputController.clear();
      setState(() {
        _actionMessage =
            '신규 ${result.added}명 추가, 기존 ${result.updated}명 정보 갱신';
      });
      await _load();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _errorMessage = toUserFacingErrorMessage(error));
    } finally {
      if (mounted) {
        setState(() => _adding = false);
      }
    }
  }

  Future<void> _deleteEntry(LearnerRosterEntry entry) async {
    final user = ref.read(authStateChangesProvider).asData?.value;
    if (user == null) {
      return;
    }
    try {
      await ref
          .read(learnerRosterRepositoryProvider)
          .deleteEntry(adminUserId: user.uid, rosterId: entry.rosterId);
      await _load();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(toUserFacingErrorMessage(error))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final notRegistered = _entries
        .where((e) => e.status == LearnerRosterStatus.notRegistered)
        .toList();
    final pending = _entries
        .where((e) => e.status == LearnerRosterStatus.pendingApproval)
        .toList();
    final approved = _entries
        .where((e) => e.status == LearnerRosterStatus.approved)
        .toList();
    final blocked = _entries
        .where((e) => e.status == LearnerRosterStatus.blocked)
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('학습자 명단 관리')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          children: [
            AppSectionCard(
              title: '명단 일괄 등록',
              description:
                  '한 줄에 한 명씩 "이름,전화번호" 형식으로 입력하세요. 이미 등록된 전화번호는 이름만 갱신됩니다.',
              icon: Icons.group_add_outlined,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _bulkInputController,
                    maxLines: 6,
                    decoration: const InputDecoration(
                      hintText: '김선교,01012345678\n이은혜,01098765432',
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_errorMessage != null) ...[
                    AppStatusBanner(
                      isError: true,
                      icon: Icons.error_outline,
                      message: _errorMessage!,
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (_actionMessage != null) ...[
                    AppStatusBanner(
                      icon: Icons.check_circle_outline,
                      message: _actionMessage!,
                    ),
                    const SizedBox(height: 12),
                  ],
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton(
                      onPressed: _adding ? null : _addEntries,
                      child: Text(_adding ? '등록 중...' : '명단에 추가'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else
              AppSectionCard(
                title: '명단 현황',
                description:
                    '전체 ${_entries.length}명 · 미가입 ${notRegistered.length}명 · '
                    '승인대기 ${pending.length}명 · 승인됨 ${approved.length}명'
                    '${blocked.isEmpty ? '' : ' · 이용제한 ${blocked.length}명'}',
                icon: Icons.fact_check_outlined,
                child: _entries.isEmpty
                    ? const Text('등록된 명단이 없습니다.')
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final entry in _entries)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: _statusIcon(entry.status),
                              title: Text(entry.name),
                              subtitle: Text(
                                entry.matchedEmail == null
                                    ? entry.phone
                                    : '${entry.phone} · ${entry.matchedEmail}',
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(_statusLabel(entry.status)),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline),
                                    tooltip: '명단에서 삭제',
                                    onPressed: () => _deleteEntry(entry),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
              ),
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

  Widget _statusIcon(LearnerRosterStatus status) => switch (status) {
    LearnerRosterStatus.notRegistered => const Icon(
      Icons.person_off_outlined,
      color: Colors.grey,
    ),
    LearnerRosterStatus.pendingApproval => const Icon(
      Icons.hourglass_empty,
      color: Colors.orange,
    ),
    LearnerRosterStatus.approved => const Icon(
      Icons.check_circle_outline,
      color: Colors.green,
    ),
    LearnerRosterStatus.blocked => const Icon(
      Icons.block,
      color: Colors.red,
    ),
  };

  String _statusLabel(LearnerRosterStatus status) => switch (status) {
    LearnerRosterStatus.notRegistered => '미가입',
    LearnerRosterStatus.pendingApproval => '승인대기',
    LearnerRosterStatus.approved => '승인됨',
    LearnerRosterStatus.blocked => '이용제한',
  };
}
