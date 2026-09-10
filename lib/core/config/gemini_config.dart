class GeminiConfig {
  static const String apiKey =
      'AQ.Ab8RN6JBDakS2C0liTDlIdNxGI11aEgeToSH2nOMlvY0bU_3Eg';

  static const String model =
      'gemini-3.5-flash-lite';

  static bool get isConfigured =>
      apiKey.isNotEmpty &&
          apiKey != 'PASTE_YOUR_GEMINI_API_KEY_HERE';
}