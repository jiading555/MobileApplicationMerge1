import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/area_profile.dart';

class OpenDataService {
  OpenDataService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _apiBase = 'https://api.data.gov.my/data-catalogue';
  static const _populationDistrictCsv =
      'https://storage.dosm.gov.my/population/population_district.csv';
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
    'hospital_beds': 'https://data.gov.my/data-catalogue/hospital_beds',
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

  static const _hospitalDistrictAliases = {
    'selangor|petaling': ['Petaling (Subang Jaya)'],
    'selangor|gombak': ['Gombak (Rawang)'],
    'selangor|ulu langat': ['Hulu Langat (Bangi)'],
    'johor|johor bahru': ['Johor Bahru'],
    'penang|timur laut': ['Timur Laut (Georgetown)'],
  };

  Future<List<AreaProfile>> fetchAreaProfiles({
    List<(String state, String district)> targets = defaultTargets,
  }) async {
    final results = await Future.wait<List<Map<String, dynamic>>>([
      _fetchPopulationDataset(),
      _fetchDataset('hh_income_district'),
      _fetchDataset('schools_district'),
      _fetchDataset('crime_district'),
      _fetchDataset('hospital_beds'),
    ]);
    return targets
        .map(
          (target) => _buildAreaProfile(
            target.$1,
            target.$2,
            populationRows: results[0],
            incomeRows: results[1],
            schoolRows: results[2],
            allCrimeRows: results[3],
            hospitalRows: results[4],
          ),
        )
        .toList();
  }

  AreaProfile _buildAreaProfile(
    String state,
    String district, {
    required List<Map<String, dynamic>> populationRows,
    required List<Map<String, dynamic>> incomeRows,
    required List<Map<String, dynamic>> schoolRows,
    required List<Map<String, dynamic>> allCrimeRows,
    required List<Map<String, dynamic>> hospitalRows,
  }) {
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
        incomeRows,
        state,
        district,
      ),
    );
    final schools = _newest(
      _filterLocation(
        schoolRows,
        state,
        district,
      ),
    );
    final crime = _newest(allCrimeRows);
    final hospitalBeds = _newest(
      _filterHospitalLocation(hospitalRows, state, district)
          .where((record) => _normaliseText(record['type']) == 'all')
          .toList(),
    );

    final latestPopulation = _firstField(population, 'population');
    final populationValue = latestPopulation == null
        ? null
        : (latestPopulation * 1000).round();
    final crimeRows = _filterCrimeLocation(crime, state, district);
    final incomeYear = _recordYear(income);
    final populationYear = _recordYear(population);
    final educationYear = _recordYear(schools);
    final crimeYear = _recordYear(crime);
    final hospitalYear = _recordYear(hospitalBeds);
    final years = [
      populationYear,
      incomeYear,
      educationYear,
      crimeYear,
      hospitalYear,
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
      hospitalBedCount: _firstField(hospitalBeds, 'beds')?.round(),
      hospitalYear: hospitalYear,
      transportStopCount: null,
      transportYear: null,
      dataYear: years.isEmpty ? null : years.reduce((a, b) => a > b ? a : b),
      source: 'OpenDOSM; data.gov.my',
      sourceUrl: _sourceReferences.values.join('; '),
      retrievedAt: DateTime.now().toUtc(),
    );
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
    final apiRows = await _fetchDataset('population_district');
    if (apiRows.isNotEmpty) return apiRows;
    return _fetchCsv(_populationDistrictCsv);
  }

  Future<List<Map<String, dynamic>>> _fetchCsv(String url) async {
    final response = await _client.get(Uri.parse(url));
    if (response.statusCode != 200) {
      throw Exception('Government CSV request failed (${response.statusCode}).');
    }
    return _parseCsv(response.body);
  }

  List<Map<String, dynamic>> _parseCsv(String source) {
    final lines = const LineSplitter().convert(source);
    if (lines.isEmpty) return const [];
    final headers = _parseCsvLine(lines.first);
    return lines.skip(1).where((line) => line.trim().isNotEmpty).map((line) {
      final values = _parseCsvLine(line);
      return {
        for (var index = 0; index < headers.length; index++)
          headers[index]: index < values.length ? values[index] : '',
      };
    }).toList();
  }

  List<String> _parseCsvLine(String line) {
    final values = <String>[];
    final field = StringBuffer();
    var inQuotes = false;
    for (var index = 0; index < line.length; index++) {
      final char = line[index];
      if (char == '"') {
        if (inQuotes && index + 1 < line.length && line[index + 1] == '"') {
          field.write('"');
          index++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (char == ',' && !inQuotes) {
        values.add(field.toString());
        field.clear();
      } else {
        field.write(char);
      }
    }
    values.add(field.toString());
    return values;
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

  List<Map<String, dynamic>> _filterHospitalLocation(
    List<Map<String, dynamic>> records,
    String state,
    String district,
  ) {
    final stateKey = _normaliseText(state);
    final aliases =
        _hospitalDistrictAliases['$stateKey|${_normaliseText(district)}'] ??
        [district];
    final aliasKeys = aliases.map(_normaliseText).toSet();
    return records.where((record) {
      return _normaliseText(record['state']) == stateKey &&
          aliasKeys.contains(_normaliseText(record['district']));
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
