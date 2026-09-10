import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:http/http.dart' as http;

import '../core/utils/location_normalizer.dart';

class TransportSnapshot {
  const TransportSnapshot({
    required this.stopCounts,
    required this.retrievedAt,
  });

  final Map<String, int> stopCounts;
  final DateTime retrievedAt;

  int? countFor(String state, String district) {
    return stopCounts[TransportDataService.locationKey(state, district)];
  }
}

class TransportDataService {
  TransportDataService({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  static const districtBoundaryUrl =
      'https://raw.githubusercontent.com/dosm-malaysia/data-open/main/'
      'datasets/geodata/administrative_2_district.geojson';

  static const _feeds = <String, String>{
    'ktmb': 'https://api.data.gov.my/gtfs-static/ktmb',
    'rapid-bus-kl':
        'https://api.data.gov.my/gtfs-static/prasarana?category=rapid-bus-kl',
    'rapid-bus-mrtfeeder':
        'https://api.data.gov.my/gtfs-static/prasarana?category=rapid-bus-mrtfeeder',
    'rapid-rail-kl':
        'https://api.data.gov.my/gtfs-static/prasarana?category=rapid-rail-kl',
  };

  Future<TransportSnapshot> fetchStopCounts({
    required List<(String state, String district)> targets,
  }) async {
    final boundaries = await _fetchBoundaries(targets);
    if (boundaries.isEmpty) {
      throw Exception('No matching district boundaries were returned.');
    }

    final uniqueStops = <String, _Stop>{};
    var successfulFeeds = 0;
    for (final entry in _feeds.entries) {
      try {
        final stops = await _fetchStops(entry.value);
        successfulFeeds++;
        for (final stop in stops) {
          final coordinateKey =
              '${stop.latitude.toStringAsFixed(5)}|'
              '${stop.longitude.toStringAsFixed(5)}';
          uniqueStops.putIfAbsent(coordinateKey, () => stop);
        }
      } catch (_) {
        // A single operator must not discard data returned by other operators.
      }
    }
    if (successfulFeeds == 0) {
      throw Exception('All official GTFS feeds failed.');
    }

    final counts = <String, int>{
      for (final boundary in boundaries) boundary.key: 0,
    };
    for (final stop in uniqueStops.values) {
      for (final boundary in boundaries) {
        if (boundary.contains(stop.longitude, stop.latitude)) {
          counts.update(boundary.key, (value) => value + 1);
          break;
        }
      }
    }

    return TransportSnapshot(
      stopCounts: counts,
      retrievedAt: DateTime.now().toUtc(),
    );
  }

  Future<List<_DistrictBoundary>> _fetchBoundaries(
    List<(String state, String district)> targets,
  ) async {
    final response = await _client.get(Uri.parse(districtBoundaryUrl));
    if (response.statusCode != 200) {
      throw Exception(
        'District boundary request failed (${response.statusCode}).',
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map || decoded['features'] is! List) return const [];

    final targetKeys = {
      for (final target in targets) locationKey(target.$1, target.$2),
    };
    final boundaries = <_DistrictBoundary>[];
    for (final item in decoded['features'] as List) {
      if (item is! Map) continue;
      final properties = item['properties'];
      final geometry = item['geometry'];
      if (properties is! Map || geometry is! Map) continue;
      final key = locationKey(
        properties['state']?.toString() ?? '',
        properties['district']?.toString() ?? '',
      );
      if (!targetKeys.contains(key)) continue;
      final polygons = _readPolygons(geometry);
      if (polygons.isNotEmpty) {
        boundaries.add(_DistrictBoundary(key, polygons));
      }
    }
    return boundaries;
  }

  Future<List<_Stop>> _fetchStops(String url) async {
    final response = await _client.get(Uri.parse(url));
    if (response.statusCode != 200) {
      throw Exception('GTFS request failed (${response.statusCode}).');
    }
    final archive = ZipDecoder().decodeBytes(response.bodyBytes);
    final file = archive.findFile('stops.txt');
    if (file == null) return const [];
    final csv = utf8.decode(file.content as List<int>);
    final rows = _parseCsv(csv);
    final stops = <_Stop>[];
    for (final row in rows) {
      final locationType = row['location_type']?.trim() ?? '';
      if (locationType.isNotEmpty && locationType != '0') continue;
      final latitude = double.tryParse(row['stop_lat'] ?? '');
      final longitude = double.tryParse(row['stop_lon'] ?? '');
      if (latitude != null && longitude != null) {
        stops.add(_Stop(latitude, longitude));
      }
    }
    return stops;
  }

  static List<List<List<_Point>>> _readPolygons(Map geometry) {
    final type = geometry['type']?.toString();
    final coordinates = geometry['coordinates'];
    if (coordinates is! List) return const [];

    if (type == 'Polygon') {
      final polygon = _readPolygon(coordinates);
      return polygon.isEmpty ? const [] : [polygon];
    }
    if (type == 'MultiPolygon') {
      return coordinates
          .whereType<List>()
          .map(_readPolygon)
          .where((polygon) => polygon.isNotEmpty)
          .toList();
    }
    return const [];
  }

  static List<List<_Point>> _readPolygon(List coordinates) {
    return coordinates
        .whereType<List>()
        .map((ring) {
          return ring
              .whereType<List>()
              .where((coordinate) {
                return coordinate.length >= 2 &&
                    coordinate[0] is num &&
                    coordinate[1] is num;
              })
              .map((coordinate) {
                return _Point(
                  (coordinate[0] as num).toDouble(),
                  (coordinate[1] as num).toDouble(),
                );
              })
              .toList();
        })
        .where((ring) => ring.length >= 3)
        .toList();
  }

  static List<Map<String, String>> _parseCsv(String source) {
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

  static List<String> _parseCsvLine(String line) {
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

  static String locationKey(String state, String district) {
    return LocationNormalizer.stateDistrictKey(state, district);
  }
}

class _DistrictBoundary {
  const _DistrictBoundary(this.key, this.polygons);

  final String key;
  final List<List<List<_Point>>> polygons;

  bool contains(double longitude, double latitude) {
    for (final polygon in polygons) {
      if (polygon.isEmpty || !_insideRing(polygon.first, longitude, latitude)) {
        continue;
      }
      final insideHole = polygon
          .skip(1)
          .any((ring) => _insideRing(ring, longitude, latitude));
      if (!insideHole) return true;
    }
    return false;
  }

  bool _insideRing(List<_Point> ring, double x, double y) {
    var inside = false;
    for (var i = 0, j = ring.length - 1; i < ring.length; j = i++) {
      final xi = ring[i].longitude;
      final yi = ring[i].latitude;
      final xj = ring[j].longitude;
      final yj = ring[j].latitude;
      final crosses =
          ((yi > y) != (yj > y)) && (x < (xj - xi) * (y - yi) / (yj - yi) + xi);
      if (crosses) inside = !inside;
    }
    return inside;
  }
}

class _Point {
  const _Point(this.longitude, this.latitude);

  final double longitude;
  final double latitude;
}

class _Stop {
  const _Stop(this.latitude, this.longitude);

  final double latitude;
  final double longitude;
}
