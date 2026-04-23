import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mission_app/l10n/app_localizations.dart';

class StudyModePlaceholderScreen extends StatelessWidget {
  const StudyModePlaceholderScreen({
    super.key,
    required this.title,
    required this.description,
    this.primaryLabel,
    this.primaryRoute,
  });

  final String title;
  final String description;
  final String? primaryLabel;
  final String? primaryRoute;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                description,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => context.go('/select'),
                child: Text(
                  l10n?.studyModeBackToSelection ?? 'Back to Selection',
                ),
              ),
            ),
            if (primaryLabel != null && primaryRoute != null) ...[
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => context.go(primaryRoute!),
                  child: Text(primaryLabel!),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
