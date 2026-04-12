import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart' as pp;
import 'package:sqflite/sqflite.dart';
import '../models/plant.dart';

/// SQLite-backed saved guides and plant detail cache.
class GuideDatabase {
  static Database? _db;

  static Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  static Future<Database> _initDb() async {
    final path = join(await getDatabasesPath(), 'foragecast_guides.db');
    return openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE saved_guides (
            id TEXT PRIMARY KEY,
            location_name TEXT,
            lat REAL NOT NULL,
            lng REAL NOT NULL,
            date_start TEXT NOT NULL,
            date_end TEXT NOT NULL,
            coverage_score REAL NOT NULL,
            plants_json TEXT NOT NULL,
            saved_at TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE cached_plants (
            id TEXT PRIMARY KEY,
            detail_json TEXT NOT NULL,
            cached_at TEXT NOT NULL
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS cached_plants (
              id TEXT PRIMARY KEY,
              detail_json TEXT NOT NULL,
              cached_at TEXT NOT NULL
            )
          ''');
        }
      },
    );
  }

  // ── Guide operations ──

  static Future<void> saveGuide(Guide guide) async {
    final db = await database;
    await db.insert(
      'saved_guides',
      {
        'id': guide.id,
        'location_name': guide.locationName,
        'lat': guide.lat,
        'lng': guide.lng,
        'date_start': guide.dateStart.toIso8601String(),
        'date_end': guide.dateEnd.toIso8601String(),
        'coverage_score': guide.coverageScore,
        'plants_json': jsonEncode(guide.plants.map((p) => p.toJson()).toList()),
        'saved_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<List<SavedGuideEntry>> listGuides() async {
    final db = await database;
    final rows = await db.query('saved_guides', orderBy: 'saved_at DESC');
    return rows.map((row) => SavedGuideEntry.fromRow(row)).toList();
  }

  static Future<Guide?> loadGuide(String id) async {
    final db = await database;
    final rows = await db.query('saved_guides', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    final row = rows.first;
    final plants = (jsonDecode(row['plants_json'] as String) as List)
        .map((p) => PredictedPlant.fromJson(p))
        .toList();
    return Guide(
      id: row['id'] as String,
      lat: row['lat'] as double,
      lng: row['lng'] as double,
      locationName: row['location_name'] as String?,
      dateStart: DateTime.parse(row['date_start'] as String),
      dateEnd: DateTime.parse(row['date_end'] as String),
      coverageScore: row['coverage_score'] as double,
      plants: plants,
    );
  }

  static Future<void> deleteGuide(String id) async {
    final db = await database;
    await db.delete('saved_guides', where: 'id = ?', whereArgs: [id]);
  }

  static Future<bool> isGuideSaved(String id) async {
    final db = await database;
    final rows = await db.query('saved_guides', where: 'id = ?', whereArgs: [id], columns: ['id']);
    return rows.isNotEmpty;
  }

  static Future<void> deleteAll() async {
    final db = await database;
    await db.delete('saved_guides');
    await db.delete('cached_plants');
  }

  // ── Plant detail cache ──

  static Future<void> cachePlantDetail(PlantDetail detail) async {
    final db = await database;
    final json = {
      'id': detail.id,
      'common_name': detail.commonName,
      'scientific_name': detail.scientificName,
      'family': detail.family,
      'edibility_rating': detail.edibilityRating,
      'medicinal_rating': detail.medicinalRating,
      'physical': detail.physical?.toJson(),
      'edible_parts': detail.edibleParts.map((e) => {'part': e.part, 'preparation': e.preparation}).toList(),
      'traditional_uses': detail.traditionalUses,
      'warnings': detail.warnings.map((w) => {'type': w.type, 'severity': w.severity, 'title': w.title, 'description': w.description, 'test': w.test}).toList(),
      'photos': detail.photos.map((p) => {'url': p.url, 'label': p.label, 'attribution': p.attribution}).toList(),
      'data_sources': detail.dataSources,
    };
    await db.insert(
      'cached_plants',
      {
        'id': detail.id,
        'detail_json': jsonEncode(json),
        'cached_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Download and cache images for a plant's photos to local storage.
  static Future<void> cacheImages(PlantDetail detail) async {
    final dir = await _imageDir();
    final client = http.Client();
    try {
      for (final photo in detail.photos) {
        try {
          final filename = _imageFilename(photo.url);
          final file = File(join(dir.path, filename));
          if (await file.exists()) continue;
          final resp = await client.get(Uri.parse(photo.url)).timeout(
            const Duration(seconds: 15),
          );
          if (resp.statusCode == 200) {
            await file.writeAsBytes(resp.bodyBytes);
          }
        } catch (_) {
          // Skip failed downloads
        }
      }
    } finally {
      client.close();
    }
  }

  /// Get local file path for a cached image, or null if not cached.
  static Future<String?> getCachedImagePath(String url) async {
    final dir = await _imageDir();
    final file = File(join(dir.path, _imageFilename(url)));
    if (await file.exists()) return file.path;
    return null;
  }

  static Future<Directory> _imageDir() async {
    final appDir = await pp.getApplicationDocumentsDirectory();
    final imgDir = Directory(join(appDir.path, 'cached_images'));
    if (!await imgDir.exists()) await imgDir.create(recursive: true);
    return imgDir;
  }

  static String _imageFilename(String url) {
    // Hash the URL to a safe filename
    final hash = url.hashCode.toUnsigned(32).toRadixString(16);
    final ext = url.contains('.jpeg') ? '.jpeg' : '.jpg';
    return 'img_$hash$ext';
  }

  static Future<PlantDetail?> getCachedPlantDetail(String plantId) async {
    final db = await database;
    final rows = await db.query('cached_plants', where: 'id = ?', whereArgs: [plantId]);
    if (rows.isEmpty) return null;
    final json = jsonDecode(rows.first['detail_json'] as String) as Map<String, dynamic>;
    return PlantDetail.fromJson(json);
  }
}

/// Lightweight entry for listing saved guides.
class SavedGuideEntry {
  final String id;
  final String? locationName;
  final double lat;
  final double lng;
  final DateTime dateStart;
  final DateTime dateEnd;
  final double coverageScore;
  final int plantCount;
  final DateTime savedAt;

  SavedGuideEntry({
    required this.id,
    required this.locationName,
    required this.lat,
    required this.lng,
    required this.dateStart,
    required this.dateEnd,
    required this.coverageScore,
    required this.plantCount,
    required this.savedAt,
  });

  factory SavedGuideEntry.fromRow(Map<String, dynamic> row) {
    final plants = jsonDecode(row['plants_json'] as String) as List;
    return SavedGuideEntry(
      id: row['id'] as String,
      locationName: row['location_name'] as String?,
      lat: row['lat'] as double,
      lng: row['lng'] as double,
      dateStart: DateTime.parse(row['date_start'] as String),
      dateEnd: DateTime.parse(row['date_end'] as String),
      coverageScore: row['coverage_score'] as double,
      plantCount: plants.length,
      savedAt: DateTime.parse(row['saved_at'] as String),
    );
  }
}
