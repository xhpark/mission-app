import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mission_app/l10n/app_localizations.dart';

import '../../../../core/errors/app_error_messages.dart';
import '../../../../core/firebase/firebase_providers.dart';
import '../controllers/bootstrap_controller.dart';

class BootstrapScreen extends ConsumerWidget {
  const BootstrapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final bootstrapState = ref.watch(bootstrapControllerProvider);
    final message = l10n?.bootstrapMessage ?? '학습 상태를 확인하는 중입니다...';

    return bootstrapState.when(
      loading: () => _BootstrapLoading(message: message),
      error: (error, _) => _BootstrapError(error: error),
      data: (_) => _BootstrapLoading(message: message),
    );
  }
}

class _BootstrapLoading extends StatelessWidget {
  const _BootstrapLoading({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 20),
                Text(message, textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BootstrapError extends ConsumerWidget {
  const _BootstrapError({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          children: [
            const SizedBox(height: 40),
            const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
            const SizedBox(height: 16),
            const Text(
              '앱 시작 중 오류가 발생했습니다.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              toUserFacingErrorMessage(error),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 20),
            Center(
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton.icon(
                    onPressed: () =>
                        ref.invalidate(bootstrapControllerProvider),
                    icon: const Icon(Icons.refresh),
                    label: const Text('다시 시도'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () async {
                      await ref.read(firebaseAuthProvider).signOut();
                      ref.invalidate(bootstrapControllerProvider);
                    },
                    icon: const Icon(Icons.login),
                    label: const Text('로그인 화면으로 이동'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
