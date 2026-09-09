import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/utils/location_normalizer.dart';
import '../models/area_profile.dart';

class OpenDataService {
  OpenDataService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

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
  };

  static const _crimeDistrictAliases = {
    'selangor|petaling': [
      'Petaling Jaya',
      'Shah Alam',
      'Subang Jaya',
      'Sungai Buloh',
      'Serdang',
    ],
    'selangor|ulu_langat': ['Kajang', 'Ampang Jaya'],
    'johor|johor_bahru': ['Johor Bahru Selatan', 'Johor Bahru Utara'],
  };

  Future<List<AreaProfile>> fetchAreaProfiles() async {
    final retrievedAt = DateTime.now().toUtc();
    final populationRows = await _fetchCsv(_populationDistrictCsv);
    final incomeRows = await _fetchDataset('hh_income_district');
    final schoolRows = await _fetchDataset('schools_district');
    final crimeRows = await _fetchCsv(_crimeDistrictCsv);

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

    final profiles = <AreaProfile>[];
    for (final entry in populationByKey.entries) {
      final master = _masterDistrict(entry.value);
      if (master == null) {
        continue;
      }

      final key = entry.key;
      final population = _firstField(entry.value, const ['population', 'pop']);
      final populationValue = population == null
          ? null
          : (population * 1000).round();
      final incomeRecords = incomeByKey[key] ?? const [];
      final schoolRecords = schoolsByKey[key] ?? const [];
      final crimeRecords = _crimeRecordsFor(key, crimeByKey);
      final years = [
        _recordYear(entry.value),
        _recordYear(incomeRecords),
        _recordYear(schoolRecords),
        _recordYear(crimeRecords),
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
          populationYear: _recordYear(entry.value),
          medianHouseholdIncome: _firstField(incomeRecords, const [
            'income_median',
            'median_income',
            'median_household_income',
          ]),
          incomeYear: _recordYear(incomeRecords),
          crimeCount: _sumField(crimeRecords, const [
            'crimes',
            'crime',
            'total',
          ])?.round(),
          crimeYear: _recordYear(crimeRecords),
          educationInstitutionCount: _sumField(schoolRecords, const [
            'schools',
            'school',
            'total',
          ])?.round(),
          educationYear: _recordYear(schoolRecords),
          transportStopCount: null,
          transportYear: null,
          dataYear: years.isEmpty
              ? null
              : years.reduce((a, b) => a > b ? a : b),
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

  Future<List<Map<String, dynamic>>> _fetchDataset(String datasetId) async {
    final uri = Uri.parse(
      _apiBase,
    ).replace(queryParameters: {'id': datasetId, 'limit': '5000'});
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

  List<Map<String, dynamic>> _crimeRecordsFor(
    String masterKey,
    Map<String, List<Map<String, dynamic>>> crimeByKey,
  ) {
    final exact = crimeByKey[masterKey];
    if (exact != null && exact.isNotEmpty) {
      return exact;
    }

    final aliases = _crimeDistrictAliases[masterKey];
    if (aliases == null) {
      return const [];
    }

    final stateKey = masterKey.split('|').first;
    final records = <Map<String, dynamic>>[];
    for (final alias in aliases) {
      records.addAll(
        crimeByKey['$stateKey|${LocationNormalizer.canonicalDistrictId(alias)}'] ??
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
      );
      if (state.isNotEmpty && district.isNotEmpty) {
        return _MasterDistrict(state, district);
      }
    }
    return null;
  }

  String? _recordLocationKey(Map<String, dynamic> record) {
    final state = LocationNormalizer.canonicalStateId(record['state']);
    final district = LocationNormalizer.canonicalDistrictId(record['district']);
    if (state.isEmpty || district.isEmpty) {
      return null;
    }
    return '$state|$district';
  }

  int? _recordYear(List<Map<String, dynamic>> records) {
    final years = records.map(_recordYearFromMap).whereType<int>();
    if (years.isEmpty) {
      return null;
    }
    return years.reduce((a, b) => a > b ? a : b);
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
    return num.tryParse(value.toString().replaceAll(',', '').trim());
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
