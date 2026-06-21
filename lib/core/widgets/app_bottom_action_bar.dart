import 'package:flutter/material.dart';

import 'word_wrap_text.dart';

class AppBottomActionBar extends StatelessWidget {
  const AppBottomActionBar({
    super.key,
    required this.primaryLabel,
    required this.onPrimaryPressed,
    this.secondaryLabel,
    this.onSecondaryPressed,
    this.tertiaryLabel,
    this.onTertiaryPressed,
    this.primaryMinHeight = 52,
    this.primaryTextStyle,
    this.primaryBackgroundColor,
    this.primaryForegroundColor,
    this.primaryIcon,
  });

  final String primaryLabel;
  final VoidCallback? onPrimaryPressed;
  final String? secondaryLabel;
  final VoidCallback? onSecondaryPressed;
  final String? tertiaryLabel;
  final VoidCallback? onTertiaryPressed;
  final double primaryMinHeight;
  final TextStyle? primaryTextStyle;
  final Color? primaryBackgroundColor;
  final Color? primaryForegroundColor;
  final IconData? primaryIcon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      minimum: EdgeInsets.zero,
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
              blurRadius: 18,
              offset: const Offset(0, -6),
            ),
          ],
          border: Border(
            top: BorderSide(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.8),
            ),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
        child: Row(
          children: [
            if (secondaryLabel != null) ...[
              Expanded(
                child: OutlinedButton(
                  onPressed: onSecondaryPressed,
                  child: _ActionLabel(secondaryLabel!),
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: primaryIcon == null
                  ? ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        minimumSize: Size(0, primaryMinHeight),
                        backgroundColor: primaryBackgroundColor,
                        foregroundColor: primaryForegroundColor,
                      ),
                      onPressed: onPrimaryPressed,
                      child: _ActionLabel(
                        primaryLabel,
                        style: primaryTextStyle,
                      ),
                    )
                  : ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        minimumSize: Size(0, primaryMinHeight),
                        backgroundColor: primaryBackgroundColor,
                        foregroundColor: primaryForegroundColor,
                      ),
                      onPressed: onPrimaryPressed,
                      icon: Icon(primaryIcon, size: 22),
                      label: _ActionLabel(
                        primaryLabel,
                        style: primaryTextStyle,
                      ),
                    ),
            ),
            if (tertiaryLabel != null) ...[
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: onTertiaryPressed,
                  child: _ActionLabel(tertiaryLabel!),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ActionLabel extends StatelessWidget {
  const _ActionLabel(this.label, {this.style});

  final String label;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return WordWrapText(
      label,
      style: style,
      textAlign: TextAlign.center,
      spacing: 6,
      runSpacing: 2,
    );
  }
}
