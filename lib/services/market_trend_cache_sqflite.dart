import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

import '../models/area_data.dart';

class MarketTrendCacheEntry {
  const MarketTrendCacheEntry({required this.areas, required this.updatedAt});

  final List<AreaData> areas;
  final DateTime updatedAt;

  bool isFreshAt(DateTime now) {
    final age = now.toUtc().difference(updatedAt.toUtc());
    return !age.isNegative && age < const Duration(days: 1);
  }
}

class MarketTrendCache {
  static const _databaseName = 'smart_property_advisor.db';
  static const _tableName = 'market_trend_cache';
  static const _snapshotId = 1;

  Database? _database;

  bool get _isSupportedPlatform =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  Future<Database> _openDatabase() async {
    final existing = _database;
    if (existing != null) return existing;

    final database = await openDatabase(
      path.join(await getDatabasesPath(), _databaseName),
      version: 1,
      onCreate: (db, _) async {
        await db.execute(
          'CREATE TABLE $_tableName ('
          'id INTEGER PRIMARY KEY, '
          'payload TEXT NOT NULL, '
          'updated_at TEXT NOT NULL'
          ')',
        );
      },
    );
    _database = database;
    return database;
  }

  Future<MarketTrendCacheEntry?> load() async {
    if (!_isSupportedPlatform) return null;

    final database = await _openDatabase();
    final rows = await database.query(
      _tableName,
      where: 'id = ?',
      whereArgs: const [_snapshotId],
      limit: 1,
    );
    if (rows.isEmpty) return null;

    final payload = rows.first['payload'] as String?;
    final updatedAtText = rows.first['updated_at'] as String?;
    if (payload == null || updatedAtText == null) return null;

    final decoded = jsonDecode(payload);
    final updatedAt = DateTime.tryParse(updatedAtText);
    if (decoded is! List || updatedAt == null) return null;

    final areas = decoded
        .whereType<Map>()
        .map((item) => AreaData.fromCacheJson(Map<String, dynamic>.from(item)))
        .toList();
    return MarketTrendCacheEntry(areas: areas, updatedAt: updatedAt);
  }

  Future<void> save(List<AreaData> areas, {required DateTime updatedAt}) async {
    if (!_isSupportedPlatform) return;

    final database = await _openDatabase();
    await database.insert(_tableName, {
      'id': _snapshotId,
      'payload': jsonEncode(areas.map((area) => area.toCacheJson()).toList()),
      'updated_at': updatedAt.toUtc().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}
