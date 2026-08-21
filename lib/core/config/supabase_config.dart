class SupabaseConfig {
  const SupabaseConfig._();

  // Replace these with your Supabase project URL and client-safe
  // publishable/anon key from the Supabase dashboard.
  static const String url = 'https://xdfxeayxkzxqnznubmof.supabase.co';
  static const String publishableKey = 'sb_publishable_1JrYLNMfBjXtCAH9XNyBbg_4v-C0LKw';

  static bool get isConfigured =>
      url.trim().isNotEmpty &&
      publishableKey.trim().isNotEmpty &&
      url != 'MY_SUPABASE_URL' &&
      publishableKey != 'MY_SUPABASE_PUBLISHABLE_KEY';
}
