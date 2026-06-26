import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/errors/app_error_messages.dart';
import '../../data/today_link_repository.dart';
import '../controllers/today_link_controller.dart';

/// 관리자가 그날 등록해 둔 외부 학습 링크를 외부 브라우저로 여는 빠른 액션.
/// 학습 세션 생성이나 리포트 집계와는 전혀 연동하지 않는다.
///
/// [isAdmin]이면 "날짜 지정" 버튼이 추가로 표시되어, 아직 오지 않은 미래 날짜에
/// 등록해 둔 링크도 미리 열어 확인할 수 있다(클릭 집계는 그 날짜로 기록됨).
class TodayLinkQuickAction extends ConsumerStatefulWidget {
  const TodayLinkQuickAction({super.key, this.isAdmin = false});

  final bool isAdmin;

  @override
  ConsumerState<TodayLinkQuickAction> createState() =>
      _TodayLinkQuickActionState();
}

class _TodayLinkQuickActionState extends ConsumerState<TodayLinkQuickAction> {
  bool _opening = false;
  DateTime? _testDate;

  String? get _testDateKey {
    final date = _testDate;
    if (date == null) {
      return null;
    }
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  Future<void> _pickTestDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _testDate ?? now,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(now.year + 2, 12, 31),
    );
    if (picked == null) {
      return;
    }
    setState(() => _testDate = picked);
  }

  Future<void> _openTodayLink() async {
    setState(() => _opening = true);
    try {
      final link = await ref
          .read(todayLinkControllerProvider.notifier)
          .fetchTodayLink(dateKey: _testDateKey);
      if (!mounted) {
        return;
      }
      if (!link.exists || link.url == null || link.url!.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _testDateKey == null
                  ? '오늘 등록된 학습 링크가 없습니다.'
                  : '${link.dateKey}에 등록된 학습 링크가 없습니다.',
            ),
          ),
        );
        return;
      }

      final uri = Uri.tryParse(link.url!);
      if (uri == null || !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('링크를 열 수 없습니다.')),
        );
        return;
      }
      unawaited(
        ref
            .read(todayLinkRepositoryProvider)
            .recordTodayLinkClick(dateKey: link.dateKey)
            .catchError((_) {}),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(toUserFacingErrorMessage(error))),
      );
    } finally {
      if (mounted) {
        setState(() => _opening = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final testDateKey = _testDateKey;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: _opening ? null : _openTodayLink,
              icon: _opening
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.open_in_browser),
              label: Text(
                _opening
                    ? '링크 확인 중...'
                    : testDateKey == null
                    ? '오늘의 링크 열기'
                    : '$testDateKey 링크 열기',
              ),
            ),
            if (widget.isAdmin) ...[
              OutlinedButton.icon(
                onPressed: _opening ? null : _pickTestDate,
                icon: const Icon(Icons.calendar_today_outlined),
                label: Text(testDateKey == null ? '날짜 지정' : '날짜 변경'),
              ),
              if (testDateKey != null)
                TextButton(
                  onPressed: _opening
                      ? null
                      : () => setState(() => _testDate = null),
                  child: const Text('오늘로 초기화'),
                ),
            ],
          ],
        ),
      ],
    );
  }
}
