import 'package:flutter/material.dart';
import 'package:mission_app/l10n/app_localizations.dart';

class StatusStateCard extends StatelessWidget {
  const StatusStateCard({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    required this.adminContact,
    this.primaryAction,
    this.secondaryAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String adminContact;
  final Widget? primaryAction;
  final Widget? secondaryAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, size: 40, color: theme.colorScheme.primary),
                  const SizedBox(height: 20),
                  Text(title, style: theme.textTheme.headlineMedium),
                  const SizedBox(height: 12),
                  Text(message, style: theme.textTheme.bodyLarge),
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n?.adminContactLabel ?? 'Admin Contact',
                          style: theme.textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(adminContact, style: theme.textTheme.bodyLarge),
                      ],
                    ),
                  ),
                  if (primaryAction != null) ...[
                    const SizedBox(height: 20),
                    SizedBox(width: double.infinity, child: primaryAction),
                  ],
                  if (secondaryAction != null) ...[
                    const SizedBox(height: 12),
                    SizedBox(width: double.infinity, child: secondaryAction),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
