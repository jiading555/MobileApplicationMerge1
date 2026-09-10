import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/auth_validators.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key, this.recoveryMode = false});

  final bool recoveryMode;

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmationController = TextEditingController();
  final formKey = GlobalKey<FormState>();

  bool sent = false;
  bool loading = false;
  bool obscurePassword = true;
  bool obscureConfirmation = true;
  String? error;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    confirmationController.dispose();
    super.dispose();
  }

  Future<void> _sendResetLink() async {
    if (!formKey.currentState!.validate()) return;
    setState(() {
      loading = true;
      error = null;
    });
    final result = await AppScope.of(
      context,
    ).resetPassword(emailController.text);
    if (!mounted) return;
    setState(() {
      loading = false;
      error = result;
      sent = result == null;
    });
  }

  Future<void> _updatePassword() async {
    if (!formKey.currentState!.validate()) return;
    setState(() {
      loading = true;
      error = null;
    });
    final result = await AppScope.of(context).updateRecoveredPassword(
      password: passwordController.text,
      confirmation: confirmationController.text,
    );
    if (!mounted) return;
    setState(() {
      loading = false;
      error = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    final recovery = widget.recoveryMode;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !recovery,
        title: Text(recovery ? 'Create new password' : 'Reset password'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      recovery
                          ? Icons.password_rounded
                          : sent
                          ? Icons.mark_email_read_rounded
                          : Icons.lock_reset_rounded,
                      size: 64,
                      color: AppTheme.blue,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      recovery
                          ? 'Choose a new password'
                          : sent
                          ? 'Check your inbox'
                          : 'Forgot your password?',
                      style: Theme.of(context).textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      recovery
                          ? 'Use at least 8 characters with uppercase, lowercase and a special character.'
                          : sent
                          ? 'A password reset link was sent to ${emailController.text}.'
                          : 'Enter your account email to request a reset link.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppTheme.muted),
                    ),
                    const SizedBox(height: 24),
                    if (recovery) ...[
                      TextFormField(
                        controller: passwordController,
                        obscureText: obscurePassword,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        decoration: InputDecoration(
                          labelText: 'New password',
                          prefixIcon: const Icon(Icons.lock_outline_rounded),
                          errorMaxLines: 3,
                          suffixIcon: IconButton(
                            onPressed: () => setState(
                              () => obscurePassword = !obscurePassword,
                            ),
                            icon: Icon(
                              obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
                        validator: AuthValidators.registrationPassword,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: confirmationController,
                        obscureText: obscureConfirmation,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        decoration: InputDecoration(
                          labelText: 'Confirm new password',
                          prefixIcon: const Icon(Icons.lock_outline_rounded),
                          errorMaxLines: 3,
                          suffixIcon: IconButton(
                            onPressed: () => setState(
                              () => obscureConfirmation = !obscureConfirmation,
                            ),
                            icon: Icon(
                              obscureConfirmation
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
                        validator: (value) => AuthValidators.confirmPassword(
                          value,
                          passwordController.text,
                        ),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: loading ? null : _updatePassword,
                          child: loading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Update password'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: loading
                            ? null
                            : () =>
                                  AppScope.of(context).cancelPasswordRecovery(),
                        child: const Text('Cancel'),
                      ),
                    ] else if (!sent) ...[
                      TextFormField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        decoration: const InputDecoration(
                          labelText: 'Email address',
                          prefixIcon: Icon(Icons.mail_outline_rounded),
                          errorMaxLines: 3,
                        ),
                        validator: AuthValidators.email,
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: loading ? null : _sendResetLink,
                          child: loading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Send reset link'),
                        ),
                      ),
                    ] else
                      FilledButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Back to sign in'),
                      ),
                    if (error != null) ...[
                      const SizedBox(height: 14),
                      Text(
                        error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Color(0xFFB42318)),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
