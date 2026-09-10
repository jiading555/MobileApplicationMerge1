import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/utils/location_normalizer.dart';
import '../models/area_profile.dart';
import 'transport_data_service.dart';

class OpenDataService {
  OpenDataService({
    http.Client? client,
    TransportDataService? transportDataService,
  }) : _client = client ?? http.Client(),
       _transportDataService =
           transportDataService ?? TransportDataService(client: client);

  final http.Client _client;
  final TransportDataService _transportDataService;

  static const _apiBase = 'https://api.data.gov.my/data-catalogue';
  static const _populationDistrictCsv =
      'https://storage.dosm.gov.my/population/population_district.csv';
  static const _crimeDistrictCsv =
      'https://storage.data.gov.my/publicsafety/crime_district.csv';

  static const _sourceReferences = {
    'population_district':
        'https://open.dosm.gov.my/data-catalogue/population_district',
    'hh_income_district':
        'https://open.dosm.gov.my/data-catalogue/hh_income_district',
    'crime_district': 'https://data.gov.my/data-catalogue/crime_district',
    'schools_district': 'https://data.gov.my/data-catalogue/schools_district',
    'hospital_beds': 'https://data.gov.my/data-catalogue/hospital_beds',
    'gtfs_static': 'https://developer.data.gov.my/realtime-api/gtfs-static',
    'district_boundaries': TransportDataService.districtBoundaryUrl,
  };

  static const _crimeDistrictAliases = {
    'selangor|petaling': [
      'Petaling Jaya',
      'Shah Alam',
      'Subang Jaya',
      'Sungai Buloh',
      'Serdang',
    ],
    'selangor|gombak': ['Gombak'],
    'selangor|ulu_langat': ['Kajang', 'Ampang Jaya'],
    'johor|johor_bahru': ['Johor Bahru Selatan', 'Johor Bahru Utara'],
    'johor|kulai': ['Kulaijaya'],
    'johor|tangkak': ['Ledang'],
    'kuala_lumpur|w_p_kuala_lumpur': ['All', 'Kuala Lumpur'],
    'selangor|ulu_selangor': ['Hulu Selangor'],
    'selangor|klang': ['Klang Selatan', 'Klang Utara'],
    'pulau_pinang|timur_laut': ['Timur Laut'],
  };

  static const _hospitalDistrictAliases = {
    'selangor|petaling': ['Petaling (Subang Jaya)'],
    'selangor|gombak': ['Gombak (Rawang)'],
    'selangor|ulu_langat': ['Hulu Langat (Bangi)', 'Ulu Langat (Bangi)'],
    'johor|johor_bahru': ['Johor Bahru'],
    'pulau_pinang|timur_laut': ['Timur Laut (Georgetown)', 'Timur Laut'],
  };

  Future<List<AreaProfile>> fetchAreaProfiles() async {
    final retrievedAt = DateTime.now().toUtc();
    final failures = <String>[];

    final populationRows = await _criticalRows(
      'Population',
      _fetchPopulationDataset(),
      failures,
    );
    final incomeRows = await _criticalRows(
      'Household income',
      _fetchDataset('hh_income_district'),
      failures,
    );
    final schoolRows = await _criticalRows(
      'Schools',
      _fetchDataset('schools_district'),
      failures,
    );
    final crimeRows = await _criticalRows(
      'Crime',
      _fetchCrimeDataset(),
      failures,
    );
    final hospitalRows = await _optionalRows(
      'Hospital beds',
      _fetchDataset('hospital_beds'),
    );

    if (failures.isNotEmpty) {
      throw GovernmentDataRefreshException(failures);
    }

    final populationByKey = _latestRecordsByLocation(
      populationRows,
      predicate: (record) =>
          _normaliseText(record['sex']) == 'both' &&
          _normaliseText(record['age']) == 'overall' &&
          _normaliseText(record['ethnicity']) == 'overall',
    );
    final incomeByKey = _latestRecordsByLocation(incomeRows);
    final schoolsByKey = _latestRecordsByLocation(schoolRows);
    final crimeByKey = _latestRecordsByLocation(
      crimeRows,
      predicate: (record) => _normaliseText(record['type']) == 'all',
    );
    final hospitalByKey = _latestRecordsByLocation(
      hospitalRows,
      predicate: (record) {
        final type = _normaliseText(record['type']);
        return type.isEmpty || type == 'all';
      },
    );

    final mastersByKey = <String, _MasterDistrict>{};
    for (final entry in populationByKey.entries) {
      final master = _masterDistrict(entry.value);
      if (master != null) {
        mastersByKey[entry.key] = master;
      }
    }

    TransportSnapshot? transport;
    if (mastersByKey.isNotEmpty) {
      try {
        transport = await _transportDataService.fetchStopCounts(
          targets: mastersByKey.values
              .map((master) => (master.state, master.district))
              .toList(),
        );
      } catch (_) {
        transport = null;
      }
    }

    final profiles = <AreaProfile>[];
    for (final entry in populationByKey.entries) {
      final master = mastersByKey[entry.key];
      if (master == null) {
        continue;
      }

      final population = _firstField(entry.value, const ['population', 'pop']);
      final populationValue = population == null
          ? null
          : (population * 1000).round();
      final incomeRecords = incomeByKey[entry.key] ?? const [];
      final schoolRecords = schoolsByKey[entry.key] ?? const [];
      final crimeRecords = _recordsForAliases(
        entry.key,
        crimeByKey,
        _crimeDistrictAliases,
      );
      final hospitalRecords = _recordsForAliases(
        entry.key,
        hospitalByKey,
        _hospitalDistrictAliases,
      );
      final populationYear = _recordYear(entry.value);
      final incomeYear = _recordYear(incomeRecords);
      final educationYear = _recordYear(schoolRecords);
      final crimeYear = _recordYear(crimeRecords);
      final hospitalYear = _recordYear(hospitalRecords);
      final transportYear = transport?.retrievedAt.year;
      final years = [
        populationYear,
        incomeYear,
        educationYear,
        crimeYear,
        hospitalYear,
        transportYear,
      ].whereType<int>();

      profiles.add(
        AreaProfile(
          areaId: LocationNormalizer.canonicalAreaId(
            master.state,
            master.district,
          ),
          state: master.state,
          district: master.district,
          population: populationValue,
          populationYear: populationYear,
          medianHouseholdIncome: _firstField(incomeRecords, const [
            'income_median',
            'median_income',
            'median_household_income',
          ]),
          incomeYear: incomeYear,
          crimeCount: _sumField(crimeRecords, const [
            'crimes',
            'crime',
            'total',
          ])?.round(),
          crimeYear: crimeYear,
          educationInstitutionCount: _sumField(schoolRecords, const [
            'schools',
            'school',
            'total',
          ])?.round(),
          educationYear: educationYear,
          hospitalBedCount: _firstField(hospitalRecords, const [
            'beds',
            'hospital_beds',
            'total',
          ])?.round(),
          hospitalYear: hospitalYear,
          transportStopCount: transport?.countFor(
            master.state,
            master.district,
          ),
          transportYear: transportYear,
          dataYear: years.isEmpty
              ? null
              : years.reduce((left, right) => left > right ? left : right),
          source: 'OpenDOSM; data.gov.my',
          sourceUrl: _sourceReferences.values.join('; '),
          retrievedAt: retrievedAt,
        ),
      );
    }

    profiles.sort((left, right) {
      final byState = left.state.compareTo(right.state);
      return byState == 0 ? left.district.compareTo(right.district) : byState;
    });
    return profiles;
  }

  Future<List<Map<String, dynamic>>> _criticalRows(
    String label,
    Future<List<Map<String, dynamic>>> request,
    List<String> failures,
  ) async {
    try {
      final rows = await request;
      if (rows.isEmpty) {
        failures.add('$label: no records returned');
      }
      return rows;
    } catch (error) {
      failures.add('$label: $error');
      return const [];
    }
  }

  Future<List<Map<String, dynamic>>> _optionalRows(
    String _,
    Future<List<Map<String, dynamic>>> request,
  ) async {
    try {
      return await request;
    } catch (_) {
      return const [];
    }
  }

  Future<List<Map<String, dynamic>>> _fetchDataset(String datasetId) async {
    final uri = Uri.parse(
      _apiBase,
    ).replace(queryParameters: {'id': datasetId, 'limit': '100000'});
    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      throw Exception(
        'data.gov.my request failed for $datasetId (${response.statusCode}).',
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is List) {
      return decoded.whereType<Map>().map(Map<String, dynamic>.from).toList();
    }
    if (decoded is Map) {
      for (final key in ['data', 'results', 'records']) {
        final records = decoded[key];
        if (records is List) {
          return records
              .whereType<Map>()
              .map(Map<String, dynamic>.from)
              .toList();
        }
      }
    }
    return const [];
  }

  Future<List<Map<String, dynamic>>> _fetchPopulationDataset() async {
    final csvRows = await _fetchCsv(_populationDistrictCsv);
    if (csvRows.isNotEmpty) {
      return csvRows;
    }
    throw Exception('the CSV returned no records');
  }

  Future<List<Map<String, dynamic>>> _fetchCrimeDataset() async {
    final csvRows = await _fetchCsv(_crimeDistrictCsv);
    if (csvRows.isNotEmpty) {
      return csvRows;
    }
    throw Exception('the CSV returned no records');
  }

  Future<List<Map<String, dynamic>>> _fetchCsv(String url) async {
    final response = await _client.get(Uri.parse(url));
    if (response.statusCode != 200) {
      throw Exception('CSV dataset request failed (${response.statusCode}).');
    }
    return _parseCsv(response.body);
  }

  List<Map<String, dynamic>> _parseCsv(String source) {
    final rows = <List<String>>[];
    final row = <String>[];
    final field = StringBuffer();
    var inQuotes = false;

    for (var index = 0; index < source.length; index++) {
      final char = source[index];
      final next = index + 1 < source.length ? source[index + 1] : '';
      if (char == '"') {
        if (inQuotes && next == '"') {
          field.write('"');
          index += 1;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (char == ',' && !inQuotes) {
        row.add(field.toString());
        field.clear();
      } else if ((char == '\n' || char == '\r') && !inQuotes) {
        if (char == '\r' && next == '\n') {
          index += 1;
        }
        row.add(field.toString());
        field.clear();
        if (row.any((value) => value.trim().isNotEmpty)) {
          rows.add(List<String>.from(row));
        }
        row.clear();
      } else {
        field.write(char);
      }
    }
    if (field.isNotEmpty || row.isNotEmpty) {
      row.add(field.toString());
      rows.add(List<String>.from(row));
    }
    if (rows.isEmpty) {
      return const [];
    }

    final headers = rows.first;
    return rows.skip(1).map((values) {
      final record = <String, dynamic>{};
      for (var index = 0; index < headers.length; index++) {
        record[headers[index]] = index < values.length ? values[index] : '';
      }
      return record;
    }).toList();
  }

  Map<String, List<Map<String, dynamic>>> _latestRecordsByLocation(
    List<Map<String, dynamic>> records, {
    bool Function(Map<String, dynamic> record)? predicate,
  }) {
    final byKey = <String, List<Map<String, dynamic>>>{};
    for (final record in records) {
      if (predicate != null && !predicate(record)) {
        continue;
      }
      final key = _recordLocationKey(record);
      if (key == null) {
        continue;
      }
      byKey.putIfAbsent(key, () => []).add(record);
    }

    return byKey.map((key, records) {
      final latestYear = records
          .map(_recordYearFromMap)
          .whereType<int>()
          .fold<int?>(null, (latest, year) {
            if (latest == null || year > latest) {
              return year;
            }
            return latest;
          });
      if (latestYear == null) {
        return MapEntry(key, records);
      }
      return MapEntry(
        key,
        records
            .where((record) => _recordYearFromMap(record) == latestYear)
            .toList(),
      );
    });
  }

  List<Map<String, dynamic>> _recordsForAliases(
    String masterKey,
    Map<String, List<Map<String, dynamic>>> rowsByKey,
    Map<String, List<String>> aliasMap,
  ) {
    final exact = rowsByKey[masterKey];
    if (exact != null && exact.isNotEmpty) {
      return exact;
    }

    final aliases = aliasMap[masterKey];
    if (aliases == null) {
      return const [];
    }

    final stateKey = masterKey.split('|').first;
    final records = <Map<String, dynamic>>[];
    for (final alias in aliases) {
      records.addAll(
        rowsByKey['$stateKey|'
                '${LocationNormalizer.canonicalDistrictIdForState(stateKey, alias)}'] ??
            const [],
      );
    }
    return records;
  }

  _MasterDistrict? _masterDistrict(List<Map<String, dynamic>> records) {
    for (final record in records) {
      final state = LocationNormalizer.displayStateName(record['state']);
      final district = LocationNormalizer.displayDistrictName(
        record['district'],
        state: state,
      );
      if (state.isNotEmpty && district.isNotEmpty) {
        return _MasterDistrict(state, district);
      }
    }
    return null;
  }

  String? _recordLocationKey(Map<String, dynamic> record) {
    final key = LocationNormalizer.stateDistrictKey(
      record['state'],
      record['district'],
    );
    return key.startsWith('|') || key.endsWith('|') ? null : key;
  }

  int? _recordYear(List<Map<String, dynamic>> records) {
    final years = records.map(_recordYearFromMap).whereType<int>();
    if (years.isEmpty) {
      return null;
    }
    return years.reduce((left, right) => left > right ? left : right);
  }

  int? _recordYearFromMap(Map<String, dynamic> record) {
    for (final field in ['date', 'year', 'tahun']) {
      final value = record[field];
      if (value == null) {
        continue;
      }
      final text = value.toString().trim();
      if (text.length >= 4) {
        final year = int.tryParse(text.substring(0, 4));
        if (year != null) {
          return year;
        }
      }
    }
    return null;
  }

  num? _sumField(List<Map<String, dynamic>> records, List<String> fields) {
    var total = 0.0;
    var found = false;
    for (final record in records) {
      for (final field in fields) {
        final value = _parseNumber(record[field]);
        if (value != null) {
          total += value;
          found = true;
          break;
        }
      }
    }
    return found ? total : null;
  }

  double? _firstField(List<Map<String, dynamic>> records, List<String> fields) {
    for (final record in records) {
      for (final field in fields) {
        final value = _parseNumber(record[field]);
        if (value != null) {
          return value.toDouble();
        }
      }
    }
    return null;
  }

  num? _parseNumber(Object? value) {
    if (value == null || value == '') {
      return null;
    }
    if (value is num) {
      return value;
    }
    final text = value.toString().replaceAll(',', '').trim();
    if (text.isEmpty) {
      return null;
    }
    return num.tryParse(text);
  }

  String _normaliseText(Object? value) {
    return value
        .toString()
        .trim()
        .toLowerCase()
        .replaceAll('-', ' ')
        .replaceAll('_', ' ')
        .replaceAll(RegExp(r'\s+'), ' ');
  }
}

class _MasterDistrict {
  const _MasterDistrict(this.state, this.district);

  final String state;
  final String district;
}

class GovernmentDataRefreshException implements Exception {
  const GovernmentDataRefreshException(this.failures);

  final List<String> failures;

  @override
  String toString() =>
      'Some government datasets could not be refreshed: ${failures.join('; ')}';
}
