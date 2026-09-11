bool isRefreshFailureMessage(String message) {
  final normalizedMessage = message.toLowerCase();

  return normalizedMessage.contains('failed') ||
      normalizedMessage.contains('could not') ||
      normalizedMessage.contains('no internet');
}
