import 'dart:io';

import 'package:smart_property_advisor/services/government_data_sync.dart';

Future<void> main() async {
  stdout.writeln('Government data sync started');
  try {
    final environment = GovernmentDataSyncEnvironment.fromMap(
      Platform.environment,
    );
    final runner = GovernmentDataSyncRunner(
      supabaseClient: SupabaseGovernmentDataRestClient(
        environment: environment,
      ),
    );
    final result = await runner.run();
    stdout.writeln('Area profiles fetched: ${result.areaProfiles.length}');
    stdout.writeln('TEDUH properties fetched: ${result.properties.length}');
    stdout.writeln('Area profiles upserted: ${result.upsertedAreaProfiles}');
    stdout.writeln('Properties upserted: ${result.upsertedProperties}');
    stdout.writeln('Government data sync completed');
  } catch (error) {
    stderr.writeln('Government data sync failed: $error');
    exitCode = 1;
  }
}
