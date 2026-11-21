import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class CustomAlbumRecord {
  final String id;
  final String name;
  final String? parentId;
  final bool isFolder;
  final bool isDeleted;

  const CustomAlbumRecord({
    required this.id,
    required this.name,
    this.parentId,
    required this.isFolder,
    this.isDeleted = false,
  });

  factory CustomAlbumRecord.fromJson(Map<String, dynamic> json) {
    return CustomAlbumRecord(
      id: json['id'].toString(),
      name: json['name'] as String? ?? '',
      parentId: json['parent_id']?.toString(),
      isFolder: json['is_folder'] == true,
      isDeleted: json['is_deleted'] == true,
    );
  }
}

class CustomPhotoRecord {
  final int id;
  final String filename;
  final String year;
  final String dateFolder;
  final String captureDate;
  final int width;
  final int height;
  final int fileSize;
  final bool isVideo;
  final String? driveId;
  final String? cameraModel;
  final String? country;
  final String? city;
  final List<String> albums;

  const CustomPhotoRecord({
    required this.id,
    required this.filename,
    required this.year,
    this.dateFolder = '',
    this.captureDate = '',
    this.width = 0,
    this.height = 0,
    this.fileSize = 0,
    this.isVideo = false,
    this.driveId,
    this.cameraModel,
    this.country,
    this.city,
    required this.albums,
  });

  factory CustomPhotoRecord.fromJson(Map<String, dynamic> json) {
    final rawAlbums = json['albums'];
    List<String> parsedAlbums = [];
    if (rawAlbums is List) {
      parsedAlbums = rawAlbums.map((e) => e.toString()).toList();
    } else if (rawAlbums is String && rawAlbums.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawAlbums);
        if (decoded is List) {
          parsedAlbums = decoded.map((e) => e.toString()).toList();
        }
      } catch (_) {}
    }

    return CustomPhotoRecord(
      id: (json['id'] as num).toInt(),
      filename: json['filename'] as String? ?? '',
      year: json['year'] as String? ?? '2026',
      dateFolder: json['date_folder'] as String? ?? '',
      captureDate: json['capture_date'] as String? ?? '',
      width: (json['width'] as num?)?.toInt() ?? 0,
      height: (json['height'] as num?)?.toInt() ?? 0,
      fileSize: (json['file_size'] as num?)?.toInt() ?? 0,
      isVideo: json['is_video'] == true,
      driveId: json['drive_id'] as String?,
      cameraModel: json['camera_model'] as String?,
      country: json['country'] as String?,
      city: json['city'] as String?,
      albums: parsedAlbums,
    );
  }
}

class PhotoOverrideRecord {
  final int photoId;
  final List<String> addedAlbums;
  final List<String> removedAlbums;
  final bool isDeleted;

  const PhotoOverrideRecord({
    required this.photoId,
    required this.addedAlbums,
    required this.removedAlbums,
    this.isDeleted = false,
  });

  factory PhotoOverrideRecord.fromJson(Map<String, dynamic> json) {
    List<String> parseList(dynamic raw) {
      if (raw is List) return raw.map((e) => e.toString()).toList();
      if (raw is String && raw.isNotEmpty) {
        try {
          final d = jsonDecode(raw);
          if (d is List) return d.map((e) => e.toString()).toList();
        } catch (_) {}
      }
      return [];
    }

    return PhotoOverrideRecord(
      photoId: (json['photo_id'] as num).toInt(),
      addedAlbums: parseList(json['added_albums']),
      removedAlbums: parseList(json['removed_albums']),
      isDeleted: json['is_deleted'] == true,
    );
  }
}

class CloudDeltaState {
  final List<CustomAlbumRecord> customAlbums;
  final List<CustomPhotoRecord> customPhotos;
  final Map<int, PhotoOverrideRecord> overridesByPhotoId;
  final bool tableReady;

  const CloudDeltaState({
    required this.customAlbums,
    required this.customPhotos,
    required this.overridesByPhotoId,
    this.tableReady = true,
  });
}

class CloudSyncService {
  CloudSyncService._();

  static const String supabaseUrl = 'https://wnhewgsaedayonccynen.supabase.co';
  static const String supabasePublishableKey =
      'sb_publishable_WZopMcHkGcXRFexLWqFl8g_xInYIwBm';

  static const String remoteCatalogUrl =
      'https://raw.githubusercontent.com/bdewev18-droid/Gallerie/main/assets/data/catalog.json';

  static Map<String, String> get _headers => {
        'apikey': supabasePublishableKey,
        'Authorization': 'Bearer $supabasePublishableKey',
        'Content-Type': 'application/json',
      };

  /// Extrait un ID Google Drive à partir d'une URL Drive complète ou d'un ID brut
  static String? extractDriveId(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return null;

    // Format /file/d/<ID>/view ou /d/<ID>
    final fileMatch = RegExp(r'/d/([a-zA-Z0-9_-]{15,})').firstMatch(trimmed);
    if (fileMatch != null) return fileMatch.group(1);

    // Format ?id=<ID>
    final idParamMatch = RegExp(r'[?&]id=([a-zA-Z0-9_-]{15,})').firstMatch(trimmed);
    if (idParamMatch != null) return idParamMatch.group(1);

    // Format ID brut
    if (RegExp(r'^[a-zA-Z0-9_-]{15,}$').hasMatch(trimmed)) {
      return trimmed;
    }
    return trimmed;
  }

  /// Charge toutes les modifications collaboratives depuis Supabase
  static Future<CloudDeltaState> fetchCloudDeltas() async {
    try {
      final albumsUri = Uri.parse('$supabaseUrl/rest/v1/custom_albums?select=*&order=created_at.asc');
      final photosUri = Uri.parse('$supabaseUrl/rest/v1/custom_photos?select=*&order=created_at.desc');
      final overridesUri = Uri.parse('$supabaseUrl/rest/v1/photo_overrides?select=*');

      final results = await Future.wait([
        http.get(albumsUri, headers: _headers).timeout(const Duration(seconds: 6)),
        http.get(photosUri, headers: _headers).timeout(const Duration(seconds: 6)),
        http.get(overridesUri, headers: _headers).timeout(const Duration(seconds: 6)),
      ]);

      // Si les tables n'ont pas encore été créées dans Supabase (404 / PGRST205)
      if (results[0].statusCode == 404 || results[0].statusCode == 401) {
        return const CloudDeltaState(
          customAlbums: [],
          customPhotos: [],
          overridesByPhotoId: {},
          tableReady: false,
        );
      }

      final customAlbums = <CustomAlbumRecord>[];
      if (results[0].statusCode == 200) {
        final list = jsonDecode(results[0].body) as List<dynamic>;
        customAlbums.addAll(list.map((e) => CustomAlbumRecord.fromJson(e as Map<String, dynamic>)));
      }

      final customPhotos = <CustomPhotoRecord>[];
      if (results[1].statusCode == 200) {
        final list = jsonDecode(results[1].body) as List<dynamic>;
        customPhotos.addAll(list.map((e) => CustomPhotoRecord.fromJson(e as Map<String, dynamic>)));
      }

      final overrides = <int, PhotoOverrideRecord>{};
      if (results[2].statusCode == 200) {
        final list = jsonDecode(results[2].body) as List<dynamic>;
        for (final item in list) {
          final rec = PhotoOverrideRecord.fromJson(item as Map<String, dynamic>);
          overrides[rec.photoId] = rec;
        }
      }

      return CloudDeltaState(
        customAlbums: customAlbums,
        customPhotos: customPhotos,
        overridesByPhotoId: overrides,
        tableReady: true,
      );
    } catch (e) {
      debugPrint('CloudSyncService.fetchCloudDeltas error: $e');
      return const CloudDeltaState(
        customAlbums: [],
        customPhotos: [],
        overridesByPhotoId: {},
        tableReady: false,
      );
    }
  }

  /// Crée un nouveau dossier ou album dans Supabase
  static Future<bool> createCustomAlbum({
    required String id,
    required String name,
    String? parentId,
    required bool isFolder,
  }) async {
    try {
      final uri = Uri.parse('$supabaseUrl/rest/v1/custom_albums');
      final response = await http
          .post(
            uri,
            headers: {
              ..._headers,
              'Prefer': 'resolution=merge-duplicates',
            },
            body: jsonEncode({
              'id': id,
              'name': name.trim(),
              'parent_id': parentId,
              'is_folder': isFolder,
              'is_deleted': false,
            }),
          )
          .timeout(const Duration(seconds: 8));
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      debugPrint('CloudSyncService.createCustomAlbum error: $e');
      return false;
    }
  }

  /// Ajoute une nouvelle photo ou vidéo Google Drive dans Supabase
  static Future<bool> addCustomPhoto(CustomPhotoRecord photo) async {
    try {
      final uri = Uri.parse('$supabaseUrl/rest/v1/custom_photos');
      final response = await http
          .post(
            uri,
            headers: {
              ..._headers,
              'Prefer': 'resolution=merge-duplicates',
            },
            body: jsonEncode({
              'id': photo.id,
              'filename': photo.filename,
              'year': photo.year,
              'date_folder': photo.dateFolder,
              'capture_date': photo.captureDate,
              'width': photo.width,
              'height': photo.height,
              'file_size': photo.fileSize,
              'is_video': photo.isVideo,
              'drive_id': photo.driveId,
              'camera_model': photo.cameraModel,
              'country': photo.country,
              'city': photo.city,
              'albums': photo.albums,
            }),
          )
          .timeout(const Duration(seconds: 8));
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      debugPrint('CloudSyncService.addCustomPhoto error: $e');
      return false;
    }
  }

  /// Associe ou retire un album sur une photo, ou la met à la corbeille
  static Future<bool> savePhotoOverride(PhotoOverrideRecord overrideRec) async {
    try {
      final uri = Uri.parse('$supabaseUrl/rest/v1/photo_overrides');
      final response = await http
          .post(
            uri,
            headers: {
              ..._headers,
              'Prefer': 'resolution=merge-duplicates',
            },
            body: jsonEncode({
              'photo_id': overrideRec.photoId,
              'added_albums': overrideRec.addedAlbums,
              'removed_albums': overrideRec.removedAlbums,
              'is_deleted': overrideRec.isDeleted,
              'deleted_at': overrideRec.isDeleted ? DateTime.now().toUtc().toIso8601String() : null,
              'updated_at': DateTime.now().toUtc().toIso8601String(),
            }),
          )
          .timeout(const Duration(seconds: 8));
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      debugPrint('CloudSyncService.savePhotoOverride error: $e');
      return false;
    }
  }

  /// Récupère éventuellement un catalog.json plus récent depuis GitHub
  static Future<Map<String, dynamic>?> fetchRemoteCatalogIfUpdated(int localPhotoCount) async {
    try {
      final uri = Uri.parse('$remoteCatalogUrl?t=${DateTime.now().millisecondsSinceEpoch ~/ 60000}');
      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final photos = data['photos'] as List<dynamic>?;
      if (photos != null && photos.length != localPhotoCount) {
        return data;
      }
    } catch (_) {}
    return null;
  }
}
