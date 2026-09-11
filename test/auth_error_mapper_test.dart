import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:smart_property_advisor/core/utils/auth_error_mapper.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('AuthErrorMapper', () {
    test('maps offline network exceptions', () {
      final error = http.ClientException(
        'ClientException with SocketException: Failed host lookup',
        Uri.parse('https://example.supabase.co/auth/v1/token'),
      );

      expect(
        AuthErrorMapper.messageFor(error, context: AuthErrorContext.signIn),
        AuthErrorMapper.networkMessage,
      );
    });

    test('maps invalid credentials', () {
      const error = AuthException(
        'Invalid login credentials',
        statusCode: '400',
        code: 'invalid_credentials',
      );

      expect(
        AuthErrorMapper.messageFor(error, context: AuthErrorContext.signIn),
        AuthErrorMapper.invalidCredentialsMessage,
      );
    });

    test('maps email not confirmed', () {
      const error = AuthException(
        'Email not confirmed',
        statusCode: '400',
        code: 'email_not_confirmed',
      );

      expect(
        AuthErrorMapper.messageFor(error, context: AuthErrorContext.signIn),
        AuthErrorMapper.emailNotConfirmedMessage,
      );
    });

    test('maps duplicate account', () {
      const error = AuthException(
        'User already registered',
        statusCode: '400',
        code: 'email_exists',
      );

      expect(
        AuthErrorMapper.messageFor(error, context: AuthErrorContext.signUp),
        AuthErrorMapper.duplicateAccountMessage,
      );
    });

    test('maps rate limit', () {
      const error = AuthException(
        'Too many requests',
        statusCode: '429',
        code: 'over_request_rate_limit',
      );

      expect(
        AuthErrorMapper.messageFor(error, context: AuthErrorContext.signIn),
        AuthErrorMapper.rateLimitMessage,
      );
    });

    test('maps unknown exceptions to fallback', () {
      expect(
        AuthErrorMapper.messageFor(
          Exception('unexpected internal details'),
          context: AuthErrorContext.signIn,
        ),
        AuthErrorMapper.fallbackMessage,
      );
    });
  });
}
