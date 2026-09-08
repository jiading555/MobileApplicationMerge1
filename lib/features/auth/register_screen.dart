import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/theme/app_theme.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  String? error;
  bool confirmationSent = false;

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (!formKey.currentState!.validate()) {
      return;
    }
    final result = await AppScope.of(context).register(
      nameController.text,
      emailController.text,
      passwordController.text,
    );
    if (!mounted) return;
    if (result == null) {
      final state = AppScope.of(context);
      if (state.registrationNeedsConfirmation) {
        setState(() {
          confirmationSent = true;
          error = null;
        });
      } else {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } else {
      setState(() => error = result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create account')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: confirmationSent
                ? _ConfirmationSent(
                    email: emailController.text.trim(),
                    onBack: () => Navigator.of(context).pop(),
                    onResend: () async {
                      final result = await AppScope.of(
                        context,
                      ).resendSignupConfirmation(emailController.text);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            result ?? 'Confirmation email sent again.',
                          ),
                          backgroundColor: result == null
                              ? AppTheme.green
                              : const Color(0xFFB42318),
                        ),
                      );
                    },
                  )
                : Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.person_add_alt_1_rounded,
                    size: 58,
                    color: AppTheme.blue,
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Start your property journey',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 28),
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Full name',
                      prefixIcon: Icon(Icons.person_outline_rounded),
                    ),
                    validator: (value) =>
                        value == null || value.trim().length < 2
                        ? 'Enter your full name'
                        : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email address',
                      prefixIcon: Icon(Icons.mail_outline_rounded),
                    ),
                    validator: (value) => value == null || !value.contains('@')
                        ? 'Enter a valid email address'
                        : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      prefixIcon: Icon(Icons.lock_outline_rounded),
                    ),
                    validator: (value) => value == null || value.length < 8
                        ? 'Use at least 8 characters'
                        : null,
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      error!,
                      style: const TextStyle(color: Color(0xFFB42318)),
                    ),
                  ],
                  const SizedBox(height: 22),
                  FilledButton(
                    onPressed: AppScope.of(context).isAccountBusy ? null : submit,
                    child: AppScope.of(context).isAccountBusy
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Create account'),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'A confirmation email may be required before your first sign in.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.muted, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ConfirmationSent extends StatelessWidget {
  const _ConfirmationSent({
    required this.email,
    required this.onBack,
    required this.onResend,
  });

  final String email;
  final VoidCallback onBack;
  final VoidCallback onResend;

  @override
  Widget build(BuildContext context) {
    final busy = AppScope.of(context).isAccountBusy;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.mark_email_read_rounded, size: 68, color: AppTheme.blue),
        const SizedBox(height: 18),
        Text(
          'Check your email',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 10),
        Text(
          'We sent a confirmation link to $email. Open the link before signing in.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppTheme.muted),
        ),
        const SizedBox(height: 24),
        FilledButton(onPressed: onBack, child: const Text('Back to sign in')),
        const SizedBox(height: 10),
        TextButton(
          onPressed: busy ? null : onResend,
          child: const Text('Resend confirmation email'),
        ),
      ],
    );
  }
}

