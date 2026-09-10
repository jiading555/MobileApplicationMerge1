import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/reset_password_screen.dart';
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
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  late final AppLinks appLinks;
  StreamSubscription<Uri>? linkSubscription;

  @override
  void initState() {
    super.initState();
    appLinks = AppLinks();
    appState.initialise();
    _listenForAuthLinks();
  }

  Future<void> _listenForAuthLinks() async {
    if (kIsWeb) return;

    try {
      final initialLink = await appLinks.getInitialLink();
      if (initialLink != null) {
        await _handleAuthLink(initialLink);
      }
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Unable to read initial auth link: $error');
      }
    }

    linkSubscription = appLinks.uriLinkStream.listen(
      _handleAuthLink,
      onError: (Object error) {
        if (kDebugMode) {
          debugPrint('Unable to handle auth link: $error');
        }
      },
    );
  }

  Future<void> _handleAuthLink(Uri uri) async {
    await appState.handleAuthDeepLink(uri);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      navigatorKey.currentState?.popUntil((route) => route.isFirst);
    });
  }

  @override
  void dispose() {
    linkSubscription?.cancel();
    appState.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      notifier: appState,
      child: MaterialApp(
        navigatorKey: navigatorKey,
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
    if (state.isPasswordRecovery) {
      return const ResetPasswordScreen(
        key: ValueKey('password-recovery'),
        recoveryMode: true,
      );
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
