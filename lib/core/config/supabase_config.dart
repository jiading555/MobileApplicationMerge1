class SupabaseConfig {
  const SupabaseConfig._();

  static const String url = 'https://xdfxeayxkzxqnznubmof.supabase.co';
  static const String publishableKey =
      'sb_publishable_1JrYLNMfBjXtCAH9XNyBbg_4v-C0LKw';

  static const String emailConfirmationRedirectUrl =
      'smartpropertyadvisor://email-confirmed';
  static const String passwordRecoveryRedirectUrl =
      'smartpropertyadvisor://reset-password';

  static bool get isConfigured =>
      url.trim().isNotEmpty &&
      publishableKey.trim().isNotEmpty &&
      url != 'MY_SUPABASE_URL' &&
      publishableKey != 'MY_SUPABASE_PUBLISHABLE_KEY';
}
