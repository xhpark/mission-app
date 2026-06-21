import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

class LearningActionStyles {
  const LearningActionStyles._();

  static ButtonStyle prominentOutlined(BuildContext context) {
    final theme = Theme.of(context);
    final disabledForeground = theme.colorScheme.onSurface.withValues(
      alpha: 0.45,
    );

    return OutlinedButton.styleFrom(
      minimumSize: const Size(0, 56),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      backgroundColor: AppColors.action,
      foregroundColor: theme.colorScheme.onPrimary,
      disabledBackgroundColor: theme.colorScheme.surfaceContainerHighest,
      disabledForegroundColor: disabledForeground,
      textStyle: theme.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w800,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ).copyWith(
      side: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return BorderSide(color: theme.colorScheme.outlineVariant);
        }
        return const BorderSide(color: AppColors.action, width: 1.4);
      }),
    );
  }
}
