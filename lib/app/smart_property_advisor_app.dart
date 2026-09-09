import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../features/auth/login_screen.dart';
import 'app_scope.dart';
import 'app_shell.dart';
import 'app_state.dart';

class SmartPropertyAdvisorApp extends StatefulWidget {
  const SmartPropertyAdvisorApp({super.key});

  @override
  State<SmartPropertyAdvisorApp> createState() =>
      _SmartPropertyAdvisorAppState();
}

class _SmartPropertyAdvisorAppState extends State<SmartPropertyAdvisorApp> {
  final AppState appState = AppState();

  @override
  void initState() {
    super.initState();
    appState.initialise();
  }

  @override
  void dispose() {
    appState.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      notifier: appState,
      child: MaterialApp(
        title: 'Smart Property Advisor',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: const _AppRoot(),
      ),
    );
  }
}

class _AppRoot extends StatelessWidget {
  const _AppRoot();

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    if (state.isLoading) {
      return const _SplashScreen();
    }
    if (state.loadError != null) {
      return _LoadError(message: state.loadError!);
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 280),
      child: state.isAuthenticated
          ? const AppShell(key: ValueKey('shell'))
          : const LoginScreen(key: ValueKey('login')),
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF083E7C), Color(0xFF087CC6), Color(0xFF28C6B7)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.home_work_rounded,
                    color: Colors.white,
                    size: 72,
                  ),
                  const SizedBox(height: 18),
                  const SizedBox(
                    width: double.infinity,
                    child: Text(
                      'Smart Property Advisor',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const SizedBox(
                    width: double.infinity,
                    child: Text(
                      'Smarter property decisions',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                  ),
                  const SizedBox(height: 32),
                  const SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 3,
                    ),
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

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded, size: 60),
              const SizedBox(height: 16),
              const Text(
                'Smart Property Advisor could not load its data snapshot.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
