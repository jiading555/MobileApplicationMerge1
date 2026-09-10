class GeminiConfig {
  static const String apiKey =
      '';

  static const String model =
      'gemini-3.5-flash-lite';

  static bool get isConfigured =>
      apiKey.isNotEmpty &&
          apiKey != 'PASTE_YOUR_GEMINI_API_KEY_HERE';
}