import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:smart_property_advisor/core/utils/network_error_mapper.dart';

void main() {
  group('NetworkErrorMapper', () {
    test('maps ClientException-style failures to offline message', () {
      final error = http.ClientException(
        'ClientException with SocketException: Failed host lookup',
        Uri.parse('https://example.supabase.co/rest/v1/properties'),
      );

      expect(
        NetworkErrorMapper.messageFor(
          error,
          action: NetworkErrorAction.refresh,
        ),
        NetworkErrorMapper.offlineMessage,
      );
    });

    test('maps failed host lookup text to offline message', () {
      expect(
        NetworkErrorMapper.messageFor(
          Exception('SocketException: Failed host lookup: example.supabase.co'),
        ),
        NetworkErrorMapper.offlineMessage,
      );
    });

    test('uses action fallback for unknown failures', () {
      expect(
        NetworkErrorMapper.messageFor(
          Exception('unexpected internal detail'),
          action: NetworkErrorAction.refresh,
        ),
        NetworkErrorMapper.refreshFailureMessage,
      );
    });

    test('cleans technical details from displayed errors', () {
      expect(
        NetworkErrorMapper.cleanMessage(
          Exception('PostgrestException: https://example.supabase.co/rest/v1'),
          fallback: NetworkErrorMapper.loadFailureMessage,
        ),
        NetworkErrorMapper.loadFailureMessage,
      );
    });
  });
}
