import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

enum AuthErrorContext {
  signIn,
  signUp,
  passwordReset,
  passwordUpdate,
  resendConfirmation,
  accountUpdate,
}

class AuthErrorMapper {
  const AuthErrorMapper._();

  static const networkMessage =
      'No internet connection. Check your network and try again.';
  static const invalidCredentialsMessage =
      'Incorrect email address or password.';
  static const emailNotConfirmedMessage =
      'Confirm your email address before signing in.';
  static const duplicateAccountMessage =
      'An account with this email already exists.';
  static const invalidEmailMessage = 'Please enter a valid email address.';
  static const weakPasswordMessage = 'Please choose a stronger password.';
  static const rateLimitMessage =
      'Too many attempts. Please wait a moment and try again.';
  static const passwordResetMessage =
      'Unable to process the request. Please check the email address and try again.';
  static const fallbackMessage = 'Unable to sign in. Please try again.';

  static String messageFor(
    Object error, {
    AuthErrorContext context = AuthErrorContext.accountUpdate,
    String? fallback,
  }) {
    if (_isNetworkError(error)) {
      return networkMessage;
    }

    if (error is AuthException) {
      return _authMessageFor(error, context: context, fallback: fallback);
    }

    return fallback ?? fallbackMessage;
  }

  static String _authMessageFor(
    AuthException error, {
    required AuthErrorContext context,
    String? fallback,
  }) {
    final code = error.code?.toLowerCase().trim();
    final statusCode = error.statusCode?.trim();
    final message = error.message.toLowerCase();

    if (code == 'email_not_confirmed' ||
        message.contains('email not confirmed')) {
      return emailNotConfirmedMessage;
    }

    if (code == 'invalid_credentials' ||
        message.contains('invalid login credentials') ||
        message.contains('invalid login') ||
        message.contains('invalid credentials')) {
      return context == AuthErrorContext.passwordUpdate
          ? 'Current password is incorrect.'
          : invalidCredentialsMessage;
    }

    if (code == 'email_exists' ||
        code == 'user_already_exists' ||
        code == 'identity_already_exists' ||
        message.contains('already registered') ||
        message.contains('already exists') ||
        message.contains('user already registered')) {
      return duplicateAccountMessage;
    }

    if (code == 'weak_password' ||
        error is AuthWeakPasswordException ||
        message.contains('weak password') ||
        message.contains('invalid password') ||
        message.contains('password should') ||
        message.contains('password must')) {
      return weakPasswordMessage;
    }

    if (statusCode == '429' ||
        code == 'over_request_rate_limit' ||
        code == 'over_email_send_rate_limit' ||
        code == 'over_sms_send_rate_limit' ||
        message.contains('rate limit') ||
        message.contains('too many requests') ||
        message.contains('too many attempts')) {
      return rateLimitMessage;
    }

    if (code == 'validation_failed' ||
        code == 'bad_json' ||
        code == 'invalid_email' ||
        message.contains('invalid email') ||
        message.contains('email address is invalid')) {
      return invalidEmailMessage;
    }

    if (context == AuthErrorContext.passwordReset &&
        (code == 'user_not_found' ||
            message.contains('user not found') ||
            message.contains('email not found'))) {
      return passwordResetMessage;
    }

    return fallback ?? fallbackMessage;
  }

  static bool _isNetworkError(Object error) {
    if (error is http.ClientException) {
      return true;
    }

    if (error is AuthRetryableFetchException && error.statusCode == null) {
      return true;
    }

    final text = error.toString().toLowerCase();
    return text.contains('socketexception') ||
        text.contains('clientexception') ||
        text.contains('failed host lookup') ||
        text.contains('no address associated with hostname') ||
        text.contains('network is unreachable') ||
        text.contains('connection failed') ||
        text.contains('connection refused') ||
        text.contains('connection reset') ||
        text.contains('connection timed out') ||
        text.contains('operation timed out') ||
        text.contains('temporary failure in name resolution') ||
        text.contains('dns') ||
        text.contains('failed to fetch') ||
        text.contains('networkerror') ||
        text.contains('xmlhttprequest error');
  }
}
