import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final controller = TextEditingController();
  bool sent = false;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reset password')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  sent
                      ? Icons.mark_email_read_rounded
                      : Icons.lock_reset_rounded,
                  size: 64,
                  color: AppTheme.blue,
                ),
                const SizedBox(height: 20),
                Text(
                  sent ? 'Check your inbox' : 'Forgot your password?',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  sent
                      ? 'A sample reset request was created for ${controller.text}.'
                      : 'Enter your account email to request a reset link.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppTheme.muted),
                ),
                const SizedBox(height: 24),
                if (!sent) ...[
                  TextField(
                    controller: controller,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email address',
                      prefixIcon: Icon(Icons.mail_outline_rounded),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        if (controller.text.contains('@')) {
                          setState(() => sent = true);
                        }
                      },
                      child: const Text('Send reset link'),
                    ),
                  ),
                ] else
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Back to sign in'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
