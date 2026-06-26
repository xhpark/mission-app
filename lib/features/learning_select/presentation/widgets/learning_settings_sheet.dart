import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/learning_preferences_controller.dart';

/// 학습 환경설정을 토글하는 가벼운 바텀시트. 현재는 자동 스크롤 토글만 노출한다.
class LearningSettingsSheet extends ConsumerWidget {
  const LearningSettingsSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => const LearningSettingsSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(learningPreferencesProvider);
    final controller = ref.read(learningPreferencesProvider.notifier);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
              child: Text(
                '학습 설정',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              value: prefs.autoScrollEnabled,
              onChanged: (value) =>
                  controller.setAutoScrollEnabled(value),
              title: const Text('다음 버튼 자동으로 보이기'),
              subtitle: const Text(
                '문장 학습에서 내용을 읽을 시간이 지나면 다음 버튼이 보이도록 자동으로 살짝 내려줍니다.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
