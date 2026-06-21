import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mission_app/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../app/theme/app_colors.dart';
import '../controllers/auth_controller.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  static const _rememberEmailEnabledKey = 'auth.remember_email.enabled';
  static const _rememberedEmailKey = 'auth.remember_email.value';

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _rememberEmail = false;
  bool _rememberedEmailLoaded = false;
  bool _creatingAccount = false;

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_persistEmailIfRemembered);
    unawaited(_loadRememberedEmail());
  }

  @override
  void dispose() {
    _emailController.removeListener(_persistEmailIfRemembered);
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authAction = ref.watch(authControllerProvider);
    final l10n = AppLocalizations.of(context);

    ref.listen(authControllerProvider, (previous, next) {
      next.whenOrNull(
        error: (error, _) {
          _showSnackBar(_authErrorMessage(error, l10n));
        },
      );
    });

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
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
                        _creatingAccount
                            ? '계정 만들기'
                            : l10n?.loginTitle ?? '학습자 로그인',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _creatingAccount
                            ? '이름과 전화번호는 관리자 승인과 계정 찾기에 사용됩니다.'
                            : '이메일과 비밀번호로 로그인해 주세요.',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 20),
                      if (_creatingAccount) ...[
                        TextField(
                          controller: _nameController,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.name],
                          decoration: const InputDecoration(
                            labelText: '이름',
                            helperText: '계정 만들기에 필요한 입력입니다.',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.telephoneNumber],
                          decoration: const InputDecoration(
                            labelText: '전화번호',
                            helperText: '계정 만들기와 이메일 찾기에 필요한 입력입니다.',
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.email],
                        decoration: const InputDecoration(
                          labelText: '이메일',
                          hintText: 'email@example.com',
                        ),
                      ),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        value: _rememberEmail,
                        onChanged: authAction.isLoading
                            ? null
                            : (value) {
                                setState(() {
                                  _rememberEmail = value ?? false;
                                });
                                unawaited(_persistRememberedEmail());
                              },
                        title: const Text('이메일 저장'),
                        subtitle: const Text('다음 로그인 때 이메일을 자동으로 입력합니다.'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _passwordController,
                        obscureText: true,
                        autofillHints: const [AutofillHints.password],
                        decoration: const InputDecoration(labelText: '비밀번호'),
                        onSubmitted: (_) => _signInWithEmail(),
                      ),
                      const SizedBox(height: 20),
                      if (_creatingAccount)
                        _CreateAccountActions(
                          authAction: authAction,
                          onCreateAccount: _createAccountWithEmail,
                          onBackToLogin: () {
                            setState(() {
                              _creatingAccount = false;
                            });
                          },
                        )
                      else
                        _LoginActions(
                          authAction: authAction,
                          onSignIn: _signInWithEmail,
                          onCreateAccount: () {
                            setState(() {
                              _creatingAccount = true;
                            });
                          },
                          onRecoverAccount: _showAccountRecoveryDialog,
                        ),
                      if (kDebugMode) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: authAction.isLoading
                                ? null
                                : () => ref
                                      .read(authControllerProvider.notifier)
                                      .signInForDevelopment(),
                            icon: const Icon(Icons.construction_outlined),
                            label: Text(
                              l10n?.loginContinueForDevelopment ?? '개발용으로 계속하기',
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'QA 계정: xhpark.app.qa@gmail.com\n실사용 테스트 계정: xhpark65@gmail.com',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                      if (authAction.isLoading) ...[
                        const SizedBox(height: 16),
                        const LinearProgressIndicator(),
                      ],
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

  Future<void> _loadRememberedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    final rememberEmail = prefs.getBool(_rememberEmailEnabledKey) ?? false;
    final rememberedEmail = prefs.getString(_rememberedEmailKey) ?? '';
    if (!mounted) {
      return;
    }
    final currentEmail = _emailController.text.trim();
    setState(() {
      _rememberEmail = rememberEmail;
      _rememberedEmailLoaded = true;
      if (rememberEmail && rememberedEmail.isNotEmpty && currentEmail.isEmpty) {
        _emailController.text = rememberedEmail;
      }
    });
  }

  void _persistEmailIfRemembered() {
    if (!_rememberEmail || !_rememberedEmailLoaded) {
      return;
    }
    unawaited(_persistRememberedEmail());
  }

  Future<void> _persistRememberedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_rememberEmailEnabledKey, _rememberEmail);
    if (_rememberEmail) {
      await prefs.setString(_rememberedEmailKey, _emailController.text.trim());
      return;
    }
    await prefs.remove(_rememberedEmailKey);
  }

  Future<void> _signInWithEmail() async {
    if (!_validateEmailAndPassword()) {
      return;
    }
    await _persistRememberedEmail();
    await ref
        .read(authControllerProvider.notifier)
        .signInWithEmail(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
  }

  Future<void> _createAccountWithEmail() async {
    if (!_validateEmailAndPassword() || !_validateProfileFields()) {
      return;
    }
    await _persistRememberedEmail();
    await ref
        .read(authControllerProvider.notifier)
        .createAccountWithEmail(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          learnerName: _nameController.text.trim(),
          learnerPhone: _phoneController.text.trim(),
        );
  }

  Future<void> _showAccountRecoveryDialog() async {
    final recoveryNameController = TextEditingController(
      text: _nameController.text.trim(),
    );
    final recoveryPhoneController = TextEditingController(
      text: _phoneController.text.trim(),
    );
    final resetEmailController = TextEditingController(
      text: _emailController.text.trim(),
    );

    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          var submitting = false;
          return StatefulBuilder(
            builder: (context, setDialogState) {
              Future<void> runDialogAction(
                Future<void> Function() action,
              ) async {
                setDialogState(() {
                  submitting = true;
                });
                try {
                  await action();
                } finally {
                  if (context.mounted) {
                    setDialogState(() {
                      submitting = false;
                    });
                  }
                }
              }

              return AlertDialog(
                title: const Text('계정 찾기'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('비밀번호를 잊으셨다면 가입한 이메일로 재설정 메일을 받을 수 있습니다.'),
                      const SizedBox(height: 12),
                      TextField(
                        controller: resetEmailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: '비밀번호 재설정 이메일',
                        ),
                      ),
                      const Divider(height: 32),
                      const Text('이메일을 잊으셨다면 가입할 때 입력한 이름과 전화번호로 찾을 수 있습니다.'),
                      const SizedBox(height: 12),
                      TextField(
                        controller: recoveryNameController,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(labelText: '이름'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: recoveryPhoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(labelText: '전화번호'),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: submitting
                        ? null
                        : () => Navigator.of(dialogContext).pop(),
                    child: const Text('닫기'),
                  ),
                  OutlinedButton(
                    onPressed: submitting
                        ? null
                        : () => runDialogAction(() async {
                            final email = resetEmailController.text.trim();
                            if (email.isEmpty) {
                              _showSnackBar('비밀번호를 재설정할 이메일을 입력해 주세요.');
                              return;
                            }
                            await ref
                                .read(authControllerProvider.notifier)
                                .sendPasswordResetEmail(email: email);
                            if (!mounted) {
                              return;
                            }
                            _showSnackBar('비밀번호 재설정 메일을 보냈습니다.');
                          }),
                    child: const Text('비밀번호 재설정'),
                  ),
                  FilledButton(
                    onPressed: submitting
                        ? null
                        : () => runDialogAction(() async {
                            final name = recoveryNameController.text.trim();
                            final phone = recoveryPhoneController.text.trim();
                            if (name.isEmpty || phone.isEmpty) {
                              _showSnackBar('이름과 전화번호를 입력해 주세요.');
                              return;
                            }
                            final maskedEmail = await ref
                                .read(authControllerProvider.notifier)
                                .findLearnerEmail(
                                  learnerName: name,
                                  learnerPhone: phone,
                                );
                            if (!mounted) {
                              return;
                            }
                            if (maskedEmail == null) {
                              _showSnackBar(
                                '일치하는 계정을 찾지 못했습니다. 관리자에게 문의해 주세요.',
                              );
                              return;
                            }
                            _showSnackBar('등록된 이메일: $maskedEmail');
                          }),
                    child: const Text('이메일 찾기'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      recoveryNameController.dispose();
      recoveryPhoneController.dispose();
      resetEmailController.dispose();
    }
  }

  bool _validateEmailAndPassword() {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      _showSnackBar('이메일과 비밀번호를 입력해 주세요.');
      return false;
    }

    if (password.length < 6) {
      _showSnackBar('비밀번호는 6자 이상이어야 합니다.');
      return false;
    }

    return true;
  }

  bool _validateProfileFields() {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    if (name.isEmpty || phone.isEmpty) {
      _showSnackBar('계정 만들기에는 이름과 전화번호가 필요합니다.');
      return false;
    }

    if (phone.replaceAll(RegExp(r'[^0-9]'), '').length < 8) {
      _showSnackBar('전화번호를 정확히 입력해 주세요.');
      return false;
    }

    return true;
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _authErrorMessage(Object error, AppLocalizations? l10n) {
    if (error is FirebaseAuthException) {
      return switch (error.code) {
        'invalid-credential' || 'user-not-found' || 'wrong-password' =>
          '로그인할 수 없습니다. 계정이 아직 없으면 같은 이메일과 비밀번호로 계정을 먼저 만들어 주세요. 이미 만든 계정이면 비밀번호를 확인해 주세요.',
        'email-already-in-use' => '이미 만들어진 계정입니다. 로그인 버튼으로 로그인해 주세요.',
        'invalid-email' => '이메일 형식이 올바르지 않습니다.',
        'weak-password' => '비밀번호가 너무 약합니다. 6자 이상으로 입력해 주세요.',
        'network-request-failed' => '네트워크 연결을 확인한 후 다시 시도해 주세요.',
        'too-many-requests' => '로그인 시도가 너무 많습니다. 잠시 후 다시 시도해 주세요.',
        _ =>
          l10n?.loginFailedWithError(error.message ?? error.code) ??
              '로그인에 실패했습니다: ${error.message ?? error.code}',
      };
    }

    return l10n?.loginFailedWithError(error.toString()) ??
        '로그인에 실패했습니다: $error';
  }
}

class _CreateAccountActions extends StatelessWidget {
  const _CreateAccountActions({
    required this.authAction,
    required this.onCreateAccount,
    required this.onBackToLogin,
  });

  final AsyncValue<void> authAction;
  final VoidCallback onCreateAccount;
  final VoidCallback onBackToLogin;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          onPressed: authAction.isLoading ? null : onCreateAccount,
          icon: const Icon(Icons.person_add_alt_1),
          label: const Text('계정 만들기'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: authAction.isLoading ? null : onBackToLogin,
          icon: const Icon(Icons.arrow_back),
          label: const Text('로그인으로 돌아가기'),
        ),
        const SizedBox(height: 8),
        const Text('계정 생성 후 관리자 승인 후에 학습을 시작할 수 있습니다.'),
      ],
    );
  }
}

class _LoginActions extends StatelessWidget {
  const _LoginActions({
    required this.authAction,
    required this.onSignIn,
    required this.onCreateAccount,
    required this.onRecoverAccount,
  });

  final AsyncValue<void> authAction;
  final VoidCallback onSignIn;
  final VoidCallback onCreateAccount;
  final VoidCallback onRecoverAccount;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 520;
            final signInButton = FilledButton.icon(
              onPressed: authAction.isLoading ? null : onSignIn,
              icon: const Icon(Icons.login),
              label: const Text('로그인'),
            );
            final createAccountButton = OutlinedButton.icon(
              onPressed: authAction.isLoading ? null : onCreateAccount,
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('계정 만들기'),
            );

            if (isCompact) {
              return Column(
                children: [
                  SizedBox(width: double.infinity, child: signInButton),
                  const SizedBox(height: 8),
                  SizedBox(width: double.infinity, child: createAccountButton),
                ],
              );
            }

            return Row(
              children: [
                Expanded(child: signInButton),
                const SizedBox(width: 12),
                Expanded(child: createAccountButton),
              ],
            );
          },
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: authAction.isLoading ? null : onRecoverAccount,
            icon: const Icon(Icons.help_outline),
            label: const Text('이메일/비밀번호를 잊으셨나요?'),
          ),
        ),
      ],
    );
  }
}
