/// Gemini credentials are stored only in Supabase Edge Function Secrets.
///
/// The Flutter client must not contain or read the Gemini API key.
class GeminiConfig {
  const GeminiConfig._();

  static const String edgeFunctionName = 'gemini-advisor';
}
