import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/area_profile.dart';

class OpenDataService {
  OpenDataService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _apiBase = 'https://api.data.gov.my/data-catalogue';
  static const _populationDistrictCsv =
      'https://storage.dosm.gov.my/population/population_district.csv';
  static const _crimeDistrictCsv =
      'https://storage.data.gov.my/publicsafety/crime_district.csv';

  static const defaultTargets = [
    ('Selangor', 'Petaling'),
    ('Selangor', 'Gombak'),
    ('Selangor', 'Ulu Langat'),
    ('Johor', 'Johor Bahru'),
    ('Pulau Pinang', 'Timur Laut'),
  ];

  static const _sourceReferences = {
    'population_district':
        'https://open.dosm.gov.my/data-catalogue/population_district',
    'hh_income_district':
        'https://open.dosm.gov.my/data-catalogue/hh_income_district',
    'crime_district': 'https://data.gov.my/data-catalogue/crime_district',
    'schools_district': 'https://data.gov.my/data-catalogue/schools_district',
  };

  static const _stateAliases = {
    'pulau pinang': 'penang',
    'p pinang': 'penang',
    'w.p. kuala lumpur': 'kuala lumpur',
    'wp kuala lumpur': 'kuala lumpur',
    'wilayah persekutuan kuala lumpur': 'kuala lumpur',
    'w.p. putrajaya': 'putrajaya',
    'wp putrajaya': 'putrajaya',
    'w.p. labuan': 'labuan',
    'wp labuan': 'labuan',
  };

  static const _displayNames = {'penang': 'Pulau Pinang'};

  static const _crimeDistrictAliases = {
    'selangor|petaling': [
      'Petaling Jaya',
      'Shah Alam',
      'Subang Jaya',
      'Sungai Buloh',
      'Serdang',
    ],
    'selangor|gombak': ['Gombak'],
    'selangor|ulu langat': ['Kajang', 'Ampang Jaya'],
    'johor|johor bahru': ['Johor Bahru Selatan', 'Johor Bahru Utara'],
    'penang|timur laut': ['Timur Laut'],
  };

  Future<List<AreaProfile>> fetchAreaProfiles({
    List<(String state, String district)> targets = defaultTargets,
  }) async {
    final profiles = <AreaProfile>[];
    for (final target in targets) {
      profiles.add(await _fetchAreaProfile(target.$1, target.$2));
    }
    return profiles;
  }

  Future<AreaProfile> _fetchAreaProfile(String state, String district) async {
    final populationRows = await _fetchCsv(_populationDistrictCsv);
    final population = _newest(
      _filterLocation(populationRows, state, district)
          .where(
            (record) =>
                _normaliseText(record['sex']) == 'both' &&
                _normaliseText(record['age']) == 'overall' &&
                _normaliseText(record['ethnicity']) == 'overall',
          )
          .toList(),
    );
    final income = _newest(
      _filterLocation(
        await _fetchDataset('hh_income_district', {
          'state': state,
          'district': district,
        }),
        state,
        district,
      ),
    );
    final schools = _newest(
      _filterLocation(
        await _fetchDataset('schools_district', {
          'state': state,
          'district': district,
        }),
        state,
        district,
      ),
    );
    final crime = _newest(await _fetchCsv(_crimeDistrictCsv));

    final latestPopulation = _firstField(population, 'population');
    final populationValue = latestPopulation == null
        ? null
        : (latestPopulation * 1000).round();
    final crimeRows = _filterCrimeLocation(crime, state, district);
    final incomeYear = _recordYear(income);
    final populationYear = _recordYear(population);
    final educationYear = _recordYear(schools);
    final crimeYear = _recordYear(crime);
    final years = [
      populationYear,
      incomeYear,
      educationYear,
      crimeYear,
    ].whereType<int>();

    return AreaProfile(
      areaId:
          '${_normaliseText(state).replaceAll(' ', '_')}_'
          '${_normaliseText(district).replaceAll(' ', '_')}',
      state: _titleText(state),
      district: _titleText(district),
      population: populationValue,
      populationYear: populationYear,
      medianHouseholdIncome: _firstField(income, 'income_median'),
      incomeYear: incomeYear,
      crimeCount: _sumField(crimeRows, 'crimes')?.round(),
      crimeYear: crimeYear,
      educationInstitutionCount: _sumField(schools, 'schools')?.round(),
      educationYear: educationYear,
      transportStopCount: null,
      transportYear: null,
      dataYear: years.isEmpty ? null : years.reduce((a, b) => a > b ? a : b),
      source: 'OpenDOSM; data.gov.my',
      sourceUrl: _sourceReferences.values.join('; '),
      retrievedAt: DateTime.now().toUtc(),
    );
  }

  Future<List<Map<String, dynamic>>> _fetchDataset(
    String datasetId,
    Map<String, String> filters,
  ) async {
    final uri = Uri.parse(
      _apiBase,
    ).replace(queryParameters: {'id': datasetId, 'limit': '5000', ...filters});
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

  List<Map<String, dynamic>> _newest(List<Map<String, dynamic>> records) {
    final dated = records.where((record) => record['date'] != null).toList();
    if (dated.isEmpty) {
      return records;
    }
    dated.sort(
      (left, right) =>
          right['date'].toString().compareTo(left['date'].toString()),
    );
    final latest = dated.first['date'];
    return dated.where((record) => record['date'] == latest).toList();
  }

  int? _recordYear(List<Map<String, dynamic>> records) {
    for (final record in records) {
      final date = record['date']?.toString().trim() ?? '';
      if (date.length >= 4) {
        return int.tryParse(date.substring(0, 4));
      }
    }
    return null;
  }

  List<Map<String, dynamic>> _filterLocation(
    List<Map<String, dynamic>> records,
    String state,
    String district,
  ) {
    final stateKey = _normaliseText(state);
    final districtKey = _normaliseText(district);
    return records.where((record) {
      return _normaliseText(record['state']) == stateKey &&
          _normaliseText(record['district']) == districtKey;
    }).toList();
  }

  List<Map<String, dynamic>> _filterCrimeLocation(
    List<Map<String, dynamic>> records,
    String state,
    String district,
  ) {
    final stateKey = _normaliseText(state);
    final districtKey = _normaliseText(district);
    final aliases =
        _crimeDistrictAliases['$stateKey|$districtKey'] ?? [district];
    final aliasKeys = aliases.map(_normaliseText).toSet();
    return records.where((record) {
      return _normaliseText(record['state']) == stateKey &&
          aliasKeys.contains(_normaliseText(record['district'])) &&
          _normaliseText(record['type']) == 'all';
    }).toList();
  }

  num? _sumField(List<Map<String, dynamic>> records, String field) {
    var total = 0.0;
    var found = false;
    for (final record in records) {
      final value = _parseNumber(record[field]);
      if (value != null) {
        total += value;
        found = true;
      }
    }
    return found ? total : null;
  }

  double? _firstField(List<Map<String, dynamic>> records, String field) {
    for (final record in records) {
      final value = _parseNumber(record[field]);
      if (value != null) {
        return value.toDouble();
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

  String _titleText(Object? value) {
    final normalised = _normaliseText(value);
    final display = _displayNames[normalised];
    if (display != null) {
      return display;
    }
    return normalised
        .split(' ')
        .map(
          (part) => part.isEmpty
              ? part
              : '${part[0].toUpperCase()}${part.substring(1)}',
        )
        .join(' ');
  }

  String _normaliseText(Object? value) {
    final text = value
        .toString()
        .trim()
        .toLowerCase()
        .replaceAll('-', ' ')
        .replaceAll('_', ' ')
        .replaceAll(RegExp(r'\s+'), ' ');
    return _stateAliases[text] ?? text;
  }
}
