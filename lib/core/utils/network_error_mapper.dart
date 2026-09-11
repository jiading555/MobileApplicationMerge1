import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

enum NetworkErrorAction { load, refresh, save, ai }

class NetworkErrorMapper {
  const NetworkErrorMapper._();

  static const offlineMessage =
      'No internet connection. Check your connection and try again.';
  static const refreshFailureMessage =
      'Unable to refresh data. Please try again later.';
  static const loadFailureMessage = 'Unable to load data. Please try again.';
  static const saveFailureMessage = 'Unable to save changes. Please try again.';
  static const aiFailureMessage =
      'Unable to reach the AI advisor. Please try again.';

  static String messageFor(
    Object error, {
    NetworkErrorAction action = NetworkErrorAction.load,
    String? fallback,
  }) {
    if (isNetworkError(error)) {
      return offlineMessage;
    }

    return fallback ?? _fallbackFor(action);
  }

  static String cleanMessage(Object error, {required String fallback}) {
    final text = error.toString().replaceFirst('Exception: ', '').trim();
    if (text.isEmpty || _containsTechnicalDetails(text)) {
      return fallback;
    }
    return text;
  }

  static bool isNetworkError(Object error) {
    if (error is TimeoutException || error is http.ClientException) {
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

  static String _fallbackFor(NetworkErrorAction action) {
    return switch (action) {
      NetworkErrorAction.load => loadFailureMessage,
      NetworkErrorAction.refresh => refreshFailureMessage,
      NetworkErrorAction.save => saveFailureMessage,
      NetworkErrorAction.ai => aiFailureMessage,
    };
  }

  static bool _containsTechnicalDetails(String value) {
    final text = value.toLowerCase();
    return text.contains('socketexception') ||
        text.contains('clientexception') ||
        text.contains('postgrestexception') ||
        text.contains('authretryablefetchexception') ||
        text.contains('supabase.co') ||
        text.contains('/rest/v1/') ||
        text.contains('/auth/v1/') ||
        text.contains('errno') ||
        text.contains('stack trace');
  }
}
