import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/auth_validators.dart';
import '../../core/widgets/advisor_brand.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final formKey = GlobalKey<FormState>();
  bool obscurePassword = true;
  String? error;

  bool get canSubmit =>
      AuthValidators.email(emailController.text) == null &&
      AuthValidators.loginPassword(passwordController.text) == null;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (!formKey.currentState!.validate()) {
      return;
    }
    final result = await AppScope.of(
      context,
    ).login(emailController.text, passwordController.text);
    if (mounted) setState(() => error = result);
  }

  Future<void> sendPasswordReset() async {
    final emailError = AuthValidators.email(emailController.text);
    if (emailError != null) {
      setState(() => error = 'Enter your email address to reset your password.');
      return;
    }

    final result = await AppScope.of(context).resetPassword(emailController.text);
    if (!mounted) return;
    if (result != null) {
      setState(() => error = result);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Password reset link sent. Check your email.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 850;
            return Row(
              children: [
                if (wide) const Expanded(child: _LoginHero()),
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(28),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 440),
                        child: Form(
                          key: formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (!wide)
                                const Align(
                                  alignment: Alignment.center,
                                  child: AdvisorBrand(),
                                ),
                              if (!wide) const SizedBox(height: 44),
                              Text(
                                'Welcome back',
                                style: Theme.of(
                                  context,
                                ).textTheme.headlineMedium,
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Sign in to continue your smarter property search.',
                                style: TextStyle(color: AppTheme.muted),
                              ),
                              const SizedBox(height: 30),
                              TextFormField(
                                controller: emailController,
                                onChanged: (_) => setState(() => error = null),
                                keyboardType: TextInputType.emailAddress,
                                autovalidateMode:
                                    AutovalidateMode.onUserInteraction,
                                decoration: const InputDecoration(
                                  labelText: 'Email address',
                                  hintText: 'name@example.com',
                                  prefixIcon: Icon(Icons.mail_outline_rounded),
                                  errorMaxLines: 3,
                                ),
                                validator: AuthValidators.email,
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: passwordController,
                                onChanged: (_) => setState(() => error = null),
                                obscureText: obscurePassword,
                                autovalidateMode:
                                    AutovalidateMode.onUserInteraction,
                                decoration: InputDecoration(
                                  labelText: 'Password',
                                  hintText: 'Enter your password',
                                  prefixIcon: const Icon(
                                    Icons.lock_outline_rounded,
                                  ),
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
                                validator: AuthValidators.loginPassword,
                              ),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: AppScope.of(context).isAccountBusy
                                      ? null
                                      : sendPasswordReset,
                                  child: const Text('Forgot password?'),
                                ),
                              ),
                              if (error != null) ...[
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFECEC),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    error!,
                                    style: const TextStyle(
                                      color: Color(0xFFB42318),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 14),
                              ],
                              FilledButton(
                                onPressed:
                                    AppScope.of(context).isAccountBusy ||
                                        !canSubmit
                                    ? null
                                    : submit,
                                child: AppScope.of(context).isAccountBusy
                                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                                    : const Text('Sign in'),
                              ),
                              const SizedBox(height: 22),
                              Wrap(
                                alignment: WrapAlignment.center,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  const Text('New here?'),
                                  TextButton(
                                    onPressed: () => Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder: (_) => const RegisterScreen(),
                                      ),
                                    ),
                                    child: const Text('Create account'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _LoginHero extends StatelessWidget {
  const _LoginHero();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.navy, AppTheme.blue, AppTheme.teal],
        ),
      ),
      padding: const EdgeInsets.all(56),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdvisorBrand(light: true),
          Spacer(),
          Icon(Icons.location_city_rounded, size: 76, color: Colors.white),
          SizedBox(height: 24),
          Text(
            'Property decisions,\ngrounded in data.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 38,
              height: 1.15,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 16),
          Text(
            'Explore Malaysian areas, compare market signals and understand every recommendation.',
            style: TextStyle(color: Colors.white70, fontSize: 16, height: 1.5),
          ),
          Spacer(),
          Text(
            'Built with Malaysian open data - SDG 9',
            style: TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

