import 'dart:convert';

import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

import '../models/property.dart';

class TeduhService {
  TeduhService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _baseUrl = 'https://teduh.kpkt.gov.my';
  static const _projectsPath = '/api/portal/projects';
  static const _filtersPath = '/api/portal/projects/filters';
  static const _projectsPagePath = '/projek';
  static const _source = 'TEDUH - Jabatan Perumahan Negara, KPKT';

  static const targetStates = [
    'Johor',
    'Kedah',
    'Kelantan',
    'Melaka',
    'Negeri Sembilan',
    'Pahang',
    'Pulau Pinang',
    'Perak',
    'Perlis',
    'Sabah',
    'Sarawak',
    'Selangor',
    'Terengganu',
  ];

  Future<List<Property>> fetchProjects({
    int maxRecords = 24,
    int maxPerState = 10,
    bool sampleByState = true,
    String? scheme,
  }) async {
    final retrievedAt = DateTime.now().toUtc();
    final stateLookup = await _fetchStateLookup();

    final htmlProjects = await _fetchProjectsFromHtml(retrievedAt);
    if (htmlProjects.isNotEmpty) {
      return _dedupe(htmlProjects).take(maxRecords).toList();
    }

    final rawRecords = <Map<String, dynamic>>[];
    if (sampleByState) {
      final stateCodes = await _fetchStateCodeLookup();
      for (final state in targetStates) {
        rawRecords.addAll(
          await _fetchProjectPages(maxPerState, {
            'state': stateCodes[_normalise(state)] ?? state,
            if (scheme != null && scheme.trim().isNotEmpty)
              'scheme': scheme.trim(),
          }),
        );
      }
    } else {
      rawRecords.addAll(
        await _fetchProjectPages(maxRecords, {
          if (scheme != null && scheme.trim().isNotEmpty)
            'scheme': scheme.trim(),
        }),
      );
    }

    final cleaned = <Property>[];
    for (final raw in rawRecords) {
      final row = _cleanProject(raw, stateLookup, retrievedAt);
      if (row != null) {
        cleaned.add(
          Property.fromTeduhJson(
            row,
            areaId: 'unknown',
            palette: (cleaned.length + 10) % 12,
          ),
        );
      }
    }
    return _dedupe(cleaned).take(maxRecords).toList();
  }

  Future<List<Property>> _fetchProjectsFromHtml(DateTime retrievedAt) async {
    final uri = Uri.https(_host, _projectsPagePath, {
      'source': 'Perumahan Awam',
    });
    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Failed to load TEDUH page (${response.statusCode}).');
    }

    final document = html_parser.parse(response.body);
    if (document.querySelector('#app') == null) {
      return const [];
    }

    final cards = document.querySelectorAll('article.ppam-card');
    if (cards.isEmpty) {
      return const [];
    }

    final projects = <Property>[];
    for (final card in cards) {
      final name = _cleanText(card.querySelector('.footer-title')?.text);
      if (name == null) {
        continue;
      }
      final location = _cleanText(card.querySelector('.footer-loc')?.text);
      final price = _parseNumber(card.querySelector('.price-pill')?.text);
      final state = _titleText(location);
      final sourceId = _htmlSourceId(name, location);
      projects.add(
        Property.fromTeduhJson(
          {
            'source_id': sourceId,
            'project_name': name,
            'state': state,
            'district': null,
            'scheme': null,
            'price_min': price,
            'price_max': price,
            'property_type': null,
            'developer_name': null,
            'source': _source,
            'source_url': uri.toString(),
            'retrieved_at': retrievedAt.toIso8601String(),
            'raw_location': location,
          },
          areaId: 'unknown',
          palette: (projects.length + 10) % 12,
        ),
      );
    }
    return projects;
  }

  Future<List<Map<String, dynamic>>> _fetchProjectPages(
    int maxRecords,
    Map<String, String> params,
  ) async {
    final records = <Map<String, dynamic>>[];
    var page = 1;
    var lastPage = 1;

    while (records.length < maxRecords && page <= lastPage && page <= 50) {
      final payload = await _getJson(_projectsPath, {
        ...params,
        'page': '$page',
      });
      final data = payload['data'];
      if (data is! List) {
        throw Exception('Unexpected TEDUH projects response format.');
      }
      if (data.isEmpty) {
        break;
      }
      records.addAll(data.whereType<Map>().map(Map<String, dynamic>.from));
      lastPage = _parseNumber(payload['last_page'])?.toInt() ?? page;
      page += 1;
    }

    return records.take(maxRecords).toList();
  }

  Future<Map<String, String>> _fetchStateLookup() async {
    final filters = await _getJson(_filtersPath);
    final states = filters['states'];
    final lookup = <String, String>{};
    if (states is List) {
      for (final state in states.whereType<Map>()) {
        final name = _cleanText(state['name']);
        if (name != null) {
          lookup[name.toUpperCase()] = _titleText(name)!;
        }
      }
    }
    return lookup;
  }

  Future<Map<String, String>> _fetchStateCodeLookup() async {
    final filters = await _getJson(_filtersPath);
    final states = filters['states'];
    final lookup = <String, String>{};
    if (states is List) {
      for (final state in states.whereType<Map>()) {
        final name = _cleanText(state['name']);
        final id = _cleanText(state['id'] ?? state['value']);
        if (name != null && id != null) {
          lookup[_normalise(name)] = id;
        }
      }
    }
    return lookup;
  }

  Future<Map<String, dynamic>> _getJson(
    String path, [
    Map<String, String>? params,
  ]) async {
    final response = await _client.get(Uri.https(_host, path, params));
    if (response.statusCode != 200) {
      throw Exception('TEDUH request failed (${response.statusCode}).');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('TEDUH returned an unexpected JSON response.');
    }
    return decoded;
  }

  Map<String, dynamic>? _cleanProject(
    Map<String, dynamic> record,
    Map<String, String> stateLookup,
    DateTime retrievedAt,
  ) {
    final name = _cleanText(record['name']);
    if (name == null) {
      return null;
    }

    final location = _cleanText(record['location']);
    final (state, district) = _splitLocation(location, stateLookup);
    final prices = _collectPrices(record);
    final unitTypes = _collectUnitTypes(record);
    final developer = record['developer'] is Map
        ? Map<String, dynamic>.from(record['developer'] as Map)
        : <String, dynamic>{};

    return {
      'source_id': _cleanText(record['id']) ?? _fallbackSourceId(record, state),
      'project_name': name,
      'state': state,
      'district': district,
      'scheme': _normaliseScheme(record),
      'price_min': prices.$1,
      'price_max': prices.$2,
      'property_type': unitTypes.isEmpty ? null : unitTypes.join('; '),
      'project_status': _cleanText(record['status']),
      'developer_name': _cleanText(developer['name']),
      'address': _cleanText(record['address']),
      'source': _source,
      'source_url': _sourceUrl(),
      'retrieved_at': retrievedAt.toIso8601String(),
      'latitude': _validCoordinate(_parseNumber(record['latitude']), true),
      'longitude': _validCoordinate(_parseNumber(record['longitude']), false),
      'total_units': _parseNumber(record['total_unit'])?.toInt(),
      'available_units': _parseNumber(record['baki_unit'])?.toInt(),
      'unit_types': unitTypes,
      'external_project_url': _cleanText(record['web_url']),
      'developer_address': _cleanText(developer['full_address']),
      'raw_location': location,
    };
  }

  (int?, int?) _collectPrices(Map<String, dynamic> record) {
    final prices = <int>[];
    final units = record['units'];
    if (units is List) {
      for (final unit in units.whereType<Map>()) {
        final price =
            _parseNumber(unit['price_start']) ??
            _parseNumber(unit['price_from_text']);
        if (price != null) {
          prices.add(price.round());
        }
      }
    }
    if (prices.isEmpty) {
      final price = _parseNumber(record['price_text']);
      if (price != null) {
        prices.add(price.round());
      }
    }
    if (prices.isEmpty) {
      return (null, null);
    }
    prices.sort();
    return (prices.first, prices.last);
  }

  List<String> _collectUnitTypes(Map<String, dynamic> record) {
    final seen = <String>{};
    final types = <String>[];
    final units = record['units'];
    if (units is! List) {
      return types;
    }
    for (final unit in units.whereType<Map>()) {
      final rawType =
          _cleanText(unit['house_type']) ?? _cleanText(unit['unit_type']);
      if (rawType == null || rawType == '-') {
        continue;
      }
      final key = rawType.toLowerCase();
      if (seen.add(key)) {
        types.add(rawType);
      }
    }
    return types;
  }

  String? _normaliseScheme(Map<String, dynamic> record) {
    final raw = _cleanText(record['scheme_name']);
    if (raw != null) {
      return raw;
    }

    final sourceId = _cleanText(record['id']) ?? '';
    final prefix = sourceId.split('_').first.toUpperCase();
    const mapping = {
      'PPR': 'Program Perumahan Rakyat (PPR)',
      'PPAM': 'Perumahan Penjawat Awam Malaysia (PPAM)',
      'PR1MA': 'PR1MA Homes',
      'RESIDENSIWILAYAH': 'Residensi Wilayah',
      'SPNB': 'Syarikat Perumahan Negara Berhad (SPNB)',
    };
    if (mapping.containsKey(prefix)) {
      return mapping[prefix];
    }

    final logo = (_cleanText(record['scheme_logo_url']) ?? '').toLowerCase();
    for (final entry in mapping.entries) {
      if (logo.contains(entry.key.toLowerCase())) {
        return entry.value;
      }
    }
    return null;
  }

  (String?, String?) _splitLocation(
    String? location,
    Map<String, String> stateLookup,
  ) {
    final text = _cleanText(location);
    if (text == null) {
      return (null, null);
    }

    final upper = text.toUpperCase();
    if (stateLookup.containsKey(upper)) {
      return (stateLookup[upper], null);
    }

    final parts = upper
        .split(',')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.length >= 2 && stateLookup.containsKey(parts.last)) {
      return (stateLookup[parts.last], _titleText(parts[parts.length - 2]));
    }

    for (final entry in stateLookup.entries) {
      if (upper.endsWith(entry.key)) {
        final beforeState = upper
            .substring(0, upper.length - entry.key.length)
            .trim()
            .replaceAll(RegExp(r',$'), '');
        final district = beforeState.isEmpty
            ? null
            : _titleText(beforeState.split(',').last);
        return (entry.value, district);
      }
    }

    return (_titleText(text), null);
  }

  List<Property> _dedupe(List<Property> records) {
    final seen = <String>{};
    final deduped = <Property>[];
    for (final record in records) {
      final key = record.sourceId ?? record.name;
      if (seen.add(key)) {
        deduped.add(record);
      }
    }
    return deduped;
  }

  String _sourceUrl() {
    return Uri.https(_host, _projectsPagePath, {
      'source': 'Perumahan Awam',
    }).toString();
  }

  String _fallbackSourceId(Map<String, dynamic> record, String? state) {
    final stableText = [
      _cleanText(record['name']),
      state,
      _cleanText(record['location']),
    ].whereType<String>().join('|');
    final slug = stableText
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    return 'teduh-${slug.substring(0, slug.length.clamp(0, 60))}-${_fnv1a(stableText).toRadixString(16)}';
  }

  String _htmlSourceId(String name, String? location) {
    final stableText = '$name|${location ?? ''}';
    final slug = stableText
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    return 'teduh-html-${slug.substring(0, slug.length.clamp(0, 50))}-${_fnv1a(stableText).toRadixString(16)}';
  }

  int _fnv1a(String value) {
    var hash = 0x811c9dc5;
    for (final codeUnit in value.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash;
  }

  num? _parseNumber(Object? value) {
    if (value == null || value is bool) {
      return null;
    }
    if (value is num) {
      return value;
    }
    final text = _cleanText(value);
    if (text == null) {
      return null;
    }
    final numeric = text.replaceAll(RegExp(r'[^\d.]'), '');
    return numeric.isEmpty ? null : num.tryParse(numeric);
  }

  num? _validCoordinate(num? value, bool latitude) {
    if (value == null) {
      return null;
    }
    final min = latitude ? -90 : -180;
    final max = latitude ? 90 : 180;
    return value >= min && value <= max ? value : null;
  }

  String? _cleanText(Object? value) {
    final text = value?.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
    if (text == null ||
        text.isEmpty ||
        text == '-' ||
        text.toLowerCase() == 'n/a' ||
        text.toLowerCase() == 'null') {
      return null;
    }
    return text;
  }

  String? _titleText(Object? value) {
    final text = _cleanText(value);
    if (text == null) {
      return null;
    }
    return text
        .toLowerCase()
        .split(' ')
        .map(
          (part) => part.isEmpty
              ? part
              : '${part[0].toUpperCase()}${part.substring(1)}',
        )
        .join(' ');
  }

  String _normalise(Object? value) {
    return value
        .toString()
        .trim()
        .toLowerCase()
        .replaceAll('-', ' ')
        .replaceAll('_', ' ')
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  String get _host => Uri.parse(_baseUrl).host;
}
