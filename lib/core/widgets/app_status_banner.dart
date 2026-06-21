import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

enum AppStatusTone { info, success, warning, error }

class AppStatusBanner extends StatelessWidget {
  const AppStatusBanner({
    super.key,
    required this.message,
    this.icon,
    this.tone = AppStatusTone.info,
    this.isError = false,
  });

  final String message;
  final IconData? icon;
  final AppStatusTone tone;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final effectiveTone = isError ? AppStatusTone.error : tone;
    final ({Color bg, Color fg, IconData icon}) palette =
        switch (effectiveTone) {
          AppStatusTone.success => (
            bg: const Color(0xFFEAF7EF),
            fg: AppColors.success,
            icon: Icons.check_circle_outline,
          ),
          AppStatusTone.warning => (
            bg: const Color(0xFFFFF7ED),
            fg: AppColors.warning,
            icon: Icons.warning_amber_rounded,
          ),
          AppStatusTone.error => (
            bg: scheme.errorContainer,
            fg: scheme.onErrorContainer,
            icon: Icons.error_outline,
          ),
          AppStatusTone.info => (
            bg: AppColors.primarySoft,
            fg: AppColors.primaryStrong,
            icon: Icons.info_outline,
          ),
        };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.bg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.fg.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon ?? palette.icon, color: palette.fg, size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: palette.fg),
            ),
          ),
        ],
      ),
    );
  }
}
