import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/smart_property_advisor_app.dart';
import 'core/config/supabase_config.dart';
import 'services/supabase_connection_verifier.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (SupabaseConfig.isConfigured) {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.publishableKey,
    );
  } else if (kDebugMode) {
    debugPrint(
      '[DEV Supabase check] SupabaseConfig constants are not set; '
      'starting with local JSON fallback only.',
    );
  }

  if (kDebugMode && SupabaseConfig.isConfigured) {
    unawaited(SupabaseConnectionVerifier.logFirstAreaProfile());
  }

  runApp(const SmartPropertyAdvisorApp());
}
