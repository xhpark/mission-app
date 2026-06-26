import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

/// Tiny one-line reference summary of the learner's current selection
/// (e.g. "일상회화, 초급, 문장학습"), shown at the top of a learning/test
/// screen. Purely informational — small and unobtrusive red text so it
/// doesn't compete with the screen's actual content.
class SelectionSummaryLine extends StatelessWidget {
  const SelectionSummaryLine({super.key, required this.labels});

  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    return Text(
      labels.join(', '),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        fontSize: 12,
        color: AppColors.error,
        fontWeight: FontWeight.w400,
      ),
    );
  }
}
