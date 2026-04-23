import 'package:flutter/material.dart';
import 'package:mission_app/l10n/app_localizations.dart';

class BootstrapScreen extends StatelessWidget {
  const BootstrapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 20),
            Text(l10n?.bootstrapMessage ?? 'Checking your learning status...'),
          ],
        ),
      ),
    );
  }
}
