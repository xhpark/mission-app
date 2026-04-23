import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mission_app/l10n/app_localizations.dart';

import '../../../../app/theme/app_colors.dart';
import '../controllers/auth_controller.dart';

class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authAction = ref.watch(authControllerProvider);
    final l10n = AppLocalizations.of(context);

    ref.listen(authControllerProvider, (previous, next) {
      next.whenOrNull(
        error: (error, _) {
          final message =
              l10n?.loginFailedWithError(error.toString()) ??
              'Login failed: $error';
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(message)));
        },
      );
    });

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: const BoxDecoration(
                          color: AppColors.primaryStrong,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.language, color: Colors.white),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        l10n?.loginTitle ?? 'Learner Login',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n?.loginSubtitle ??
                            'Use development mode login until phone auth is enabled.',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: authAction.isLoading
                            ? null
                            : () => ref
                                  .read(authControllerProvider.notifier)
                                  .enterDevelopmentMode(),
                        child: authAction.isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                l10n?.loginContinueForDevelopment ??
                                    'Continue for Development',
                              ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        l10n?.loginReleaseNote ??
                            'Phone authentication will be enabled in release.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
