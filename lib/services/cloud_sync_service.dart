import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

enum AuthStatus { unknown, signedOut, signingIn, signedIn }

class AuthUserSession {
  final AuthStatus status;
  final String? userId;
  final String? email;
  final String? displayName;
  final String? avatarUrl;

  const AuthUserSession({
    required this.status,
    this.userId,
    this.email,
    this.displayName,
    this.avatarUrl,
  });

  bool get isSignedIn => status == AuthStatus.signedIn && (email?.isNotEmpty ?? false);

  String get shortLabel {
    if (displayName != null && displayName!.trim().isNotEmpty) {
      return displayName!.trim();
    }
    if (email != null && email!.isNotEmpty) {
      return email!.split('@').first;
    }
    return 'Invité';
  }

  static const AuthUserSession unknown = AuthUserSession(status: AuthStatus.unknown);
  static const AuthUserSession signedOut = AuthUserSession(status: AuthStatus.signedOut);
  static const AuthUserSession signingIn = AuthUserSession(status: AuthStatus.signingIn);
}

class CustomAlbumRecord {
  final String id;
  final String name;
  final String? parentId;
  final bool isFolder;
  final bool isDeleted;
  final String? createdByEmail;
  final String? createdByName;

  const CustomAlbumRecord({
    required this.id,
    required this.name,
    this.parentId,
    required this.isFolder,
    this.isDeleted = false,
    this.createdByEmail,
    this.createdByName,
  });

  factory CustomAlbumRecord.fromJson(Map<String, dynamic> json) {
    return CustomAlbumRecord(
      id: json['id'].toString(),
      name: json['name'] as String? ?? '',
      parentId: json['parent_id']?.toString(),
      isFolder: json['is_folder'] == true,
      isDeleted: json['is_deleted'] == true,
      createdByEmail: json['created_by_email'] as String?,
      createdByName: json['created_by_name'] as String?,
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
  final String? addedByEmail;
  final String? addedByName;

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
    this.addedByEmail,
    this.addedByName,
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
      addedByEmail: json['added_by_email'] as String?,
      addedByName: json['added_by_name'] as String?,
    );
  }
}

class PhotoOverrideRecord {
  final int photoId;
  final List<String> addedAlbums;
  final List<String> removedAlbums;
  final bool isDeleted;
  final String? updatedByEmail;
  final String? updatedByName;

  const PhotoOverrideRecord({
    required this.photoId,
    required this.addedAlbums,
    required this.removedAlbums,
    this.isDeleted = false,
    this.updatedByEmail,
    this.updatedByName,
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
      updatedByEmail: json['updated_by_email'] as String?,
      updatedByName: json['updated_by_name'] as String?,
    );
  }
}

class PhotoLikeRecord {
  final int photoId;
  final String userEmail;
  final String userName;

  const PhotoLikeRecord({
    required this.photoId,
    required this.userEmail,
    required this.userName,
  });

  factory PhotoLikeRecord.fromJson(Map<String, dynamic> json) {
    return PhotoLikeRecord(
      photoId: (json['photo_id'] as num).toInt(),
      userEmail: json['user_email'] as String? ?? '',
      userName: json['user_name'] as String? ?? '',
    );
  }
}

class CloudDeltaState {
  final List<CustomAlbumRecord> customAlbums;
  final List<CustomPhotoRecord> customPhotos;
  final Map<int, PhotoOverrideRecord> overridesByPhotoId;
  final Map<int, List<PhotoLikeRecord>> likesByPhotoId;
  final bool tableReady;

  const CloudDeltaState({
    required this.customAlbums,
    required this.customPhotos,
    required this.overridesByPhotoId,
    required this.likesByPhotoId,
    this.tableReady = true,
  });
}

class CloudSyncService {
  CloudSyncService._();

  static const String supabaseUrl = 'https://wnhewgsaedayonccynen.supabase.co';
  static const String supabasePublishableKey =
      'sb_publishable_WZopMcHkGcXRFexLWqFl8g_xInYIwBm';

  /// Web OAuth Client ID Google Cloud (format xxxx.apps.googleusercontent.com)
  /// Même projet Google Cloud Console que vos autres projets.
  static const String googleWebClientId =
      '46362990646-g8jlqo1t641ivopje5ebojjnrccrv2hb.apps.googleusercontent.com';

  static const String remoteCatalogUrl =
      'https://raw.githubusercontent.com/bdewev18-droid/Gallerie/main/assets/data/catalog.json';

  static bool _initialized = false;
  static late final GoogleSignIn _googleSignIn;
  static final StreamController<AuthUserSession> _authController =
      StreamController<AuthUserSession>.broadcast();
  static AuthUserSession _currentAuth = AuthUserSession.signedOut;

  static Stream<AuthUserSession> get authStream => _authController.stream;
  static AuthUserSession get currentAuth => _currentAuth;

  /// Initialise Supabase Auth + GoogleSignIn
  static Future<void> initialize() async {
    if (_initialized) return;
    try {
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabasePublishableKey,
      );
      if (!kIsWeb) {
        _googleSignIn = GoogleSignIn(
          scopes: const ['email', 'openid', 'profile'],
          signInOption: SignInOption.standard,
          serverClientId: googleWebClientId.isEmpty ? null : googleWebClientId,
          forceCodeForRefreshToken: false,
        );
      }

      Supabase.instance.client.auth.onAuthStateChange.listen((data) {
        _updateFromSupabaseSession(data.session);
      });
      _updateFromSupabaseSession(Supabase.instance.client.auth.currentSession);
      _initialized = true;
    } catch (e) {
      debugPrint('CloudSyncService.initialize error: $e');
      rethrow;
    }
  }

  static void _updateFromSupabaseSession(Session? session) {
    if (session == null) {
      _currentAuth = AuthUserSession.signedOut;
    } else {
      final user = session.user;
      final meta = user.userMetadata ?? {};
      final fullName = (meta['full_name'] ?? meta['name'])?.toString();
      final avatar = (meta['avatar_url'] ?? meta['picture'])?.toString();
      _currentAuth = AuthUserSession(
        status: AuthStatus.signedIn,
        userId: user.id,
        email: user.email,
        displayName: fullName,
        avatarUrl: avatar,
      );
    }
    _authController.add(_currentAuth);
  }

  /// Connexion Google (Web : OAuth Redirect Supabase, Android : GoogleSignIn + signInWithIdToken)
  static Future<AuthUserSession> signInWithGoogle() async {
    if (!_initialized) {
      await initialize();
    }
    _currentAuth = AuthUserSession.signingIn;
    _authController.add(_currentAuth);

    try {
      final client = Supabase.instance.client;
      if (kIsWeb) {
        final redirect = _webRedirectUrl();
        await client.auth.signInWithOAuth(
          OAuthProvider.google,
          redirectTo: redirect,
        );
        return _currentAuth;
      }

      GoogleSignInAccount? account;
      try {
        account = await _googleSignIn.signInSilently();
      } catch (_) {}
      account ??= await _googleSignIn.signIn();

      if (account == null) {
        _currentAuth = AuthUserSession.signedOut;
        _authController.add(_currentAuth);
        throw StateError(
          'Connexion Google annulée ou SHA-1 du keystore non déclaré dans Google Cloud Console '
          '(Package: com.dewevre.gallerie, SHA-1: 2A:23:B2:2E:FB:C2:76:3B:DC:14:D5:17:7C:63:65:9D:49:1F:32:96).',
        );
      }

      final googleAuth = await account.authentication;
      final idToken = googleAuth.idToken;
      final accessToken = googleAuth.accessToken;

      if (idToken == null || idToken.isEmpty) {
        _currentAuth = AuthUserSession.signedOut;
        _authController.add(_currentAuth);
        throw StateError(
          'idToken Google vide. Vérifiez que le client OAuth Android (com.dewevre.gallerie) '
          'et le Web Client ID sont configurés dans Google Cloud Console et Supabase.',
        );
      }

      final response = await client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );
      _updateFromSupabaseSession(response.session);
      return _currentAuth;
    } catch (e) {
      _currentAuth = AuthUserSession.signedOut;
      _authController.add(_currentAuth);
      rethrow;
    }
  }

  /// Déconnexion Google & Supabase
  static Future<void> signOut() async {
    try {
      if (_initialized) {
        await Supabase.instance.client.auth.signOut();
      }
    } catch (_) {}
    try {
      if (!kIsWeb && await _googleSignIn.isSignedIn()) {
        await _googleSignIn.signOut();
      }
    } catch (_) {}
    _currentAuth = AuthUserSession.signedOut;
    _authController.add(_currentAuth);
  }

  static String _webRedirectUrl() {
    const String path = 'Gallerie/';
    const String fallback = 'http://127.0.0.1:8084/Gallerie/';
    try {
      final uri = Uri.base;
      if (uri.host.isEmpty) return fallback;
      final origin = '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}/';
      return '$origin$path';
    } catch (_) {
      return fallback;
    }
  }

  static Map<String, String> get _headers {
    String bearer = supabasePublishableKey;
    if (_initialized) {
      final session = Supabase.instance.client.auth.currentSession;
      if (session != null && session.accessToken.isNotEmpty) {
        bearer = session.accessToken;
      }
    }
    return {
      'apikey': supabasePublishableKey,
      'Authorization': 'Bearer $bearer',
      'Content-Type': 'application/json',
    };
  }

  /// Extrait un ID Google Drive à partir d'une URL Drive complète ou d'un ID brut
  static String? extractDriveId(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return null;

    final fileMatch = RegExp(r'/d/([a-zA-Z0-9_-]{15,})').firstMatch(trimmed);
    if (fileMatch != null) return fileMatch.group(1);

    final idParamMatch = RegExp(r'[?&]id=([a-zA-Z0-9_-]{15,})').firstMatch(trimmed);
    if (idParamMatch != null) return idParamMatch.group(1);

    if (RegExp(r'^[a-zA-Z0-9_-]{15,}$').hasMatch(trimmed)) {
      return trimmed;
    }
    return trimmed;
  }

  /// Charge toutes les modifications collaboratives et les likes depuis Supabase
  static Future<CloudDeltaState> fetchCloudDeltas() async {
    try {
      final albumsUri = Uri.parse('$supabaseUrl/rest/v1/custom_albums?select=*&order=created_at.asc');
      final photosUri = Uri.parse('$supabaseUrl/rest/v1/custom_photos?select=*&order=created_at.desc');
      final overridesUri = Uri.parse('$supabaseUrl/rest/v1/photo_overrides?select=*');
      final likesUri = Uri.parse('$supabaseUrl/rest/v1/photo_likes?select=*&order=created_at.asc');

      final results = await Future.wait([
        http.get(albumsUri, headers: _headers).timeout(const Duration(seconds: 6)),
        http.get(photosUri, headers: _headers).timeout(const Duration(seconds: 6)),
        http.get(overridesUri, headers: _headers).timeout(const Duration(seconds: 6)),
        http.get(likesUri, headers: _headers).timeout(const Duration(seconds: 6)),
      ]);

      if (results[0].statusCode == 404 || results[0].statusCode == 401) {
        return const CloudDeltaState(
          customAlbums: [],
          customPhotos: [],
          overridesByPhotoId: {},
          likesByPhotoId: {},
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

      final likesByPhoto = <int, List<PhotoLikeRecord>>{};
      if (results[3].statusCode == 200) {
        final list = jsonDecode(results[3].body) as List<dynamic>;
        for (final item in list) {
          final like = PhotoLikeRecord.fromJson(item as Map<String, dynamic>);
          likesByPhoto.putIfAbsent(like.photoId, () => []).add(like);
        }
      }

      return CloudDeltaState(
        customAlbums: customAlbums,
        customPhotos: customPhotos,
        overridesByPhotoId: overrides,
        likesByPhotoId: likesByPhoto,
        tableReady: true,
      );
    } catch (e) {
      debugPrint('CloudSyncService.fetchCloudDeltas error: $e');
      return const CloudDeltaState(
        customAlbums: [],
        customPhotos: [],
        overridesByPhotoId: {},
        likesByPhotoId: {},
        tableReady: false,
      );
    }
  }

  /// Crée un nouveau dossier ou album dans Supabase avec l'auteur connecté
  static Future<bool> createCustomAlbum({
    required String id,
    required String name,
    String? parentId,
    required bool isFolder,
  }) async {
    try {
      final uri = Uri.parse('$supabaseUrl/rest/v1/custom_albums');
      final payload = <String, dynamic>{
        'id': id,
        'name': name.trim(),
        'parent_id': parentId,
        'is_folder': isFolder,
        'is_deleted': false,
      };
      if (_currentAuth.isSignedIn) {
        payload['created_by_email'] = _currentAuth.email;
        payload['created_by_name'] = _currentAuth.shortLabel;
      }

      final response = await http
          .post(
            uri,
            headers: {
              ..._headers,
              'Prefer': 'resolution=merge-duplicates',
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 8));
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      debugPrint('CloudSyncService.createCustomAlbum error: $e');
      return false;
    }
  }

  /// Ajoute une nouvelle photo ou vidéo Google Drive dans Supabase avec l'auteur connecté
  static Future<bool> addCustomPhoto(CustomPhotoRecord photo) async {
    try {
      final uri = Uri.parse('$supabaseUrl/rest/v1/custom_photos');
      final payload = <String, dynamic>{
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
      };
      if (_currentAuth.isSignedIn) {
        payload['added_by_email'] = _currentAuth.email;
        payload['added_by_name'] = _currentAuth.shortLabel;
      }

      final response = await http
          .post(
            uri,
            headers: {
              ..._headers,
              'Prefer': 'resolution=merge-duplicates',
            },
            body: jsonEncode(payload),
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
      final payload = <String, dynamic>{
        'photo_id': overrideRec.photoId,
        'added_albums': overrideRec.addedAlbums,
        'removed_albums': overrideRec.removedAlbums,
        'is_deleted': overrideRec.isDeleted,
        'deleted_at': overrideRec.isDeleted ? DateTime.now().toUtc().toIso8601String() : null,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };
      if (_currentAuth.isSignedIn) {
        payload['updated_by_email'] = _currentAuth.email;
        payload['updated_by_name'] = _currentAuth.shortLabel;
      }

      final response = await http
          .post(
            uri,
            headers: {
              ..._headers,
              'Prefer': 'resolution=merge-duplicates',
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 8));
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      debugPrint('CloudSyncService.savePhotoOverride error: $e');
      return false;
    }
  }

  /// Ajoute ou retire un Like ("J'aime") sur une photo pour l'utilisateur connecté
  static Future<bool> togglePhotoLike({
    required int photoId,
    required bool isCurrentlyLiked,
  }) async {
    if (!_currentAuth.isSignedIn || _currentAuth.email == null) return false;
    final email = _currentAuth.email!;
    final name = _currentAuth.shortLabel;

    try {
      if (isCurrentlyLiked) {
        final uri = Uri.parse(
          '$supabaseUrl/rest/v1/photo_likes?photo_id=eq.$photoId&user_email=eq.${Uri.encodeQueryComponent(email)}',
        );
        final response = await http.delete(uri, headers: _headers).timeout(const Duration(seconds: 6));
        return response.statusCode >= 200 && response.statusCode < 300;
      } else {
        final uri = Uri.parse('$supabaseUrl/rest/v1/photo_likes');
        final response = await http
            .post(
              uri,
              headers: {
                ..._headers,
                'Prefer': 'resolution=merge-duplicates',
              },
              body: jsonEncode({
                'photo_id': photoId,
                'user_email': email,
                'user_name': name,
              }),
            )
            .timeout(const Duration(seconds: 6));
        return response.statusCode >= 200 && response.statusCode < 300;
      }
    } catch (e) {
      debugPrint('CloudSyncService.togglePhotoLike error: $e');
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
