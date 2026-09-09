import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/area_profile.dart';
import '../models/property.dart';
import 'open_data_service.dart';
import 'teduh_service.dart';

class GovernmentDataSyncEnvironment {
  const GovernmentDataSyncEnvironment({
    required this.supabaseUrl,
    required this.serviceRoleKey,
  });

  final String supabaseUrl;
  final String serviceRoleKey;

  factory GovernmentDataSyncEnvironment.fromMap(Map<String, String> values) {
    final url = values['SUPABASE_URL']?.trim() ?? '';
    final key = values['SUPABASE_SERVICE_ROLE_KEY']?.trim() ?? '';
    if (url.isEmpty) {
      throw const GovernmentDataSyncConfigurationException(
        'SUPABASE_URL is required.',
      );
    }
    if (key.isEmpty) {
      throw const GovernmentDataSyncConfigurationException(
        'SUPABASE_SERVICE_ROLE_KEY is required.',
      );
    }
    return GovernmentDataSyncEnvironment(
      supabaseUrl: url.replaceAll(RegExp(r'/+$'), ''),
      serviceRoleKey: key,
    );
  }
}

class GovernmentDataSyncRunner {
  GovernmentDataSyncRunner({
    OpenDataService? openDataService,
    TeduhService? teduhService,
    required SupabaseGovernmentDataRestClient supabaseClient,
  }) : this._(
         openDataService ?? OpenDataService(),
         teduhService ?? TeduhService(),
         supabaseClient,
       );

  GovernmentDataSyncRunner._(
    this._openDataService,
    this._teduhService,
    this._supabaseClient,
  );

  final OpenDataService _openDataService;
  final TeduhService _teduhService;
  final SupabaseGovernmentDataRestClient _supabaseClient;

  Future<GovernmentDataSyncResult> run() async {
    final areaProfiles = _mergeAreaProfiles(
      await _openDataService.fetchAreaProfiles(),
    ).values.toList();
    final properties = await _teduhService.fetchProjects();

    final upsertedAreaProfiles = await _supabaseClient.upsertAreaProfiles(
      areaProfiles,
    );
    final upsertedProperties = await _supabaseClient.upsertProperties(
      properties,
    );

    return GovernmentDataSyncResult(
      areaProfiles: areaProfiles,
      properties: properties,
      upsertedAreaProfiles: upsertedAreaProfiles,
      upsertedProperties: upsertedProperties,
    );
  }

  Map<String, AreaProfile> _mergeAreaProfiles(Iterable<AreaProfile> profiles) {
    final merged = <String, AreaProfile>{};
    for (final profile in profiles) {
      final canonical = profile.canonicalized();
      final existing = merged[canonical.areaId];
      merged[canonical.areaId] = existing == null
          ? canonical
          : existing.mergeWith(canonical);
    }
    return merged;
  }
}

class SupabaseGovernmentDataRestClient {
  SupabaseGovernmentDataRestClient({
    required this.environment,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final GovernmentDataSyncEnvironment environment;
  final http.Client _client;

  Uri upsertUri(String table, String conflictKey) {
    final baseUrl = environment.supabaseUrl.replaceAll(RegExp(r'/+$'), '');
    return Uri.parse(
      '$baseUrl/rest/v1/$table',
    ).replace(queryParameters: {'on_conflict': conflictKey});
  }

  Map<String, String> get headers {
    return {
      'apikey': environment.serviceRoleKey,
      'Authorization': 'Bearer ${environment.serviceRoleKey}',
      'Content-Type': 'application/json',
      'Prefer': 'resolution=merge-duplicates,return=minimal',
    };
  }

  Future<int> upsertAreaProfiles(List<AreaProfile> profiles) {
    final updatedAt = DateTime.now().toUtc();
    return _upsertRows(
      table: 'area_profiles',
      conflictKey: 'area_id',
      rows: profiles
          .map((profile) => profile.toSupabaseJson(updatedAt: updatedAt))
          .toList(),
    );
  }

  Future<int> upsertProperties(List<Property> properties) {
    final updatedAt = DateTime.now().toUtc();
    return _upsertRows(
      table: 'properties',
      conflictKey: 'source_id',
      rows: properties
          .map((property) => property.toSupabaseJson(updatedAt: updatedAt))
          .toList(),
    );
  }

  Future<int> _upsertRows({
    required String table,
    required String conflictKey,
    required List<Map<String, dynamic>> rows,
  }) async {
    if (rows.isEmpty) {
      return 0;
    }
    final response = await _client.post(
      upsertUri(table, conflictKey),
      headers: headers,
      body: jsonEncode(rows),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw GovernmentDataSyncUpsertException(
        'Supabase upsert failed for $table (${response.statusCode}).',
      );
    }
    return rows.length;
  }
}

class GovernmentDataSyncResult {
  const GovernmentDataSyncResult({
    required this.areaProfiles,
    required this.properties,
    required this.upsertedAreaProfiles,
    required this.upsertedProperties,
  });

  final List<AreaProfile> areaProfiles;
  final List<Property> properties;
  final int upsertedAreaProfiles;
  final int upsertedProperties;
}

class GovernmentDataSyncConfigurationException implements Exception {
  const GovernmentDataSyncConfigurationException(this.message);

  final String message;

  @override
  String toString() => message;
}

class GovernmentDataSyncUpsertException implements Exception {
  const GovernmentDataSyncUpsertException(this.message);

  final String message;

  @override
  String toString() => message;
}
