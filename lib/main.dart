import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'services/app_update_service.dart';
import 'services/cloud_sync_service.dart';
import 'widgets/world_map_tab.dart';
import 'widgets/world_wonders.dart';

const int appBuildNumber = 26;
const String appVersionLabel = "1.0.25";

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await CloudSyncService.initialize();
  runApp(const GallerieApp());
}

class GallerieApp extends StatelessWidget {
  const GallerieApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Medias Familly',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFF97316),
          primary: const Color(0xFFF97316),
          secondary: const Color(0xFF0EA5E9),
          tertiary: const Color(0xFF10B981),
          brightness: Brightness.light,
          surface: const Color(0xFFFFFFFF),
        ),
        scaffoldBackgroundColor: const Color(0xFFFFFBF2),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFFFFFFF),
          foregroundColor: Color(0xFF1E293B),
          surfaceTintColor: Colors.transparent,
          elevation: 0,
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: const Color(0xFFFFFFFF),
          indicatorColor: const Color(0xFFF97316).withValues(alpha: 0.16),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

enum PhotoFlagStatus { neutral, pick, reject }

class PhotoRatingRecord {
  final int rating; // 0..5
  final PhotoFlagStatus status;

  const PhotoRatingRecord({this.rating = 0, this.status = PhotoFlagStatus.neutral});

  static PhotoRatingRecord parse(String raw) {
    final parts = raw.split(':');
    final r = (int.tryParse(parts.isNotEmpty ? parts[0] : '0') ?? 0).clamp(0, 5);
    final stName = parts.length > 1 ? parts[1] : 'neutral';
    final st = PhotoFlagStatus.values.firstWhere(
      (e) => e.name == stName,
      orElse: () => PhotoFlagStatus.neutral,
    );
    return PhotoRatingRecord(rating: r, status: st);
  }
}

class PhotoItem {
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
  final double? latitude;
  final double? longitude;
  final List<String> albums;
  final String? addedByName;
  final String? addedByEmail;

  PhotoItem({
    required this.id,
    required this.filename,
    required this.year,
    required this.dateFolder,
    required this.captureDate,
    required this.width,
    required this.height,
    required this.fileSize,
    required this.isVideo,
    this.driveId,
    this.cameraModel,
    this.country,
    this.city,
    this.latitude,
    this.longitude,
    required this.albums,
    this.addedByName,
    this.addedByEmail,
  });

  factory PhotoItem.fromJson(Map<String, dynamic> json) {
    return PhotoItem(
      id: (json['id'] as num).toInt(),
      filename: json['fn'] as String? ?? '',
      year: json['y'] as String? ?? 'unknown_date',
      dateFolder: json['d'] as String? ?? '',
      captureDate: json['dt'] as String? ?? '',
      width: (json['w'] as num?)?.toInt() ?? 0,
      height: (json['h'] as num?)?.toInt() ?? 0,
      fileSize: (json['s'] as num?)?.toInt() ?? 0,
      isVideo: (json['m'] as String? ?? 'p') == 'v',
      driveId: json['gid'] as String?,
      cameraModel: json['cam'] as String?,
      country: json['co'] as String?,
      city: json['ci'] as String?,
      latitude: (json['lat'] as num?)?.toDouble(),
      longitude: (json['lon'] as num?)?.toDouble(),
      albums: (json['al'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
    );
  }

  String? get thumbnailUrl => driveId != null
      ? 'https://lh3.googleusercontent.com/d/$driveId=w400'
      : null;

  String? get largePreviewUrl => driveId != null
      ? 'https://lh3.googleusercontent.com/d/$driveId=w1920'
      : null;

  String getDriveViewUrl(String defaultFolderUrl) {
    if (driveId != null) {
      return 'https://drive.google.com/file/d/$driveId/view';
    }
    return defaultFolderUrl;
  }
}

class AlbumNode {
  final String id;
  final String name;
  final String? parentId;
  final bool isFolder;
  final int directCount;
  final int totalCount;
  final int directVideoCount;
  final int totalVideoCount;
  final String? createdByName;

  AlbumNode({
    required this.id,
    required this.name,
    this.parentId,
    required this.isFolder,
    required this.directCount,
    required this.totalCount,
    this.directVideoCount = 0,
    this.totalVideoCount = 0,
    this.createdByName,
  });

  factory AlbumNode.fromJson(Map<String, dynamic> json) {
    final rawFolder = json['is_folder'];
    final isFolder = rawFolder is bool ? rawFolder : (rawFolder == 1 || rawFolder == '1');
    return AlbumNode(
      id: json['id'].toString(),
      name: json['name'] as String? ?? '',
      parentId: json['parent_id']?.toString(),
      isFolder: isFolder,
      directCount: (json['direct_count'] as num?)?.toInt() ?? 0,
      totalCount: (json['count'] as num?)?.toInt() ?? 0,
    );
  }
}

class ActiveTripConfig {
  final String title;
  final String countryIso;
  final String countryName;
  final String countryFlag;
  final String startDate; // YYYY-MM-DD
  final String endDate;   // YYYY-MM-DD
  final String? createdBy;

  const ActiveTripConfig({
    required this.title,
    required this.countryIso,
    required this.countryName,
    required this.countryFlag,
    required this.startDate,
    required this.endDate,
    this.createdBy,
  });

  String toJsonString() => jsonEncode({
        'title': title,
        'countryIso': countryIso,
        'countryName': countryName,
        'countryFlag': countryFlag,
        'startDate': startDate,
        'endDate': endDate,
        if (createdBy != null) 'createdBy': createdBy,
      });

  static ActiveTripConfig? tryParse(String raw) {
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      return ActiveTripConfig(
        title: m['title'] as String? ?? 'Voyage en cours',
        countryIso: m['countryIso'] as String? ?? 'FRA',
        countryName: m['countryName'] as String? ?? 'France',
        countryFlag: m['countryFlag'] as String? ?? '🌍',
        startDate: m['startDate'] as String? ?? '',
        endDate: m['endDate'] as String? ?? '',
        createdBy: m['createdBy'] as String?,
      );
    } catch (_) {
      return null;
    }
  }
}

class YearItem {
  final String year;
  final int count;

  YearItem({
    required this.year,
    required this.count,
  });

  factory YearItem.fromJson(Map<String, dynamic> json) {
    return YearItem(
      year: json['year'] as String,
      count: json['count'] as int? ?? 0,
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isLoading = true;
  String _gdriveUrl = "https://drive.google.com/drive/folders/1w_szSK4yKM_j0Trk8lT5Zcpcxae_0_iO";
  List<PhotoItem> _allPhotos = [];
  List<PhotoItem> _photosOnly = [];
  List<PhotoItem> _videosOnly = [];
  Map<String, AlbumNode> _nodesById = {};
  Map<String?, List<AlbumNode>> _childrenByParent = {};
  List<YearItem> _photoYears = [];
  List<YearItem> _videoYears = [];

  int _mediaMode = 0; // 0 = Photos, 1 = Vidéos
  int _currentIndex = 0; // 0 = La carte, 1 = Galerie, 2 = Thématiques, 3 = Années, 4 = Recherche
  String? _mapFilterYear;
  bool _showPreHome = true;
  RemoteAppVersion? _pendingUpdate;
  bool _isCheckingUpdate = true;
  bool _updateSkipped = false;
  final List<AlbumNode> _navHistory = [];
  String _albumSearch = '';
  final TextEditingController _albumSearchController = TextEditingController();
  final List<AlbumNode> _yearsNavHistory = [];
  String _yearsSearch = '';
  final TextEditingController _yearsSearchController = TextEditingController();
  bool _isSyncingCloud = false;
  bool _cloudTableReady = true;
  final Map<int, PhotoOverrideRecord> _overridesByPhotoId = {};
  final Map<int, List<PhotoLikeRecord>> _likesByPhotoId = {};
  final Set<String> _customAlbumIds = {};
  final Set<String> _deletedAlbumIds = {};
  final Map<String, String> _albumCountryIsoById = {};

  static const String _kPhotosWrapperId = '6cda9b888a514233bc7edbe3753a3c4a';
  static const String _kYearsRootId = '11335cb33a134da79410f393dc77c9b2';
  static const String _kYear2026Id = '8a27a7356de54a4fa7aae6fdea783597';
  static const String _kPaysFolderId = '2956c2bdbaf04c7984849dbacdb605ab';
  static const String _kCountryMetaParentId = '__country_meta__';
  static const String _kCoverMetaParentId = '__cover_meta__';
  static const String _kRateMetaParentId = '__rate_meta__';
  static const String _kTrashMetaParentId = '__trash_meta__';
  static const String _kPurgeMetaParentId = '__purge_meta__';
  static const String _kTripMetaParentId = '__trip_meta__';
  static const String _kActiveTripNodeId = '__active_trip__';
  static const String _kCollabTripAlbumId = 'collab_voyage_en_cours';
  final Map<String, int> _albumCoverPhotoIdById = {};
  final Map<int, PhotoRatingRecord> _ratingsByPhotoId = {};
  final Map<int, DateTime> _trashedAtByPhotoId = {};
  final Set<int> _purgedPhotoIds = {};
  final List<PhotoItem> _trashedPhotos = [];
  ActiveTripConfig? _activeTrip;
  AuthUserSession _auth = CloudSyncService.currentAuth;
  StreamSubscription<AuthUserSession>? _authSub;

  @override
  void initState() {
    super.initState();
    _authSub = CloudSyncService.authStream.listen((session) {
      if (mounted) {
        setState(() => _auth = session);
      }
    });
    _loadCatalog();
    _checkLaunchUpdate();
  }

  Future<void> _checkLaunchUpdate() async {
    if (mounted) setState(() => _isCheckingUpdate = true);
    final update = await AppUpdateService.checkUpdate();
    if (!mounted) return;
    setState(() {
      _pendingUpdate = update;
      _isCheckingUpdate = false;
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _albumSearchController.dispose();
    _yearsSearchController.dispose();
    super.dispose();
  }

  Future<void> _handleGoogleSignIn() async {
    try {
      await CloudSyncService.signInWithGoogle();
      if (!mounted) return;
      if (_auth.isSignedIn) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFFFFFFF),
            content: Text(
              '✔ Connecté en tant que ${_auth.shortLabel} (${_auth.email})',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        );
      }
    } catch (error) {
      if (!mounted) return;
      showDialog<void>(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          backgroundColor: const Color(0xFFFFFFFF),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: Color(0xFFEBDDC6)),
          ),
          title: const Text('Connexion Google impossible', style: TextStyle(color: const Color(0xFF1E293B), fontSize: 16)),
          content: SingleChildScrollView(
            child: Text('$error', style: const TextStyle(color: Color(0xFF475569), fontSize: 12)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _handleSignOut() async {
    await CloudSyncService.signOut();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: Color(0xFFFFFFFF),
        content: Text('Déconnecté.', style: TextStyle(color: Colors.white, fontSize: 12)),
      ),
    );
  }

  void _showUserAccountSheet() {
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: const Color(0xFFFFFFFF),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFEBDDC6)),
        ),
        title: Row(
          children: [
            Icon(
              _auth.isSignedIn ? Icons.verified_user_outlined : Icons.account_circle_outlined,
              color: _auth.isSignedIn ? const Color(0xFF4ADE80) : const Color(0xFF0EA5E9),
              size: 24,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _auth.isSignedIn ? 'Compte connecté' : 'Connexion Google Famille',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B)),
              ),
            ),
          ],
        ),
        content: _auth.isSignedIn
            ? Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: const Color(0xFFF97316),
                        backgroundImage:
                            (_auth.avatarUrl != null && _auth.avatarUrl!.isNotEmpty) ? NetworkImage(_auth.avatarUrl!) : null,
                        child: (_auth.avatarUrl == null || _auth.avatarUrl!.isEmpty)
                            ? Text(
                                _auth.shortLabel.substring(0, 1).toUpperCase(),
                                style: const TextStyle(fontWeight: FontWeight.bold, color: const Color(0xFF1E293B)),
                              )
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _auth.shortLabel,
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B)),
                            ),
                            Text(
                              _auth.email ?? '',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF6EFE2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Vos "J\'aime" (❤️), nouveaux dossiers et ajouts de photos sont automatiquement associés à votre prénom pour toute la famille.',
                      style: TextStyle(fontSize: 11, color: Color(0xFF475569)),
                    ),
                  ),
                ],
              )
            : const Text(
                'Connectez-vous avec votre compte Google pour aimer des photos (❤️), créer des dossiers ou ajouter des photos associées à votre nom.',
                style: TextStyle(fontSize: 12, color: Color(0xFF475569)),
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Fermer', style: TextStyle(color: Color(0xFF64748B))),
          ),
          if (_auth.isSignedIn)
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.logout, size: 17),
              label: const Text('Se déconnecter'),
              onPressed: () async {
                Navigator.of(dialogCtx).pop();
                await _handleSignOut();
              },
            )
          else
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF97316),
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.login, size: 17),
              label: const Text('Se connecter avec Google'),
              onPressed: () async {
                Navigator.of(dialogCtx).pop();
                await _handleGoogleSignIn();
              },
            ),
        ],
      ),
    );
  }

  Widget _buildAuthHeaderChip({bool compact = false}) {
    final isSigningIn = _auth.status == AuthStatus.signingIn;
    if (isSigningIn) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Chip(
          backgroundColor: const Color(0xFFF6EFE2),
          avatar: const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0EA5E9)),
          ),
          label: Text(compact ? '...' : 'Connexion...', style: const TextStyle(fontSize: 11)),
        ),
      );
    }

    if (_auth.isSignedIn) {
      return Padding(
        padding: const EdgeInsets.only(right: 6),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 10, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFFECFDF5),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF10B981)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFF059669),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                _auth.shortLabel,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF065F46)),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF0EA5E9),
          backgroundColor: const Color(0xFFF6EFE2),
          side: const BorderSide(color: Color(0xFFF97316)),
          visualDensity: VisualDensity.compact,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 12, vertical: 6),
        ),
        onPressed: _handleGoogleSignIn,
        icon: const Icon(Icons.login, size: 15),
        label: Text(compact ? 'Connexion' : 'Connexion Google', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Future<void> _loadCatalog() async {
    try {
      final jsonString = await rootBundle.loadString('assets/data/catalog.json');
      final data = json.decode(jsonString) as Map<String, dynamic>;
      await _applyCatalogData(data);

      // Charger immédiatement les modifications collaboratives Supabase
      await _syncWithCloud(silent: true);

      // Vérifier silencieusement si le catalog.json sur GitHub a reçu de nouveaux exports Lightroom
      final remoteData = await CloudSyncService.fetchRemoteCatalogIfUpdated(_allPhotos.length);
      if (remoteData != null && mounted) {
        await _applyCatalogData(remoteData);
        await _syncWithCloud(silent: true);
      }
    } catch (e) {
      debugPrint("Error loading catalog: $e");
    } finally {
      if (mounted && _isLoading) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _applyCatalogData(Map<String, dynamic> data) async {
    _gdriveUrl = data['gdrive_url'] ?? _gdriveUrl;

    final rawAlbums = data['albums'] as List<dynamic>;
    final albumsList = rawAlbums.map((e) => AlbumNode.fromJson(e)).toList();

    _nodesById = {for (var a in albumsList) a.id: a};
    _normalizeAlbumHierarchy();
    _rebuildChildrenTree();

    final rawYears = data['years'] as List<dynamic>;
    _photoYears = rawYears.map((e) => YearItem.fromJson(e)).toList();

    final rawVideoYears = (data['video_years'] as List<dynamic>?) ?? [];
    _videoYears = rawVideoYears.map((e) => YearItem.fromJson(e)).toList();

    final rawPhotos = data['photos'] as List<dynamic>;

    // Chargement progressif : afficher immédiatement les 60 premiers médias
    const int initialBatchSize = 60;
    const int chunkBatchSize = 1500;
    final int totalCount = rawPhotos.length;
    final int firstEnd = totalCount < initialBatchSize ? totalCount : initialBatchSize;

    final initialItems = <PhotoItem>[];
    final initialPhotos = <PhotoItem>[];
    final initialVideos = <PhotoItem>[];

    for (int i = 0; i < firstEnd; i++) {
      final item = PhotoItem.fromJson(rawPhotos[i] as Map<String, dynamic>);
      initialItems.add(item);
      if (item.isVideo) {
        initialVideos.add(item);
      } else {
        initialPhotos.add(item);
      }
    }

    _allPhotos = initialItems;
    _photosOnly = initialPhotos;
    _videosOnly = initialVideos;

    if (mounted) {
      setState(() => _isLoading = false);
    }

    // Parser le reste en arrière-plan par lots pour ne pas bloquer l'interface
    int currentIdx = firstEnd;
    while (currentIdx < totalCount) {
      await Future<void>.delayed(const Duration(milliseconds: 16));
      if (!mounted) return;
      final int nextEnd = (currentIdx + chunkBatchSize) < totalCount
          ? (currentIdx + chunkBatchSize)
          : totalCount;
      for (int i = currentIdx; i < nextEnd; i++) {
        final item = PhotoItem.fromJson(rawPhotos[i] as Map<String, dynamic>);
        _allPhotos.add(item);
        if (item.isVideo) {
          _videosOnly.add(item);
        } else {
          _photosOnly.add(item);
        }
      }
      currentIdx = nextEnd;
      if (mounted) {
        setState(() {});
      }
    }
    _attachOrphanVideosToYears();
    _rebuildChildrenTree();
    _recalculateAlbumCounts();
    if (mounted) {
      setState(() {});
    }
  }

  void _attachOrphanVideosToYears() {
    if (!_nodesById.containsKey(_kYearsRootId)) return;
    bool nodesAdded = false;

    for (final v in _videosOnly) {
      if (v.albums.any((aid) => _nodesById.containsKey(aid))) continue;

      final hasYear = RegExp(r'^\d{4}$').hasMatch(v.year);
      if (!hasYear) {
        const unknownAlbumId = 'video_unassigned_unknown';
        if (!_nodesById.containsKey(unknownAlbumId)) {
          _nodesById[unknownAlbumId] = AlbumNode(
            id: unknownAlbumId,
            name: 'Vidéos sans date',
            parentId: _kYearsRootId,
            isFolder: false,
            directCount: 0,
            totalCount: 0,
          );
          nodesAdded = true;
        }
        v.albums.add(unknownAlbumId);
        continue;
      }

      final yearStr = v.year;
      final yearCandidates = _nodesById.values
          .where((n) => n.parentId == _kYearsRootId && n.isFolder && n.name == yearStr)
          .toList();
      AlbumNode? targetYearNode;
      if (yearCandidates.isNotEmpty) {
        targetYearNode = yearCandidates.firstWhere(
          (n) => n.totalVideoCount > 0,
          orElse: () => yearCandidates.first,
        );
      } else {
        final newYearId = 'video_year_$yearStr';
        targetYearNode = _nodesById[newYearId] ??
            AlbumNode(
              id: newYearId,
              name: yearStr,
              parentId: _kYearsRootId,
              isFolder: true,
              directCount: 0,
              totalCount: 0,
            );
        if (!_nodesById.containsKey(newYearId)) {
          _nodesById[newYearId] = targetYearNode;
          nodesAdded = true;
        }
      }

      final leafAlbumId = 'video_unassigned_$yearStr';
      if (!_nodesById.containsKey(leafAlbumId)) {
        _nodesById[leafAlbumId] = AlbumNode(
          id: leafAlbumId,
          name: 'Vidéos non classées ($yearStr)',
          parentId: targetYearNode.id,
          isFolder: false,
          directCount: 0,
          totalCount: 0,
        );
        nodesAdded = true;
      }
      v.albums.add(leafAlbumId);
    }

    if (nodesAdded) {
      _rebuildChildrenTree();
    }
  }

  void _normalizeAlbumHierarchy() {
    // 1. Supprimer les dossiers marqués comme supprimés dans Supabase
    for (final delId in _deletedAlbumIds) {
      _nodesById.remove(delId);
    }

    // 2. Supprimer le niveau inutile "Photos" (6cda9b888a514233bc7edbe3753a3c4a)
    //    et remonter ses enfants directs (01 - Meilleures, 02 - Pays, Print, etc.) à la racine (parentId = null)
    _nodesById.remove(_kPhotosWrapperId);
    final updated = <String, AlbumNode>{};
    for (final entry in _nodesById.entries) {
      final node = entry.value;
      String? newParentId = node.parentId;
      if (newParentId == _kPhotosWrapperId) {
        newParentId = null;
      }
      // 3. Placer le dossier "2026" dans "00 - Années" s'il était à la racine
      if (node.id == _kYear2026Id && (newParentId == null || newParentId == _kPhotosWrapperId)) {
        newParentId = _kYearsRootId;
      }
      // 4. Rattacher les dossiers d'années vidéo orphelins (ex-racine Vidéos) à "00 - Années"
      if (newParentId == 'bb3d36f6161042d4a2ba6a500c4fe504') {
        newParentId = _kYearsRootId;
      }
      updated[node.id] = AlbumNode(
        id: node.id,
        name: node.name,
        parentId: newParentId,
        isFolder: node.isFolder,
        directCount: node.directCount,
        totalCount: node.totalCount,
        createdByName: node.createdByName,
      );
    }
    _nodesById = updated;
  }

  bool _isInsideYearsTree(String? nodeId) {
    String? cur = nodeId;
    final visited = <String>{};
    while (cur != null && visited.add(cur)) {
      if (cur == _kYearsRootId) return true;
      cur = _nodesById[cur]?.parentId;
    }
    return false;
  }

  void _rebuildChildrenTree() {
    _childrenByParent = {};
    for (var a in _nodesById.values) {
      // Ne pas afficher le conteneur "00 - Années" dans la racine de Thématiques
      if (a.id == _kYearsRootId) continue;
      _childrenByParent.putIfAbsent(a.parentId, () => []).add(a);
    }
    for (var entry in _childrenByParent.entries) {
      final parentId = entry.key;
      final list = entry.value;
      list.sort((a, b) {
        // Pour la racine de "00 - Années", trier les années de la plus récente (2026) à la plus ancienne (2004)
        if (parentId == _kYearsRootId) {
          return b.name.toLowerCase().compareTo(a.name.toLowerCase());
        }
        if (a.isFolder != b.isFolder) {
          return a.isFolder ? -1 : 1;
        }
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    }
  }

  void _recalculateAlbumCounts() {
    final directCounts = <String, int>{};
    for (final p in _photosOnly) {
      for (final aId in p.albums) {
        directCounts[aId] = (directCounts[aId] ?? 0) + 1;
      }
    }
    final directVideoCounts = <String, int>{};
    for (final v in _videosOnly) {
      for (final aId in v.albums) {
        directVideoCounts[aId] = (directVideoCounts[aId] ?? 0) + 1;
      }
    }

    int computeTotal(String nodeId, Map<String, int> map, Set<String> visited) {
      if (!visited.add(nodeId)) return 0;
      int sum = map[nodeId] ?? 0;
      for (final child in _childrenByParent[nodeId] ?? const <AlbumNode>[]) {
        sum += computeTotal(child.id, map, visited);
      }
      return sum;
    }

    final updatedNodes = <String, AlbumNode>{};
    for (final entry in _nodesById.entries) {
      final node = entry.value;
      final dCount = directCounts[node.id] ?? 0;
      final tCount = node.isFolder ? computeTotal(node.id, directCounts, {}) : dCount;
      final dvCount = directVideoCounts[node.id] ?? 0;
      final tvCount = node.isFolder ? computeTotal(node.id, directVideoCounts, {}) : dvCount;
      updatedNodes[node.id] = AlbumNode(
        id: node.id,
        name: node.name,
        parentId: node.parentId,
        isFolder: node.isFolder,
        directCount: dCount,
        totalCount: tCount,
        directVideoCount: dvCount,
        totalVideoCount: tvCount,
        createdByName: node.createdByName,
      );
    }
    _nodesById = updatedNodes;
    _rebuildChildrenTree();
  }

  Future<void> _syncWithCloud({bool silent = false}) async {
    if (_isSyncingCloud) return;
    setState(() => _isSyncingCloud = true);
    try {
      final delta = await CloudSyncService.fetchCloudDeltas();
      if (!mounted) return;
      _cloudTableReady = delta.tableReady;

      // 1. Appliquer les nouveaux dossiers & albums (ainsi que déplacements, suppressions, pays, couvertures, notes, corbeille et voyage actif)
      for (final ca in delta.customAlbums) {
        if (ca.parentId == _kPurgeMetaParentId || ca.id.startsWith('__purged__')) {
          final idStr = ca.id.startsWith('__purged__') ? ca.id.substring('__purged__'.length) : ca.id;
          final pid = int.tryParse(idStr);
          if (pid != null && !ca.isDeleted) _purgedPhotoIds.add(pid);
          continue;
        }
        if (ca.parentId == _kTrashMetaParentId || ca.id.startsWith('__trash__')) {
          final idStr = ca.id.startsWith('__trash__') ? ca.id.substring('__trash__'.length) : ca.id;
          final pid = int.tryParse(idStr);
          if (pid != null) {
            if (ca.isDeleted) {
              _trashedAtByPhotoId.remove(pid);
            } else {
              final dt = DateTime.tryParse(ca.name.trim());
              if (dt != null) _trashedAtByPhotoId[pid] = dt;
            }
          }
          continue;
        }
        if (ca.parentId == _kRateMetaParentId || ca.id.startsWith('__rate__')) {
          final targetIdStr = ca.id.startsWith('__rate__') ? ca.id.substring('__rate__'.length) : ca.id;
          final targetPhotoId = int.tryParse(targetIdStr);
          if (targetPhotoId != null) {
            if (ca.isDeleted) {
              _ratingsByPhotoId.remove(targetPhotoId);
            } else {
              _ratingsByPhotoId[targetPhotoId] = PhotoRatingRecord.parse(ca.name);
            }
          }
          continue;
        }
        if (ca.parentId == _kCoverMetaParentId || ca.id.startsWith('__cover__')) {
          final targetAlbumId = ca.id.startsWith('__cover__') ? ca.id.substring('__cover__'.length) : ca.id;
          final parsedId = int.tryParse(ca.name.trim());
          if (ca.isDeleted || parsedId == null) {
            _albumCoverPhotoIdById.remove(targetAlbumId);
          } else {
            _albumCoverPhotoIdById[targetAlbumId] = parsedId;
          }
          continue;
        }
        if (ca.parentId == _kTripMetaParentId || ca.id == _kActiveTripNodeId) {
          if (ca.isDeleted) {
            _activeTrip = null;
          } else {
            _activeTrip = ActiveTripConfig.tryParse(ca.name);
          }
          continue;
        }
        if (ca.parentId == _kCountryMetaParentId || ca.id.startsWith('__country__')) {
          final targetAlbumId = ca.id.startsWith('__country__') ? ca.id.substring('__country__'.length) : ca.id;
          if (ca.isDeleted || ca.name.trim().isEmpty) {
            _albumCountryIsoById.remove(targetAlbumId);
          } else {
            _albumCountryIsoById[targetAlbumId] = ca.name.trim();
          }
          continue;
        }
        if (ca.isDeleted) {
          _deletedAlbumIds.add(ca.id);
          _nodesById.remove(ca.id);
          _customAlbumIds.remove(ca.id);
        } else {
          _deletedAlbumIds.remove(ca.id);
          _customAlbumIds.add(ca.id);
          final existing = _nodesById[ca.id];
          _nodesById[ca.id] = AlbumNode(
            id: ca.id,
            name: ca.name,
            parentId: ca.parentId == _kPhotosWrapperId ? null : ca.parentId,
            isFolder: ca.isFolder,
            directCount: existing?.directCount ?? 0,
            totalCount: existing?.totalCount ?? 0,
            createdByName: ca.createdByName ?? existing?.createdByName,
          );
        }
      }
      _normalizeAlbumHierarchy();
      _rebuildChildrenTree();

      // 2. Appliquer les nouvelles photos ajoutées depuis l'app
      final existingIds = _allPhotos.map((p) => p.id).toSet();
      final newCustomItems = <PhotoItem>[];
      for (final cp in delta.customPhotos) {
        if (!existingIds.contains(cp.id)) {
          newCustomItems.add(
            PhotoItem(
              id: cp.id,
              filename: cp.filename,
              year: cp.year,
              dateFolder: cp.dateFolder,
              captureDate: cp.captureDate,
              width: cp.width,
              height: cp.height,
              fileSize: cp.fileSize,
              isVideo: cp.isVideo,
              driveId: cp.driveId,
              cameraModel: cp.cameraModel,
              country: cp.country,
              city: cp.city,
              albums: List<String>.from(cp.albums),
              addedByName: cp.addedByName,
              addedByEmail: cp.addedByEmail,
            ),
          );
        }
      }
      if (newCustomItems.isNotEmpty) {
        _allPhotos.insertAll(0, newCustomItems);
      }

      // 3. Appliquer les overrides (ajout/retrait d'albums, suppression) et les likes
      _overridesByPhotoId
        ..clear()
        ..addAll(delta.overridesByPhotoId);
      _likesByPhotoId
        ..clear()
        ..addAll(delta.likesByPhotoId);

      _trashedPhotos.clear();
      final expiredToPurge = <PhotoItem>[];
      final updatedAll = <PhotoItem>[];
      for (final p in _allPhotos) {
        if (_purgedPhotoIds.contains(p.id)) continue;
        final ov = _overridesByPhotoId[p.id];
        if (ov == null) {
          updatedAll.add(p);
          continue;
        }
        if (ov.isDeleted) {
          final trashedAt = _trashedAtByPhotoId[p.id] ?? DateTime.now();
          _trashedAtByPhotoId.putIfAbsent(p.id, () => trashedAt);
          if (DateTime.now().difference(trashedAt).inDays >= 30) {
            expiredToPurge.add(p);
          } else {
            _trashedPhotos.add(p);
          }
          continue;
        }
        final albumSet = p.albums.toSet()
          ..addAll(ov.addedAlbums)
          ..removeAll(ov.removedAlbums);
        updatedAll.add(
          PhotoItem(
            id: p.id,
            filename: p.filename,
            year: p.year,
            dateFolder: p.dateFolder,
            captureDate: p.captureDate,
            width: p.width,
            height: p.height,
            fileSize: p.fileSize,
            isVideo: p.isVideo,
            driveId: p.driveId,
            cameraModel: p.cameraModel,
            country: p.country,
            city: p.city,
            albums: albumSet.toList(),
          ),
        );
      }

      _allPhotos = updatedAll;
      _photosOnly = _allPhotos.where((p) => !p.isVideo).toList();
      _videosOnly = _allPhotos.where((p) => p.isVideo).toList();
      _attachOrphanVideosToYears();
      _rebuildChildrenTree();
      _recalculateAlbumCounts();

      if (expiredToPurge.isNotEmpty) {
        Future<void>.microtask(() => _permanentlyPurgePhotos(expiredToPurge));
      }

      if (!silent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF1E293B),
            content: Text(
              _cloudTableReady
                  ? 'Synchronisé avec le cloud familial Supabase (${delta.customAlbums.length} dossiers créés, ${delta.customPhotos.length} médias ajoutés).'
                  : 'Tables Supabase non initialisées : exécutez scripts/supabase_schema.sql dans votre SQL Editor Supabase.',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncingCloud = false);
      }
    }
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Color(0xFF0EA5E9)),
              SizedBox(height: 16),
              Text("Chargement de Medias Familly...", style: TextStyle(color: Color(0xFF475569))),
            ],
          ),
        ),
      );
    }

    if (_showPreHome) {
      return _buildPreHomeScreen();
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth >= 900;

    if (isWide) {
      return _buildDesktopScaffold();
    }
    return _buildMobileScaffold();
  }

  Future<void> _openCollaborativeTripAlbum() async {
    if (_activeTrip == null) {
      await _showCreateActiveTripDialog();
      return;
    }
    await _openActiveTripScreen();
  }

  Future<void> _showCreateActiveTripDialog() async {
    if (_activeTrip != null) return;
    final titleCtrl = TextEditingController();
    WorldCountryMeta selectedCountry = kCountriesByIso['ESP'] ?? kWorldCountries.first;
    DateTimeRange selectedRange = DateTimeRange(
      start: DateTime.now(),
      end: DateTime.now().add(const Duration(days: 7)),
    );
    String fmtDate(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    final sortedCountries = List<WorldCountryMeta>.from(kWorldCountries)
      ..sort((a, b) => a.nameFr.toLowerCase().compareTo(b.nameFr.toLowerCase()));

    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.flight_takeoff_rounded, color: Color(0xFF10B981)),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Créer un voyage en cours',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Un seul voyage peut être actif à la fois pour toute la famille.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: titleCtrl,
                    decoration: InputDecoration(
                      labelText: 'Nom du voyage',
                      hintText: 'Ex: Vacances Espagne',
                      filled: true,
                      fillColor: const Color(0xFFF6EFE2),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<WorldCountryMeta>(
                    value: selectedCountry,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Pays de destination',
                      filled: true,
                      fillColor: const Color(0xFFF6EFE2),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: sortedCountries
                        .map(
                          (c) => DropdownMenuItem<WorldCountryMeta>(
                            value: c,
                            child: Text('${c.flag}  ${c.nameFr}'),
                          ),
                        )
                        .toList(),
                    onChanged: (c) {
                      if (c != null) setDialogState(() => selectedCountry = c);
                    },
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () async {
                      final picked = await showDateRangePicker(
                        context: ctx,
                        initialDateRange: selectedRange,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2035),
                      );
                      if (picked != null) {
                        setDialogState(() => selectedRange = picked);
                      }
                    },
                    icon: const Icon(Icons.date_range_rounded, color: Color(0xFFF97316)),
                    label: Text(
                      'Dates : ${fmtDate(selectedRange.start)} → ${fmtDate(selectedRange.end)}',
                      style: const TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('Annuler'),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
              onPressed: () async {
                final title = titleCtrl.text.trim().isEmpty
                    ? 'Voyage ${selectedCountry.nameFr}'
                    : titleCtrl.text.trim();
                final cfg = ActiveTripConfig(
                  title: title,
                  countryIso: selectedCountry.iso3,
                  countryName: selectedCountry.nameFr,
                  countryFlag: selectedCountry.flag,
                  startDate: fmtDate(selectedRange.start),
                  endDate: fmtDate(selectedRange.end),
                  createdBy: _auth.isSignedIn ? _auth.shortLabel : null,
                );
                Navigator.of(dialogCtx).pop();
                setState(() => _activeTrip = cfg);
                await CloudSyncService.createCustomAlbum(
                  id: _kActiveTripNodeId,
                  name: cfg.toJsonString(),
                  parentId: _kTripMetaParentId,
                  isFolder: false,
                );
                if (!mounted) return;
                await _openActiveTripScreen();
              },
              icon: const Icon(Icons.check),
              label: const Text('Démarrer le voyage'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openActiveTripScreen() async {
    final trip = _activeTrip;
    if (trip == null) return;

    if (!_nodesById.containsKey(_kCollabTripAlbumId)) {
      _nodesById[_kCollabTripAlbumId] = AlbumNode(
        id: _kCollabTripAlbumId,
        name: trip.title,
        parentId: _kYearsRootId,
        isFolder: false,
        directCount: 0,
        totalCount: 0,
      );
      _customAlbumIds.add(_kCollabTripAlbumId);
      _recalculateAlbumCounts();
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _ActiveTripScreen(
          trip: trip,
          getTripMedia: () => _allPhotos
              .where((p) => p.albums.contains(_kCollabTripAlbumId))
              .toList(),
          currentUserName: _auth.shortLabel,
          currentUserEmail: _auth.email,
          gdriveUrl: _gdriveUrl,
          onUploadSelectedFiles: (files, onProgress) async {
            int done = 0;
            for (final f in files) {
              final bytes = f.bytes;
              if (bytes == null) continue;
              final lower = f.name.toLowerCase();
              final isVid = lower.endsWith('.mp4') || lower.endsWith('.mov') || lower.endsWith('.avi');
              final mime = isVid ? 'video/mp4' : 'image/jpeg';
              final driveId = await CloudSyncService.uploadFileToGoogleDrive(
                filename: f.name,
                bytes: bytes,
                mimeType: mime,
                folderName: 'Medias Familly - ${trip.title}',
              );
              final now = DateTime.now();
              final dFolder =
                  '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
              final photoId = DateTime.now().millisecondsSinceEpoch + done;
              final rec = CustomPhotoRecord(
                id: photoId,
                filename: f.name,
                year: now.year.toString(),
                dateFolder: dFolder,
                captureDate: now.toIso8601String(),
                width: 0,
                height: 0,
                fileSize: bytes.length,
                isVideo: isVid,
                driveId: driveId,
                country: trip.countryName,
                albums: [_kCollabTripAlbumId],
                addedByName: _auth.isSignedIn ? _auth.shortLabel : 'Invité',
                addedByEmail: _auth.email,
              );
              await CloudSyncService.addCustomPhoto(rec);
              final item = PhotoItem(
                id: photoId,
                filename: f.name,
                year: now.year.toString(),
                dateFolder: dFolder,
                captureDate: now.toIso8601String(),
                width: 0,
                height: 0,
                fileSize: bytes.length,
                isVideo: isVid,
                driveId: driveId,
                country: trip.countryName,
                albums: [_kCollabTripAlbumId],
                addedByName: rec.addedByName,
                addedByEmail: rec.addedByEmail,
              );
              if (mounted) {
                setState(() {
                  _allPhotos.insert(0, item);
                  if (isVid) {
                    _videosOnly.insert(0, item);
                  } else {
                    _photosOnly.insert(0, item);
                  }
                  _recalculateAlbumCounts();
                });
              }
              done++;
              onProgress(done, files.length);
            }
          },
          onAddViaLink: () => _showAddPhotoDialog(defaultAlbumId: _kCollabTripAlbumId),
          onTerminateTrip: () async {
            setState(() {
              _activeTrip = null;
              for (final p in _allPhotos) {
                p.albums.remove(_kCollabTripAlbumId);
              }
              _recalculateAlbumCounts();
            });
            await CloudSyncService.createCustomAlbum(
              id: _kActiveTripNodeId,
              name: '',
              parentId: _kTripMetaParentId,
              isFolder: false,
              isDeleted: true,
            );
          },
          onBulkDeleteTripPhotos: _handleBulkDeletePhotos,
          onOpenPhoto: (photo, allTripMedia) {
            final idx = allTripMedia.indexWhere((p) => p.id == photo.id);
            Navigator.of(context).push(
              PageRouteBuilder<void>(
                opaque: false,
                barrierColor: Colors.black.withValues(alpha: 0.96),
                pageBuilder: (_, __, ___) => _FullScreenPhotoViewer(
                  photos: allTripMedia,
                  initialIndex: idx < 0 ? 0 : idx,
                  defaultGdriveUrl: _gdriveUrl,
                  onLaunchDrive: (ctx, url) => _openUrl(url),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPreHomeScreen() {
    final collabCount = _allPhotos.where((p) => p.albums.contains(_kCollabTripAlbumId)).length;
    final hasPendingUpdate = _pendingUpdate != null && !_updateSkipped;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFFF8E7), Color(0xFFFFF0DB), Color(0xFFE6F8FC)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 540),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Logo & Version header — Thème Carnet de Vacances
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFF97316), Color(0xFFFB923C), Color(0xFFFBBF24)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFF97316).withValues(alpha: 0.28),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                width: 58,
                                height: 58,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.25),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.45), width: 1.5),
                                ),
                                child: const Icon(Icons.beach_access_rounded, color: Colors.white, size: 32),
                              ),
                              Positioned(
                                right: -4,
                                top: -4,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFFEF08A),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.wb_sunny_rounded, size: 13, color: Color(0xFFEA580C)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Carnet de Vacances 🌴',
                                  style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: Colors.white),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'Medias Familly · v$appVersionLabel • ${_allPhotos.length} souvenirs',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white.withValues(alpha: 0.92),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 20),

                  // 1. Module Connexion Google
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFFFF),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _auth.isSignedIn
                            ? const Color(0xFF4ADE80).withValues(alpha: 0.4)
                            : Color(0xFFEBDDC6),
                      ),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: _auth.isSignedIn
                              ? const Color(0xFF4ADE80).withValues(alpha: 0.2)
                              : const Color(0xFFF6EFE2),
                          child: Icon(
                            _auth.isSignedIn ? Icons.verified_user_rounded : Icons.person_outline_rounded,
                            color: _auth.isSignedIn ? const Color(0xFF4ADE80) : Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _auth.isSignedIn ? _auth.shortLabel : 'Non connecté',
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B)),
                              ),
                              Text(
                                _auth.isSignedIn
                                    ? (_auth.email ?? 'Connecté avec Google')
                                    : 'Connectez-vous pour liker et déposer des médias',
                                style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (_auth.status == AuthStatus.signingIn)
                          const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0EA5E9)),
                          )
                        else if (_auth.isSignedIn)
                          TextButton(
                            onPressed: _handleSignOut,
                            child: const Text('Déconnexion', style: TextStyle(fontSize: 12, color: Color(0xFFF87171))),
                          )
                        else
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFFF97316),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                            onPressed: _handleGoogleSignIn,
                            icon: const Icon(Icons.login, size: 16),
                            label: const Text('Connexion', style: TextStyle(fontSize: 12)),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 2. Module Version & Mise à jour (avec possibilité de passer)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: hasPendingUpdate
                          ? const Color(0xFF0C4A6E).withValues(alpha: 0.4)
                          : const Color(0xFFFFFFFF),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: hasPendingUpdate ? const Color(0xFF0EA5E9) : Color(0xFFF1E6D2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              hasPendingUpdate ? Icons.system_update_alt_rounded : Icons.check_circle_outline_rounded,
                              size: 18,
                              color: hasPendingUpdate ? const Color(0xFF0EA5E9) : const Color(0xFF4ADE80),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _isCheckingUpdate
                                    ? 'Vérification des mises à jour...'
                                    : hasPendingUpdate
                                        ? 'Mise à jour disponible : v${_pendingUpdate!.version} (Build ${_pendingUpdate!.buildNumber})'
                                        : (_updateSkipped && _pendingUpdate != null
                                            ? 'Mise à jour v${_pendingUpdate!.version} passée'
                                            : 'Application à jour (v$appVersionLabel)'),
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B)),
                              ),
                            ),
                            if (!_isCheckingUpdate && !hasPendingUpdate)
                              IconButton(
                                tooltip: 'Vérifier les mises à jour',
                                icon: const Icon(Icons.refresh, size: 18, color: Color(0xFF64748B)),
                                onPressed: () {
                                  setState(() => _updateSkipped = false);
                                  _checkLaunchUpdate();
                                },
                              ),
                          ],
                        ),
                        if (hasPendingUpdate) ...[
                          if ((_pendingUpdate!.releaseNotes ?? '').isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              _pendingUpdate!.releaseNotes!,
                              style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
                            ),
                          ],
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: FilledButton.icon(
                                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0EA5E9)),
                                  onPressed: () => AppUpdateService.promptUpdate(context, _pendingUpdate!, isForced: true),
                                  icon: const Icon(Icons.download_rounded, size: 17),
                                  label: const Text('Mettre à jour'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Color(0xFF475569),
                                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                                ),
                                onPressed: () => setState(() => _updateSkipped = true),
                                child: const Text('Passer'),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),

                  const Text(
                    'CHOISIR UN ESPACE',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // 3. Mode Photos
                  _buildPreHomeModeCard(
                    icon: Icons.photo_camera_rounded,
                    badgeIcon: Icons.wb_sunny_rounded,
                    color: const Color(0xFFF97316),
                    gradientColors: const [Color(0xFFF97316), Color(0xFFFBBF24)],
                    title: 'Photos de Vacances',
                    subtitle: '${_photosOnly.length} photos · Carte du monde, Thématiques & Années',
                    onTap: () => setState(() {
                      _mediaMode = 0;
                      _currentIndex = 0;
                      _showPreHome = false;
                    }),
                  ),
                  const SizedBox(height: 12),

                  // 4. Mode Vidéos
                  _buildPreHomeModeCard(
                    icon: Icons.videocam_rounded,
                    badgeIcon: Icons.waves_rounded,
                    color: const Color(0xFF0EA5E9),
                    gradientColors: const [Color(0xFF0284C7), Color(0xFF22D3EE)],
                    title: 'Films & Vidéos',
                    subtitle: '${_videosOnly.length} vidéos · Carte du monde, Thématiques & Années',
                    onTap: () => setState(() {
                      _mediaMode = 1;
                      _currentIndex = 0;
                      _showPreHome = false;
                    }),
                  ),
                  const SizedBox(height: 12),

                  // 5. Album collaboratif (Voyage en cours)
                  _buildPreHomeModeCard(
                    icon: Icons.flight_takeoff_rounded,
                    badgeIcon: Icons.luggage_rounded,
                    color: const Color(0xFF10B981),
                    gradientColors: const [Color(0xFF059669), Color(0xFF34D399)],
                    title: _activeTrip != null
                        ? '${_activeTrip!.countryFlag} ${_activeTrip!.title}'
                        : 'Créer un voyage en cours ✈️',
                    subtitle: _activeTrip != null
                        ? '${_activeTrip!.countryName} · Du ${_activeTrip!.startDate} au ${_activeTrip!.endDate} · $collabCount souvenir(s)'
                        : 'Aucun voyage actif · Créez l\'album partagé des vacances',
                    onTap: _openCollaborativeTripAlbum,
                  ),
                  const SizedBox(height: 12),
                  // 6. Corbeille (30 jours)
                  _buildPreHomeModeCard(
                    icon: Icons.delete_outline_rounded,
                    badgeIcon: Icons.schedule_rounded,
                    color: const Color(0xFFEF4444),
                    gradientColors: const [Color(0xFFDC2626), Color(0xFFF87171)],
                    title: 'Corbeille (${_trashedPhotos.length})',
                    subtitle: _trashedPhotos.isEmpty
                        ? 'Aucun élément · Suppression auto après 30 jours'
                        : '${_trashedPhotos.length} élément(s) conservé(s) 30 jours avant suppression Drive',
                    onTap: _openTrashScreen,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildPreHomeModeCard({
    required IconData icon,
    required IconData badgeIcon,
    required Color color,
    required List<Color> gradientColors,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      elevation: 2,
      shadowColor: color.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.28), width: 1.3),
          ),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: gradientColors,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(icon, color: Colors.white, size: 28),
                  ),
                  Positioned(
                    right: -5,
                    bottom: -5,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: color.withValues(alpha: 0.4)),
                      ),
                      child: Icon(badgeIcon, size: 12, color: color),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.arrow_forward_rounded, size: 18, color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopScaffold() {
    final activeNavIndex = _currentIndex;
    final isVideos = _mediaMode == 1;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFFFFF),
        surfaceTintColor: Colors.transparent,
        toolbarHeight: 64,
        titleSpacing: 16,
        shape: const Border(bottom: BorderSide(color: Color(0xFFF1E6D2))),
        title: Row(
          children: [
            IconButton(
              tooltip: 'Retour à l\'accueil',
              icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFFF97316)),
              onPressed: () => setState(() => _showPreHome = true),
            ),
            const SizedBox(width: 4),
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFF97316), Color(0xFF0EA5E9)],
                  begin: Alignment.bottomLeft,
                  end: Alignment.topRight,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isVideos ? Icons.videocam_rounded : Icons.photo_camera_rounded,
                color: Colors.white,
                size: 19,
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isVideos ? "Films & Vidéos" : "Photos de Vacances",
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, letterSpacing: -0.3),
                ),
                Text(
                  "${isVideos ? _videosOnly.length : _photosOnly.length} ${isVideos ? 'vidéos' : 'photos'}",
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ],
        ),
        actions: [
          _buildAuthHeaderChip(compact: false),
          IconButton(
            tooltip: "Ajouter un média Google Drive",
            icon: const Icon(Icons.add_photo_alternate_outlined, color: Color(0xFF059669), size: 22),
            onPressed: () => _showAddPhotoDialog(defaultIsVideo: isVideos),
          ),
          IconButton(
            tooltip: "Forcer la synchronisation (Supabase Cloud)",
            icon: _isSyncingCloud
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0EA5E9)),
                  )
                : const Icon(Icons.sync, color: Color(0xFF0EA5E9), size: 20),
            onPressed: () => _syncWithCloud(silent: false),
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: Row(
        children: [
          Container(
            width: 220,
            decoration: const BoxDecoration(
              color: Color(0xFFFFFFFF),
              border: Border(right: BorderSide(color: Color(0xFFF1E6D2))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    isVideos ? "NAVIGATION VIDÉOS" : "NAVIGATION PHOTOS",
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ),
                _buildDesktopNavItem(
                  index: 0,
                  activeIndex: activeNavIndex,
                  icon: Icons.explore_outlined,
                  selectedIcon: Icons.explore_rounded,
                  label: "La carte",
                ),
                _buildDesktopNavItem(
                  index: 1,
                  activeIndex: activeNavIndex,
                  icon: Icons.backpack_outlined,
                  selectedIcon: Icons.backpack_rounded,
                  label: "Thématiques",
                  badge: "${_countPhotosInTree(yearsTree: false, videosOnly: isVideos)}",
                ),
                _buildDesktopNavItem(
                  index: 2,
                  activeIndex: activeNavIndex,
                  icon: Icons.event_note_outlined,
                  selectedIcon: Icons.event_note_rounded,
                  label: "Années",
                  badge: "${_countPhotosInTree(yearsTree: true, videosOnly: isVideos)}",
                ),
                _buildDesktopNavItem(
                  index: 3,
                  activeIndex: activeNavIndex,
                  icon: Icons.travel_explore_outlined,
                  selectedIcon: Icons.travel_explore_rounded,
                  label: "Recherche",
                ),
                const Spacer(),
                Container(
                  margin: const EdgeInsets.all(12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF6EFE2).withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Color(0xFFF1E6D2)),
                  ),
                  child: Text(
                    "v$appVersionLabel • Build $appBuildNumber",
                    style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: IndexedStack(
              index: _currentIndex.clamp(0, 3),
              children: [
                _buildWorldMapTab(videosOnly: isVideos),
                _buildAlbumsTab(),
                _buildPhotoYearsTab(),
                _buildSearchTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopNavItem({
    required int index,
    required int activeIndex,
    required IconData icon,
    required IconData selectedIcon,
    required String label,
    String? badge,
  }) {
    final isSelected = index == activeIndex;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => setState(() => _currentIndex = index),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFF97316).withValues(alpha: 0.14) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? const Color(0xFFF97316).withValues(alpha: 0.35) : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              Icon(
                isSelected ? selectedIcon : icon,
                size: 19,
                color: isSelected ? const Color(0xFFF97316) : const Color(0xFF64748B),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected ? const Color(0xFFEA580C) : const Color(0xFF475569),
                  ),
                ),
              ),
              if (badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFFF97316).withValues(alpha: 0.18) : const Color(0xFFF6EFE2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    badge,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? const Color(0xFFEA580C) : const Color(0xFF64748B),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileScaffold() {
    final isVideos = _mediaMode == 1;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFFFFF),
        leading: IconButton(
          tooltip: 'Retour à l\'accueil',
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFFF97316)),
          onPressed: () => setState(() => _showPreHome = true),
        ),
        title: Text(
          isVideos ? "Films & Vidéos" : "Photos de Vacances",
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ),
        actions: [
          _buildAuthHeaderChip(compact: true),
          IconButton(
            tooltip: "Ajouter un média Google Drive",
            icon: const Icon(Icons.add_photo_alternate_outlined, color: Color(0xFF059669)),
            onPressed: () => _showAddPhotoDialog(defaultIsVideo: isVideos),
          ),
          IconButton(
            tooltip: "Forcer la synchronisation (Supabase Cloud)",
            icon: _isSyncingCloud
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0EA5E9)),
                  )
                : const Icon(Icons.sync, color: Color(0xFF0EA5E9)),
            onPressed: () => _syncWithCloud(silent: false),
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex.clamp(0, 3),
        children: [
          _buildWorldMapTab(videosOnly: isVideos),
          _buildAlbumsTab(),
          _buildPhotoYearsTab(),
          _buildSearchTab(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex.clamp(0, 3),
        onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
        backgroundColor: const Color(0xFFFFFFFF),
        indicatorColor: const Color(0xFFF97316).withValues(alpha: 0.2),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore_rounded, color: Color(0xFFF97316)),
            label: "La carte",
          ),
          NavigationDestination(
            icon: Icon(Icons.backpack_outlined),
            selectedIcon: Icon(Icons.backpack_rounded, color: Color(0xFFF97316)),
            label: "Thématiques",
          ),
          NavigationDestination(
            icon: Icon(Icons.event_note_outlined),
            selectedIcon: Icon(Icons.event_note_rounded, color: Color(0xFFF97316)),
            label: "Années",
          ),
          NavigationDestination(
            icon: Icon(Icons.travel_explore_outlined),
            selectedIcon: Icon(Icons.travel_explore_rounded, color: Color(0xFFF97316)),
            label: "Recherche",
          ),
        ],
      ),
    );
  }

  int _countPhotosInTree({required bool yearsTree, bool videosOnly = false}) {
    final targetAlbumIds = <String>{};
    for (final node in _nodesById.values) {
      if (node.id == _kYearsRootId) continue;
      if (_isInsideYearsTree(node.id) == yearsTree) {
        targetAlbumIds.add(node.id);
      }
    }
    int count = 0;
    final pool = videosOnly ? _videosOnly : _photosOnly;
    for (final p in pool) {
      if (p.albums.any((a) => targetAlbumIds.contains(a))) {
        count++;
      }
    }
    return count;
  }

  String? _getEffectiveCountryIsoForNode(String nodeId) {
    String? cur = nodeId;
    final visited = <String>{};
    while (cur != null && visited.add(cur)) {
      if (_albumCountryIsoById.containsKey(cur)) {
        return _albumCountryIsoById[cur];
      }
      cur = _nodesById[cur]?.parentId;
    }
    if (_isInsideYearsTree(nodeId)) {
      return 'FRA';
    }
    return null;
  }

  Future<void> _showAssignCountryToAlbumDialog(AlbumNode node) async {
    final searchCtrl = TextEditingController();
    String query = '';
    final sortedCountries = List<WorldCountryMeta>.from(kWorldCountries)
      ..sort((a, b) => a.nameFr.toLowerCase().compareTo(b.nameFr.toLowerCase()));
    final usedIsos = _computeVisitedCountryStats().map((c) => c.meta.iso3).toSet();
    final currentIso = _getEffectiveCountryIsoForNode(node.id);

    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final normQ = normalizeCountryKey(query);
          final filtered = normQ.isEmpty
              ? sortedCountries
              : sortedCountries
                  .where((c) => normalizeCountryKey(c.nameFr).contains(normQ))
                  .toList();
          return AlertDialog(
            backgroundColor: const Color(0xFFFFFFFF),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Color(0xFFEBDDC6)),
            ),
            title: Row(
              children: [
                const Icon(Icons.public_rounded, color: Color(0xFF0EA5E9), size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Pays pour "${node.name}"',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 400,
              height: 400,
              child: Column(
                children: [
                  TextField(
                    controller: searchCtrl,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Rechercher un pays...',
                      prefixIcon: const Icon(Icons.search, size: 18),
                      filled: true,
                      fillColor: const Color(0xFFF6EFE2),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      isDense: true,
                    ),
                    onChanged: (v) => setDialogState(() => query = v),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (_, idx) {
                        final c = filtered[idx];
                        final isSelected = c.iso3 == currentIso;
                        final isUsed = usedIsos.contains(c.iso3);
                        return ListTile(
                          dense: true,
                          selected: isSelected,
                          selectedTileColor: const Color(0xFF0EA5E9).withOpacity(0.18),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          leading: Text(c.flag, style: const TextStyle(fontSize: 22)),
                          title: Text(
                            c.nameFr,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              color: const Color(0xFF1E293B),
                            ),
                          ),
                          subtitle: Text(
                            '${c.continent} · ${c.capital}',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isUsed)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0EA5E9).withOpacity(0.16),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'Visité',
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF0369A1)),
                                  ),
                                ),
                              if (isSelected) ...[
                                const SizedBox(width: 6),
                                const Icon(Icons.check_circle, color: Color(0xFF0EA5E9), size: 18),
                              ],
                            ],
                          ),
                          onTap: () async {
                            Navigator.of(dialogCtx).pop();
                            setState(() {
                              _albumCountryIsoById[node.id] = c.iso3;
                            });
                            final ok = await CloudSyncService.createCustomAlbum(
                              id: '__country__${node.id}',
                              name: c.iso3,
                              parentId: _kCountryMetaParentId,
                              isFolder: false,
                            );
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: const Color(0xFFFFFFFF),
                                content: Text(
                                  ok
                                      ? '✔ "${node.name}" associé à ${c.flag} ${c.nameFr} sur la carte !'
                                      : '⚠ Associé localement à ${c.flag} ${c.nameFr}.',
                                  style: const TextStyle(color: Colors.white, fontSize: 12),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogCtx).pop(),
                child: const Text("Fermer", style: TextStyle(color: Color(0xFF64748B))),
              ),
            ],
          );
        },
      ),
    );
  }

  // --- LA CARTE: World Map Tab ---
  String? _extractDateHint(String name) {
    final mY = RegExp(r'\b(19\d{2}|20\d{2})\b').firstMatch(name);
    final mMY = RegExp(r'\b(\d{1,2}/20\d{2})\b').firstMatch(name);
    return mMY?.group(1) ?? mY?.group(1);
  }

  DateTime? _parseMediaDate(PhotoItem m) {
    if (m.captureDate.isNotEmpty) {
      final dt = DateTime.tryParse(m.captureDate);
      if (dt != null) return dt;
    }
    if (m.dateFolder.isNotEmpty) {
      final dt = DateTime.tryParse(m.dateFolder);
      if (dt != null) return dt;
    }
    return null;
  }

  String _fmtFrDate(DateTime d) {
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    return '$dd/$mm/${d.year}';
  }

  List<String> _computeTravelDateRanges(Iterable<PhotoItem> media) {
    final Map<int, List<DateTime>> byYear = {};
    for (final m in media) {
      final dt = _parseMediaDate(m);
      if (dt != null && dt.year >= 1980 && dt.year <= 2035) {
        byYear.putIfAbsent(dt.year, () => []).add(dt);
      }
    }
    if (byYear.isEmpty) return const [];
    final years = byYear.keys.toList()..sort((a, b) => b.compareTo(a));
    final ranges = <String>[];
    for (final y in years.take(6)) {
      final list = byYear[y]!..sort();
      final first = list.first;
      final last = list.last;
      if (first.year == last.year && first.month == last.month && first.day == last.day) {
        ranges.add(_fmtFrDate(first));
      } else {
        ranges.add('Du ${_fmtFrDate(first)} au ${_fmtFrDate(last)}');
      }
    }
    return ranges;
  }

  List<CountryVisitStats> _computeVisitedCountryStats({
    bool videosOnly = false,
    String? filterYear,
  }) {
    final basePool = videosOnly ? _videosOnly : _photosOnly;
    final mediaPool = filterYear == null
        ? basePool
        : basePool.where((m) => m.year == filterYear).toList();
    final Map<String, Set<int>> photoIdsByIso = {};
    final Map<String, Set<int>> videoIdsByIso = {};
    final Map<String, CountryAlbumSummary> discoveryByIso = {};
    final Map<String, List<CountryAlbumSummary>> albumsByIso = {};
    final Map<String, List<CountrySlideshowPhoto>> slidesByIso = {};
    final Map<String, Set<int>> slideSeenIds = {};
    final Map<String, Set<String>> addedAlbumIdsByIso = {};

    void ensureIso(String iso) {
      photoIdsByIso.putIfAbsent(iso, () => <int>{});
      videoIdsByIso.putIfAbsent(iso, () => <int>{});
      albumsByIso.putIfAbsent(iso, () => <CountryAlbumSummary>[]);
      slidesByIso.putIfAbsent(iso, () => <CountrySlideshowPhoto>[]);
      slideSeenIds.putIfAbsent(iso, () => <int>{});
      addedAlbumIdsByIso.putIfAbsent(iso, () => <String>{});
    }

    ({String? range, int latestTs, String? coverThumb}) computeAlbumStats(
      String albumId,
      Iterable<PhotoItem> items,
      String iso,
    ) {
      int latestTs = 0;
      DateTime? minDt;
      DateTime? maxDt;
      String? coverThumb;
      final customCoverId = _albumCoverPhotoIdById[albumId];
      for (final m in items) {
        if (customCoverId != null && m.id == customCoverId && m.thumbnailUrl != null) {
          coverThumb = m.thumbnailUrl;
        } else if (coverThumb == null && m.thumbnailUrl != null) {
          coverThumb = m.thumbnailUrl;
        }
        final dt = _parseMediaDate(m);
        if (dt != null && dt.year >= 1980 && dt.year <= 2035) {
          final ms = dt.millisecondsSinceEpoch;
          if (ms > latestTs) latestTs = ms;
          if (minDt == null || dt.isBefore(minDt)) minDt = dt;
          if (maxDt == null || dt.isAfter(maxDt)) maxDt = dt;
        }
      }
      String? range;
      if (iso != 'FRA' && minDt != null && maxDt != null) {
        range = (minDt.year == maxDt.year && minDt.month == maxDt.month && minDt.day == maxDt.day)
            ? _fmtFrDate(minDt)
            : 'Du ${_fmtFrDate(minDt)} au ${_fmtFrDate(maxDt)}';
      }
      return (range: range, latestTs: latestTs, coverThumb: coverThumb);
    }

    // 1. Scan all direct children of "02 - Pays" (_kPaysFolderId) -> populates slideshowPhotos + separate discoveryAlbum!
    final paysChildren = _childrenByParent[_kPaysFolderId] ?? const <AlbumNode>[];
    for (final child in paysChildren) {
      final meta = matchCountryMeta(child.name);
      if (meta == null) continue;
      ensureIso(meta.iso3);

      final descendantIds = _getAllDescendantAlbumIds(child.id);
      int pDisc = 0;
      int vDisc = 0;
      for (final m in mediaPool) {
        if (m.albums.any((a) => descendantIds.contains(a))) {
          if (m.isVideo) {
            vDisc++;
            videoIdsByIso[meta.iso3]!.add(m.id);
          } else {
            pDisc++;
            photoIdsByIso[meta.iso3]!.add(m.id);
            if ((m.largePreviewUrl ?? m.thumbnailUrl) != null &&
                slideSeenIds[meta.iso3]!.add(m.id) &&
                slidesByIso[meta.iso3]!.length < 30) {
              slidesByIso[meta.iso3]!.add(
                CountrySlideshowPhoto(
                  id: m.id,
                  filename: m.filename,
                  thumbnailUrl: m.thumbnailUrl,
                  largePreviewUrl: m.largePreviewUrl,
                  captureDate: m.captureDate,
                ),
              );
            }
          }
        }
      }
      if (!videosOnly && pDisc > 0) {
        discoveryByIso[meta.iso3] = CountryAlbumSummary(
          albumId: child.id,
          name: child.name,
          sourceLabel: 'Pays',
          photoCount: pDisc,
          videoCount: vDisc,
          isFolder: child.isFolder,
        );
      }
    }

    // 2. Scan all Années albums (default FRA, or overridden via _albumCountryIsoById)
    //    plus any Thématiques album (outside 02 - Pays) with an explicit _albumCountryIsoById override
    final Map<String, List<PhotoItem>> photosByAlbumId = {};
    for (final m in mediaPool) {
      for (final aId in m.albums) {
        photosByAlbumId.putIfAbsent(aId, () => []).add(m);
      }
    }

    for (final node in _nodesById.values) {
      if (node.id == _kYearsRootId || node.id == _kPaysFolderId || node.parentId == _kPaysFolderId) continue;
      final inYears = _isInsideYearsTree(node.id);
      final hasExplicit = _albumCountryIsoById.containsKey(node.id);
      if (!inYears && !hasExplicit) continue;
      final directMedia = photosByAlbumId[node.id] ?? const <PhotoItem>[];
      if (node.isFolder && directMedia.isEmpty && !hasExplicit) continue;

      final iso = _getEffectiveCountryIsoForNode(node.id);
      if (iso == null || !kCountriesByIso.containsKey(iso)) continue;
      ensureIso(iso);

      final targetIds = node.isFolder ? _getAllDescendantAlbumIds(node.id) : {node.id};
      final Set<int> seenInAlb = {};
      final List<PhotoItem> albItems = [];
      int pCount = 0;
      int vCount = 0;
      for (final aId in targetIds) {
        for (final m in (photosByAlbumId[aId] ?? const <PhotoItem>[])) {
          if (!seenInAlb.add(m.id)) continue;
          albItems.add(m);
          if (m.isVideo) {
            vCount++;
            videoIdsByIso[iso]!.add(m.id);
          } else {
            pCount++;
            photoIdsByIso[iso]!.add(m.id);
          }
        }
      }
      if ((pCount > 0 || vCount > 0) && addedAlbumIdsByIso[iso]!.add(node.id)) {
        final metaStats = computeAlbumStats(node.id, albItems, iso);
        final yearHint = _extractDateHint(node.name);
        final fallbackYearTs = int.tryParse((yearHint ?? '').replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
        final sortTs = metaStats.latestTs > 0
            ? metaStats.latestTs
            : (fallbackYearTs > 1900 ? DateTime(fallbackYearTs).millisecondsSinceEpoch : 0);

        albumsByIso[iso]!.add(
          CountryAlbumSummary(
            albumId: node.id,
            name: node.name,
            dateHint: yearHint,
            dateRange: metaStats.range,
            coverThumbUrl: metaStats.coverThumb,
            sortTimestamp: sortTs,
            sourceLabel: inYears ? 'Années' : 'Thématiques',
            photoCount: pCount,
            videoCount: vCount,
            isFolder: node.isFolder,
          ),
        );
      }
    }

    // 3. Also include photo/video `country` metadata without double counting
    for (final m in mediaPool) {
      final rawCountry = m.country?.trim();
      if (rawCountry == null || rawCountry.isEmpty) continue;
      final meta = matchCountryMeta(rawCountry);
      if (meta == null) continue;
      ensureIso(meta.iso3);
      if (m.isVideo) {
        videoIdsByIso[meta.iso3]!.add(m.id);
      } else {
        photoIdsByIso[meta.iso3]!.add(m.id);
        if (slidesByIso[meta.iso3]!.length < 15 &&
            (m.largePreviewUrl ?? m.thumbnailUrl) != null &&
            slideSeenIds[meta.iso3]!.add(m.id)) {
          slidesByIso[meta.iso3]!.add(
            CountrySlideshowPhoto(
              id: m.id,
              filename: m.filename,
              thumbnailUrl: m.thumbnailUrl,
              largePreviewUrl: m.largePreviewUrl,
              captureDate: m.captureDate,
            ),
          );
        }
      }
    }

    final result = <CountryVisitStats>[];
    for (final iso in photoIdsByIso.keys) {
      final meta = kCountriesByIso[iso];
      if (meta == null) continue;
      final pSet = photoIdsByIso[iso]!;
      final vSet = videoIdsByIso[iso]!;
      if (videosOnly && vSet.isEmpty) continue;
      if (!videosOnly && pSet.isEmpty) continue;
      final albums = albumsByIso[iso]!
        ..sort((a, b) => b.sortTimestamp.compareTo(a.sortTimestamp));

      result.add(
        CountryVisitStats(
          meta: meta,
          photoCount: videosOnly ? 0 : pSet.length,
          videoCount: videosOnly ? vSet.length : 0,
          discoveryAlbum: discoveryByIso[iso],
          albums: albums,
          slideshowPhotos: slidesByIso[iso] ?? const [],
        ),
      );
    }

    result.sort((a, b) => b.totalMedia.compareTo(a.totalMedia));
    return result;
  }

  Widget _buildWorldMapTab({bool videosOnly = false}) {
    final visited = _computeVisitedCountryStats(
      videosOnly: videosOnly,
      filterYear: _mapFilterYear,
    );
    final totalP = visited.fold<int>(0, (acc, c) => acc + c.photoCount);
    final totalV = visited.fold<int>(0, (acc, c) => acc + c.videoCount);
    final basePool = videosOnly ? _videosOnly : _photosOnly;
    final availableYears = basePool
        .map((m) => m.year)
        .where((y) => y.isNotEmpty && y != 'unknown_date' && int.tryParse(y) != null)
        .toSet()
        .toList()
      ..sort();
    final filteredPool = _mapFilterYear == null
        ? basePool
        : basePool.where((m) => m.year == _mapFilterYear).toList();
    final geoPhotos = filteredPool
        .where((m) => m.latitude != null && m.longitude != null)
        .map(
          (m) => MapGeoPhoto(
            id: m.id,
            latitude: m.latitude!,
            longitude: m.longitude!,
            country: m.country,
            city: m.city,
            captureDate: m.captureDate,
            thumbnailUrl: m.thumbnailUrl,
          ),
        )
        .toList(growable: false);
    final wonderAlbums = _nodesById.values
        .where((n) => n.totalCount > 0)
        .map((n) => WonderAlbumOption(id: n.id, name: n.name, count: n.totalCount))
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return WorldMapTab(
      visitedCountries: visited,
      geoPhotos: geoPhotos,
      availableYears: availableYears,
      selectedYear: _mapFilterYear,
      onYearChanged: (y) => setState(() => _mapFilterYear = y),
      wonderAlbums: wonderAlbums,
      onFetchWonderPhotos: (albumIds, wonder) {
        final expandedIds = albumIds
            .expand((id) {
              final node = _nodesById[id];
              return node != null && node.isFolder ? _getAllDescendantAlbumIds(id) : {id};
            })
            .toSet();
        final matched = <WonderPhotoPreview>[];
        for (final m in basePool) {
          final inAlbum = expandedIds.isNotEmpty && m.albums.any((a) => expandedIds.contains(a));
          final nearGps = m.latitude != null &&
              m.longitude != null &&
              haversineKm(m.latitude!, m.longitude!, wonder.lat, wonder.lon) <= 25.0;
          if (inAlbum || nearGps) {
            matched.add(
              WonderPhotoPreview(
                id: m.id,
                filename: m.filename,
                thumbnailUrl: m.thumbnailUrl,
                largePreviewUrl: m.largePreviewUrl,
                captureDate: m.captureDate,
              ),
            );
            if (matched.length >= 25) break;
          }
        }
        return matched;
      },
      totalPhotos: totalP,
      totalVideos: totalV,
      isVideoMode: videosOnly,
      onAddCountryFolder: () => _showCreateAlbumDialog(defaultParentId: _kPaysFolderId),
      onOpenAlbum: (albumId) {
        final node = _nodesById[albumId];
        if (node != null) {
          _openPhotosForNode(node);
        }
      },
      onOpenCountryMedia: (stats) {
        final matchingAlbumIds = <String>{
          if (stats.discoveryAlbum != null) stats.discoveryAlbum!.albumId,
          ...stats.albums.map((a) => a.albumId),
        }.expand((id) {
          final n = _nodesById[id];
          return n != null && n.isFolder ? _getAllDescendantAlbumIds(id) : {id};
        }).toSet();

        final countryMedia = basePool.where((m) {
          if (m.albums.any((a) => matchingAlbumIds.contains(a))) return true;
          final rawCountry = m.country?.trim();
          if (rawCountry != null && rawCountry.isNotEmpty) {
            return matchCountryMeta(rawCountry)?.iso3 == stats.meta.iso3;
          }
          return false;
        }).toList();

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PhotoGridScreen(
              title: '${stats.meta.flag} ${stats.meta.nameFr}',
              photos: countryMedia,
              nodesById: _nodesById,
              gdriveUrl: _gdriveUrl,
              likesByPhotoId: _likesByPhotoId,
              ratingsByPhotoId: _ratingsByPhotoId,
              currentUserEmail: _auth.email,
              onToggleLike: _handleTogglePhotoLike,
              onUpdateRating: _handleUpdatePhotoRating,
              onAssignAlbum: _handleAssignAlbumToPhoto,
              onDeletePhoto: _handleDeletePhoto,
              onBulkAssignAlbum: _handleBulkAssignAlbumToPhotos,
              onBulkDeletePhotos: _handleBulkDeletePhotos,
            ),
          ),
        );
      },
    );
  }

  // --- GALERIE: Direct Photo Grid Tab ---
  Widget _buildGalleryTab(List<PhotoItem> photos, {required bool isVideo}) {
    final header = Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFFFFFFFF),
        border: Border(bottom: BorderSide(color: Color(0xFFF1E6D2))),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF97316).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isVideo ? Icons.movie_outlined : Icons.photo_library_outlined,
              size: 20,
              color: const Color(0xFF0EA5E9),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isVideo ? "Toutes les vidéos" : "Derniers ajouts (Maroc 10/2026)",
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B)),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  "${photos.length} ${isVideo ? 'vidéos' : 'photos'} • Google Drive HD & Cloud Familial",
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF4ADE80),
              backgroundColor: const Color(0xFFF6EFE2),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => _showAddPhotoDialog(defaultIsVideo: isVideo),
            icon: const Icon(Icons.add_photo_alternate_outlined, size: 16),
            label: const Text("Ajouter", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    return PhotoGridBody(
      photos: photos,
      nodesById: _nodesById,
      gdriveUrl: _gdriveUrl,
      header: header,
      likesByPhotoId: _likesByPhotoId,
      currentUserEmail: _auth.email,
      onToggleLike: _handleTogglePhotoLike,
      onAssignAlbum: _handleAssignAlbumToPhoto,
      onDeletePhoto: _handleDeletePhoto,
      onBulkAssignAlbum: _handleBulkAssignAlbumToPhotos,
      onBulkDeletePhotos: _handleBulkDeletePhotos,
    );
  }

  // --- PHOTOS / VIDEOS: Lightroom Thematics Tab ---
  Widget _buildAlbumsTab() {
    return _buildTreeExplorer(
      rootParentId: null,
      rootTitle: "Thématiques",
      history: _navHistory,
      searchQuery: _albumSearch,
      searchController: _albumSearchController,
      onSearchChanged: (val) => setState(() => _albumSearch = val),
      isYearsTab: false,
    );
  }

  // --- PHOTOS: Years Tab (Arborescence de 00 - Années + 2026) ---
  Widget _buildPhotoYearsTab() {
    return _buildTreeExplorer(
      rootParentId: _kYearsRootId,
      rootTitle: "Années",
      history: _yearsNavHistory,
      searchQuery: _yearsSearch,
      searchController: _yearsSearchController,
      onSearchChanged: (val) => setState(() => _yearsSearch = val),
      isYearsTab: true,
    );
  }

  Widget _buildTreeExplorer({
    required String? rootParentId,
    required String rootTitle,
    required List<AlbumNode> history,
    required String searchQuery,
    required TextEditingController searchController,
    required ValueChanged<String> onSearchChanged,
    required bool isYearsTab,
  }) {
    final isVideoMode = _mediaMode == 1;
    final currentParentId = history.isEmpty ? rootParentId : history.last.id;
    final currentChildren = _childrenByParent[currentParentId] ?? [];

    final baseFiltered = searchQuery.isEmpty
        ? currentChildren
        : _nodesById.values.where((a) {
            if (a.id == _kYearsRootId) return false;
            final inYears = _isInsideYearsTree(a.id);
            if (isYearsTab != inYears) return false;
            return a.name.toLowerCase().contains(searchQuery.toLowerCase());
          }).toList();

    final filtered = isVideoMode
        ? baseFiltered.where((n) => n.totalVideoCount > 0).toList()
        : baseFiltered.where((n) => !(n.totalCount == 0 && n.totalVideoCount > 0)).toList();

    return Column(
      children: [
        // Breadcrumb bar + Nouveau dossier/album
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          color: const Color(0xFFFFFFFF),
          child: Row(
            children: [
              if (history.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.arrow_back, size: 20, color: Color(0xFF0EA5E9)),
                  onPressed: () => setState(() => history.removeLast()),
                  tooltip: "Retour au dossier parent",
                ),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      InkWell(
                        onTap: () => setState(() => history.clear()),
                        child: Text(
                          rootTitle,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: history.isEmpty ? FontWeight.bold : FontWeight.normal,
                            color: history.isEmpty ? const Color(0xFF0EA5E9) : Color(0xFF64748B),
                          ),
                        ),
                      ),
                      for (int i = 0; i < history.length; i++) ...[
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4),
                          child: Icon(Icons.chevron_right, size: 16, color: Color(0xFF94A3B8)),
                        ),
                        InkWell(
                          onTap: () => setState(() {
                            while (history.length > i + 1) {
                              history.removeLast();
                            }
                          }),
                          child: Text(
                            history[i].name,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: i == history.length - 1 ? FontWeight.bold : FontWeight.normal,
                              color: i == history.length - 1 ? const Color(0xFF0EA5E9) : Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF97316),
                  foregroundColor: Colors.white,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => _showCreateAlbumDialog(defaultParentId: currentParentId),
                icon: const Icon(Icons.create_new_folder_outlined, size: 16),
                label: const Text("Nouveau dossier / album", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),

        // Search in folders/albums
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
          child: TextField(
            controller: searchController,
            decoration: InputDecoration(
              hintText: searchQuery.isEmpty && history.isNotEmpty
                  ? "Filtrer dans ${history.last.name}..."
                  : (isYearsTab ? "Rechercher une année, un mois ou événement..." : "Rechercher une thématique..."),
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        searchController.clear();
                        onSearchChanged('');
                      },
                    )
                  : null,
              filled: true,
              fillColor: const Color(0xFFF6EFE2),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
            ),
            onChanged: onSearchChanged,
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              "💡 Astuce : maintenez appuyé sur un dossier/album (ou cliquez sur ⋮) pour le déplacer, le renommer ou le supprimer.",
              style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
            ),
          ),
        ),

        // List
        Expanded(
          child: filtered.isEmpty
              ? const Center(
                  child: Text("Aucun dossier ou album trouvé", style: TextStyle(color: Color(0xFF94A3B8))),
                )
              : ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, idx) {
                    final node = filtered[idx];
                    final children = (_childrenByParent[node.id] ?? []).where((c) => !isVideoMode || c.totalVideoCount > 0).toList();
                    final hasChildren = children.isNotEmpty;
                    final displayTotal = isVideoMode ? node.totalVideoCount : node.totalCount;
                    final displayDirect = isVideoMode ? node.directVideoCount : node.directCount;
                    final unitLabel = isVideoMode ? 'vidéos' : 'photos';
                    final coverPhoto = _getCoverPhotoForNode(node, isVideoMode: isVideoMode);
                    final coverThumb = coverPhoto?.thumbnailUrl;

                    return ListTile(
                      leading: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF6EFE2),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFEBDDC6)),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: coverThumb != null
                                ? Image.network(coverThumb, fit: BoxFit.cover, cacheWidth: 120)
                                : Icon(
                                    node.isFolder
                                        ? (isYearsTab && history.isEmpty ? Icons.calendar_month_outlined : Icons.folder_outlined)
                                        : (isVideoMode ? Icons.movie_outlined : Icons.photo_library_outlined),
                                    color: node.isFolder ? const Color(0xFFFBBF24) : const Color(0xFF0EA5E9),
                                    size: 24,
                                  ),
                          ),
                          if (node.isFolder && coverThumb != null)
                            Positioned(
                              right: -3,
                              bottom: -3,
                              child: Container(
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: const Color(0xFFEBDDC6)),
                                ),
                                child: const Icon(Icons.folder_rounded, size: 11, color: Color(0xFFF59E0B)),
                              ),
                            ),
                        ],
                      ),
                      title: Text(
                        node.name,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: node.isFolder ? FontWeight.bold : FontWeight.w500,
                        ),
                      ),
                      subtitle: Text(
                        "${node.isFolder ? '${children.length} sous-dossiers/albums • $displayTotal $unitLabel' : '$displayDirect $unitLabel'}"
                        "${node.createdByName != null && node.createdByName!.isNotEmpty ? ' • par ${node.createdByName}' : ''}",
                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (node.isFolder && displayTotal > 0)
                            IconButton(
                              icon: const Icon(Icons.grid_view, size: 18, color: Color(0xFF64748B)),
                              tooltip: "Voir tous les médias du dossier",
                              onPressed: () => _openPhotosForNode(node),
                            ),
                          IconButton(
                            icon: const Icon(Icons.more_vert, size: 18, color: Color(0xFF64748B)),
                            tooltip: "Actions (Déplacer, Renommer, Supprimer)",
                            onPressed: () => _showNodeActionsSheet(node),
                          ),
                          if (hasChildren)
                            const Icon(Icons.chevron_right, size: 20, color: Color(0xFF94A3B8)),
                        ],
                      ),
                      onLongPress: () => _showNodeActionsSheet(node),
                      onTap: () {
                        if (hasChildren || node.isFolder) {
                          setState(() {
                            history.add(node);
                            searchController.clear();
                            onSearchChanged('');
                          });
                        } else {
                          _openPhotosForNode(node);
                        }
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  Set<String> _getAllDescendantAlbumIds(String nodeId) {
    final ids = <String>{nodeId};
    final children = _childrenByParent[nodeId] ?? [];
    for (final child in children) {
      ids.addAll(_getAllDescendantAlbumIds(child.id));
    }
    return ids;
  }

  PhotoItem? _getCoverPhotoForNode(AlbumNode node, {bool isVideoMode = false}) {
    final customId = _albumCoverPhotoIdById[node.id];
    if (customId != null) {
      for (final p in _allPhotos) {
        if (p.id == customId && p.thumbnailUrl != null) return p;
      }
    }
    final targetIds = node.isFolder ? _getAllDescendantAlbumIds(node.id) : {node.id};
    final pool = isVideoMode ? _videosOnly : _photosOnly;
    for (final p in pool) {
      if (p.thumbnailUrl != null && p.albums.any((a) => targetIds.contains(a))) {
        return p;
      }
    }
    return null;
  }

  Future<void> _handleSetAlbumCover(PhotoItem photo, {String? preferredAlbumId}) async {
    String? targetAlbumId = preferredAlbumId;
    if (targetAlbumId == null && photo.albums.isNotEmpty) {
      targetAlbumId = photo.albums.first;
    }
    if (targetAlbumId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFF1E293B),
            content: Text('Cette photo n\'appartient à aucun album.', style: TextStyle(color: Colors.white)),
          ),
        );
      }
      return;
    }
    setState(() {
      _albumCoverPhotoIdById[targetAlbumId!] = photo.id;
    });
    final ok = await CloudSyncService.createCustomAlbum(
      id: '__cover__$targetAlbumId',
      name: '${photo.id}',
      parentId: _kCoverMetaParentId,
      isFolder: false,
    );
    if (!mounted) return;
    final albumName = _nodesById[targetAlbumId]?.name ?? 'album';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF1E293B),
        content: Text(
          ok
              ? '✔ Photo définie comme couverture de "$albumName" !'
              : '⚠ Couverture définie localement.',
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
      ),
    );
  }

  Future<List<PhotoItem>> _pickAndUploadFilesToAlbum(AlbumNode node) async {
    try {
      final results = await Connectivity().checkConnectivity();
      final hasWifi = results.contains(ConnectivityResult.wifi) ||
          results.contains(ConnectivityResult.ethernet);
      if (!hasWifi && mounted) {
        final proceed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            title: const Row(
              children: [
                Icon(Icons.wifi_off_rounded, color: Color(0xFFF97316)),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Protection Wi-Fi',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                  ),
                ),
              ],
            ),
            content: const Text(
              'Vous n\'êtes pas connecté en Wi-Fi.\nL\'envoi vers Google Drive peut consommer vos données mobiles. Continuer quand même ?',
              style: TextStyle(fontSize: 13, color: Color(0xFF475569)),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Attendre le Wi-Fi')),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFFF97316)),
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Envoyer quand même'),
              ),
            ],
          ),
        );
        if (proceed != true) return const [];
      }
    } catch (_) {}

    final picked = await FilePicker.platform.pickFiles(
      type: FileType.media,
      allowMultiple: true,
      withData: true,
    );
    if (picked == null || picked.files.isEmpty) return const [];

    final uploaded = <PhotoItem>[];
    final effectiveIso = _getEffectiveCountryIsoForNode(node.id);
    final countryName = effectiveIso != null ? kCountriesByIso[effectiveIso]?.nameFr : null;

    for (int i = 0; i < picked.files.length; i++) {
      final f = picked.files[i];
      final bytes = f.bytes;
      if (bytes == null) continue;
      final lower = f.name.toLowerCase();
      final isVid = lower.endsWith('.mp4') || lower.endsWith('.mov') || lower.endsWith('.avi');
      final mime = isVid ? 'video/mp4' : 'image/jpeg';
      final driveId = await CloudSyncService.uploadFileToGoogleDrive(
        filename: f.name,
        bytes: bytes,
        mimeType: mime,
        folderName: 'Medias Familly - ${node.name}',
      );
      final now = DateTime.now();
      final dFolder = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final photoId = DateTime.now().millisecondsSinceEpoch + i;
      final rec = CustomPhotoRecord(
        id: photoId,
        filename: f.name,
        year: now.year.toString(),
        dateFolder: dFolder,
        captureDate: now.toIso8601String(),
        width: 0,
        height: 0,
        fileSize: bytes.length,
        isVideo: isVid,
        driveId: driveId,
        country: countryName,
        albums: [node.id],
        addedByName: _auth.isSignedIn ? _auth.shortLabel : 'Invité',
        addedByEmail: _auth.email,
      );
      await CloudSyncService.addCustomPhoto(rec);
      final item = PhotoItem(
        id: photoId,
        filename: f.name,
        year: now.year.toString(),
        dateFolder: dFolder,
        captureDate: now.toIso8601String(),
        width: 0,
        height: 0,
        fileSize: bytes.length,
        isVideo: isVid,
        driveId: driveId,
        country: countryName,
        albums: [node.id],
        addedByName: rec.addedByName,
        addedByEmail: rec.addedByEmail,
      );
      uploaded.add(item);
      if (mounted) {
        setState(() {
          _allPhotos.insert(0, item);
          if (isVid) {
            _videosOnly.insert(0, item);
          } else {
            _photosOnly.insert(0, item);
          }
          _recalculateAlbumCounts();
        });
      }
    }
    return uploaded;
  }

  void _openPhotosForNode(AlbumNode node) {
    final targetIds = node.isFolder ? _getAllDescendantAlbumIds(node.id) : {node.id};
    final pool = _mediaMode == 1 ? _videosOnly : _photosOnly;
    final albumPhotos = pool.where((p) => p.albums.any((aId) => targetIds.contains(aId))).toList();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PhotoGridScreen(
          title: node.name,
          albumId: node.id,
          photos: albumPhotos,
          nodesById: _nodesById,
          gdriveUrl: _gdriveUrl,
          likesByPhotoId: _likesByPhotoId,
          ratingsByPhotoId: _ratingsByPhotoId,
          currentUserEmail: _auth.email,
          onToggleLike: _handleTogglePhotoLike,
          onUpdateRating: _handleUpdatePhotoRating,
          onAssignAlbum: _handleAssignAlbumToPhoto,
          onDeletePhoto: _handleDeletePhoto,
          onBulkAssignAlbum: _handleBulkAssignAlbumToPhotos,
          onBulkDeletePhotos: _handleBulkDeletePhotos,
          onSetAlbumCover: (photo) => _handleSetAlbumCover(photo, preferredAlbumId: node.id),
          onUploadToAlbum: () => _pickAndUploadFilesToAlbum(node),
        ),
      ),
    );
  }

  void _showNodeActionsSheet(AlbumNode node) {
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: const Color(0xFFFFFFFF),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFEBDDC6)),
        ),
        title: Row(
          children: [
            Icon(
              node.isFolder ? Icons.folder_outlined : Icons.photo_library_outlined,
              color: node.isFolder ? const Color(0xFFFBBF24) : const Color(0xFF0EA5E9),
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                node.name,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B)),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.grid_view, color: Color(0xFF0EA5E9)),
              title: const Text("Voir toutes les photos", style: TextStyle(fontSize: 14)),
              subtitle: Text("${node.totalCount} photos", style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
              onTap: () {
                Navigator.of(dialogCtx).pop();
                _openPhotosForNode(node);
              },
            ),
            ListTile(
              leading: const Icon(Icons.public_rounded, color: Color(0xFF0EA5E9)),
              title: const Text("Pays sur la carte", style: TextStyle(fontSize: 14)),
              subtitle: Builder(
                builder: (_) {
                  final iso = _getEffectiveCountryIsoForNode(node.id);
                  final meta = iso != null ? kCountriesByIso[iso] : null;
                  final label = meta != null
                      ? '${meta.flag} ${meta.nameFr}${_albumCountryIsoById.containsKey(node.id) ? '' : ' (par défaut)'}'
                      : 'Aucun pays assigné';
                  return Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)));
                },
              ),
              onTap: () {
                Navigator.of(dialogCtx).pop();
                _showAssignCountryToAlbumDialog(node);
              },
            ),
            ListTile(
              leading: const Icon(Icons.drive_file_move_outlined, color: Color(0xFFFBBF24)),
              title: const Text("Déplacer vers un autre niveau / dossier", style: TextStyle(fontSize: 14)),
              onTap: () {
                Navigator.of(dialogCtx).pop();
                _showMoveNodeDialog(node);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined, color: Color(0xFF475569)),
              title: const Text("Renommer", style: TextStyle(fontSize: 14)),
              onTap: () {
                Navigator.of(dialogCtx).pop();
                _showRenameNodeDialog(node);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Color(0xFFF87171)),
              title: const Text("Supprimer ce dossier / album", style: TextStyle(fontSize: 14, color: Color(0xFFF87171))),
              onTap: () {
                Navigator.of(dialogCtx).pop();
                _confirmDeleteNodeDialog(node);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text("Fermer", style: TextStyle(color: Color(0xFF64748B))),
          ),
        ],
      ),
    );
  }

  Future<void> _showMoveNodeDialog(AlbumNode node) async {
    final descendants = _getAllDescendantAlbumIds(node.id);
    final candidateFolders = _nodesById.values
        .where((f) => f.isFolder && !descendants.contains(f.id) && f.id != _kYearsRootId)
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    String? selectedParentId = node.parentId;

    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFFFFFFFF),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFEBDDC6)),
          ),
          title: Text(
            'Déplacer "${node.name}"',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B)),
          ),
          content: SizedBox(
            width: 400,
            child: DropdownButtonFormField<String?>(
              value: selectedParentId == null ||
                      selectedParentId == _kYearsRootId ||
                      candidateFolders.any((f) => f.id == selectedParentId)
                  ? selectedParentId
                  : null,
              isExpanded: true,
              dropdownColor: const Color(0xFFF6EFE2),
              decoration: InputDecoration(
                labelText: "Nouveau dossier parent",
                filled: true,
                fillColor: const Color(0xFFF6EFE2),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text("📁 Racine de Thématiques"),
                ),
                const DropdownMenuItem<String?>(
                  value: _kYearsRootId,
                  child: Text("📅 Racine de Années (00 - Années)"),
                ),
                ...candidateFolders.map(
                  (f) => DropdownMenuItem<String?>(
                    value: f.id,
                    child: Text(
                      "${_isInsideYearsTree(f.id) ? '📅' : '📁'} ${f.name}",
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
              onChanged: (val) => setDialogState(() => selectedParentId = val),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text("Annuler", style: TextStyle(color: Color(0xFF64748B))),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF97316),
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.check, size: 18),
              label: const Text("Déplacer"),
              onPressed: () async {
                Navigator.of(dialogCtx).pop();
                setState(() {
                  _nodesById[node.id] = AlbumNode(
                    id: node.id,
                    name: node.name,
                    parentId: selectedParentId,
                    isFolder: node.isFolder,
                    directCount: node.directCount,
                    totalCount: node.totalCount,
                    createdByName: node.createdByName,
                  );
                  _recalculateAlbumCounts();
                });

                final ok = await CloudSyncService.createCustomAlbum(
                  id: node.id,
                  name: node.name,
                  parentId: selectedParentId,
                  isFolder: node.isFolder,
                );
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: const Color(0xFF1E293B),
                    content: Text(
                      ok
                          ? '✔ "${node.name}" déplacé et synchronisé pour tout le monde !'
                          : '⚠ Déplacé localement.',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showRenameNodeDialog(AlbumNode node) async {
    final nameController = TextEditingController(text: node.name);
    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: const Color(0xFFFFFFFF),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFEBDDC6)),
        ),
        title: const Text(
          "Renommer le dossier / album",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B)),
        ),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: InputDecoration(
            labelText: "Nouveau nom",
            filled: true,
            fillColor: const Color(0xFFF6EFE2),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text("Annuler", style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF97316),
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final newName = nameController.text.trim();
              if (newName.isEmpty) return;
              Navigator.of(dialogCtx).pop();
              setState(() {
                _nodesById[node.id] = AlbumNode(
                  id: node.id,
                  name: newName,
                  parentId: node.parentId,
                  isFolder: node.isFolder,
                  directCount: node.directCount,
                  totalCount: node.totalCount,
                  createdByName: node.createdByName,
                );
                _rebuildChildrenTree();
              });
              await CloudSyncService.createCustomAlbum(
                id: node.id,
                name: newName,
                parentId: node.parentId,
                isFolder: node.isFolder,
              );
            },
            child: const Text("Enregistrer"),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteNodeDialog(AlbumNode node) async {
    final descendantIds = _getAllDescendantAlbumIds(node.id);
    final subCount = descendantIds.length - 1;
    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: const Color(0xFFFFFFFF),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFEBDDC6)),
        ),
        title: Text(
          'Supprimer "${node.name}" ?',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B)),
        ),
        content: Text(
          subCount > 0
              ? 'Attention : ce dossier contient $subCount sous-dossier(s) ou sous-album(s). Tout ce qui se trouve en dessous sera également supprimé de l\'arborescence pour tous les utilisateurs (les photos elles-mêmes restent dans la Galerie).'
              : 'Ce dossier ou album sera supprimé de l\'arborescence pour tous les utilisateurs (les photos elles-mêmes restent dans la Galerie).',
          style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text("Annuler", style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.delete_outline, size: 18),
            label: Text(subCount > 0 ? "Tout supprimer ($subCount + 1)" : "Supprimer"),
            onPressed: () async {
              Navigator.of(dialogCtx).pop();
              final nodesToDelete = descendantIds
                  .map((id) => _nodesById[id])
                  .whereType<AlbumNode>()
                  .toList();
              setState(() {
                for (final id in descendantIds) {
                  _deletedAlbumIds.add(id);
                  _nodesById.remove(id);
                }
                _navHistory.removeWhere((n) => descendantIds.contains(n.id));
                _yearsNavHistory.removeWhere((n) => descendantIds.contains(n.id));
                _recalculateAlbumCounts();
              });
              bool allOk = true;
              for (final target in nodesToDelete) {
                final ok = await CloudSyncService.createCustomAlbum(
                  id: target.id,
                  name: target.name,
                  parentId: target.parentId,
                  isFolder: target.isFolder,
                  isDeleted: true,
                );
                if (!ok) allOk = false;
              }
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: const Color(0xFF1E293B),
                  content: Text(
                    allOk
                        ? '✔ "${node.name}"${subCount > 0 ? ' et $subCount sous-élément(s)' : ''} supprimé(s).'
                        : '⚠ Supprimé localement.',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // --- VIDEOS: Only by Year Tab ---
  Widget _buildVideoYearsTab() {
    return Column(
      children: [
        // "Toutes les vidéos" Tile
        ListTile(
          tileColor: const Color(0xFFF6EFE2).withValues(alpha: 0.5),
          leading: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFF97316).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.movie_filter_outlined, color: Color(0xFF0EA5E9), size: 24),
          ),
          title: const Text("Toutes les vidéos", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF97316).withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text("${_videosOnly.length}", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0EA5E9))),
          ),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PhotoGridScreen(
                  title: "Toutes les vidéos",
                  photos: _videosOnly,
                  nodesById: _nodesById,
                  gdriveUrl: _gdriveUrl,
                  likesByPhotoId: _likesByPhotoId,
                  currentUserEmail: _auth.email,
                  onToggleLike: _handleTogglePhotoLike,
                  onAssignAlbum: _handleAssignAlbumToPhoto,
                  onDeletePhoto: _handleDeletePhoto,
                ),
              ),
            );
          },
        ),
        const Divider(height: 1, color: Color(0xFFF1E6D2)),
        // List of Video Years
        Expanded(
          child: ListView.builder(
            itemCount: _videoYears.length,
            itemBuilder: (context, idx) {
              final vy = _videoYears[idx];
              final label = vy.year == 'unknown_date' ? 'Vidéos sans date' : "Vidéos ${vy.year}";
              return ListTile(
                leading: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF6EFE2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.movie_outlined, color: Color(0xFFFBBF24), size: 22),
                ),
                title: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF6EFE2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text("${vy.count}", style: const TextStyle(fontSize: 11, color: Color(0xFF475569))),
                ),
                onTap: () {
                  final yearVideos = _videosOnly.where((p) => p.year == vy.year).toList();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PhotoGridScreen(
                        title: label,
                        photos: yearVideos,
                        nodesById: _nodesById,
                        gdriveUrl: _gdriveUrl,
                        likesByPhotoId: _likesByPhotoId,
                        currentUserEmail: _auth.email,
                        onToggleLike: _handleTogglePhotoLike,
                        onAssignAlbum: _handleAssignAlbumToPhoto,
                        onDeletePhoto: _handleDeletePhoto,
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSearchTab() {
    return PhotoSearchScreen(
      allPhotos: _mediaMode == 1 ? _videosOnly : _photosOnly,
      nodesById: _nodesById,
      gdriveUrl: _gdriveUrl,
      likesByPhotoId: _likesByPhotoId,
      ratingsByPhotoId: _ratingsByPhotoId,
      currentUserEmail: _auth.email,
      onToggleLike: _handleTogglePhotoLike,
      onUpdateRating: _handleUpdatePhotoRating,
      onAssignAlbum: _handleAssignAlbumToPhoto,
      onDeletePhoto: _handleDeletePhoto,
    );
  }

  Future<void> _showCreateAlbumDialog({String? defaultParentId}) async {
    final nameController = TextEditingController();
    bool isFolder = defaultParentId == _kPaysFolderId;
    String? selectedParentId = defaultParentId;
    WorldCountryMeta? selectedCountry;
    final folderNodes = _nodesById.values.where((n) => n.isFolder && n.id != _kYearsRootId).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final isPaysParent = selectedParentId == _kPaysFolderId;
          return AlertDialog(
            backgroundColor: const Color(0xFFFFFFFF),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Color(0xFFEBDDC6)),
            ),
            title: Row(
              children: [
                Icon(
                  isPaysParent ? Icons.public_rounded : Icons.create_new_folder_outlined,
                  color: isPaysParent ? const Color(0xFF0EA5E9) : const Color(0xFFFBBF24),
                  size: 24,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isPaysParent ? "Ajouter un pays (lié à La carte)" : "Nouveau dossier ou album",
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B)),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 420,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isPaysParent) ...[
                      DropdownButtonFormField<WorldCountryMeta>(
                        value: selectedCountry,
                        isExpanded: true,
                        dropdownColor: const Color(0xFFF6EFE2),
                        decoration: InputDecoration(
                          labelText: "Choisir un pays (connecté à La carte)",
                          filled: true,
                          fillColor: const Color(0xFFF6EFE2),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        items: kWorldCountries
                            .map(
                              (c) => DropdownMenuItem<WorldCountryMeta>(
                                value: c,
                                child: Text('${c.flag}  ${c.nameFr} (${c.continent})'),
                              ),
                            )
                            .toList(),
                        onChanged: (c) {
                          setDialogState(() {
                            selectedCountry = c;
                            if (c != null) {
                              nameController.text = c.nameFr;
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextField(
                      controller: nameController,
                      autofocus: !isPaysParent,
                      decoration: InputDecoration(
                        labelText: isPaysParent ? "Nom du dossier pays (modifiable)" : "Nom du dossier ou de l'album",
                        hintText: isPaysParent ? "Ex: Japon" : "Ex: Vacances Été 2027",
                        filled: true,
                        fillColor: const Color(0xFFF6EFE2),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String?>(
                      value: selectedParentId == null ||
                              selectedParentId == _kYearsRootId ||
                              folderNodes.any((f) => f.id == selectedParentId)
                          ? selectedParentId
                          : null,
                      isExpanded: true,
                      dropdownColor: const Color(0xFFF6EFE2),
                      decoration: InputDecoration(
                        labelText: "Emplacement (Dossier parent)",
                        filled: true,
                        fillColor: const Color(0xFFF6EFE2),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text("📁 Racine de Thématiques"),
                        ),
                        const DropdownMenuItem<String?>(
                          value: _kYearsRootId,
                          child: Text("📅 Racine de Années (00 - Années)"),
                        ),
                        ...folderNodes.map(
                          (f) => DropdownMenuItem<String?>(
                            value: f.id,
                            child: Text(
                              "${f.id == _kPaysFolderId ? '🌍' : (_isInsideYearsTree(f.id) ? '📅' : '📁')} ${f.name}",
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                      onChanged: (val) => setDialogState(() {
                        selectedParentId = val;
                        if (val == _kPaysFolderId) {
                          isFolder = true;
                        }
                      }),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text("Créer comme Dossier (peut contenir des sous-albums)", style: TextStyle(fontSize: 13)),
                      subtitle: Text(
                        isFolder ? "Type : Dossier parent 📁" : "Type : Album photo 🖼️",
                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                      ),
                      value: isFolder,
                      activeThumbColor: const Color(0xFFFBBF24),
                      onChanged: (val) => setDialogState(() => isFolder = val),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text("Annuler", style: TextStyle(color: Color(0xFF64748B))),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF97316),
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.check, size: 18),
              label: const Text("Créer et partager"),
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) return;
                Navigator.of(dialogCtx).pop();

                final newId = 'custom_${DateTime.now().millisecondsSinceEpoch}';
                setState(() {
                  _nodesById[newId] = AlbumNode(
                    id: newId,
                    name: name,
                    parentId: selectedParentId,
                    isFolder: isFolder,
                    directCount: 0,
                    totalCount: 0,
                    createdByName: _auth.isSignedIn ? _auth.shortLabel : null,
                  );
                  _customAlbumIds.add(newId);
                  _rebuildChildrenTree();
                });

                final ok = await CloudSyncService.createCustomAlbum(
                  id: newId,
                  name: name,
                  parentId: selectedParentId,
                  isFolder: isFolder,
                );
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: const Color(0xFF1E293B),
                    content: Text(
                      ok
                          ? '✔ "${name}" créé et synchronisé en direct avec toute la famille !'
                          : '⚠ Créé localement (exécutez scripts/supabase_schema.sql dans Supabase pour activer la sauvegarde cloud).',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
      ),
    );
  }

  Future<void> _showAddPhotoDialog({bool defaultIsVideo = false, String? defaultAlbumId}) async {
    final driveLinkController = TextEditingController();
    final filenameController = TextEditingController();
    final yearController = TextEditingController(text: DateTime.now().year.toString());
    final countryController = TextEditingController();
    final cityController = TextEditingController();
    bool isVideo = defaultIsVideo;
    String? selectedAlbumId = defaultAlbumId ?? (_navHistory.isNotEmpty ? _navHistory.last.id : null);

    final allAlbumsSorted = _nodesById.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFFFFFFFF),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFEBDDC6)),
          ),
          title: const Row(
            children: [
              Icon(Icons.add_photo_alternate_outlined, color: Color(0xFF4ADE80), size: 24),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  "Ajouter une photo / vidéo Google Drive",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B)),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "1. Uploadez votre fichier dans le dossier Google Drive partagé.\n2. Collez ci-dessous son lien de partage Google Drive (ou son ID) :",
                    style: TextStyle(fontSize: 11, color: Color(0xFF475569)),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: driveLinkController,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: "Lien Google Drive ou File ID *",
                      hintText: "https://drive.google.com/file/d/.../view",
                      filled: true,
                      fillColor: const Color(0xFFF6EFE2),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: filenameController,
                    decoration: InputDecoration(
                      labelText: "Titre / Nom du fichier *",
                      hintText: "Ex: vacances-maroc-200.jpg",
                      filled: true,
                      fillColor: const Color(0xFFF6EFE2),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: yearController,
                          decoration: InputDecoration(
                            labelText: "Année",
                            filled: true,
                            fillColor: const Color(0xFFF6EFE2),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: countryController,
                          decoration: InputDecoration(
                            labelText: "Pays (optionnel)",
                            filled: true,
                            fillColor: const Color(0xFFF6EFE2),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String?>(
                    value: allAlbumsSorted.any((a) => a.id == selectedAlbumId) ? selectedAlbumId : null,
                    isExpanded: true,
                    dropdownColor: const Color(0xFFF6EFE2),
                    decoration: InputDecoration(
                      labelText: "Ranger dans l'album / dossier",
                      filled: true,
                      fillColor: const Color(0xFFF6EFE2),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text("Aucun album spécifique"),
                      ),
                      ...allAlbumsSorted.map(
                        (a) => DropdownMenuItem<String?>(
                          value: a.id,
                          child: Text(
                            "${a.isFolder ? '📁' : '🖼️'} ${a.name}",
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                    onChanged: (val) => setDialogState(() => selectedAlbumId = val),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text("C'est une vidéo", style: TextStyle(fontSize: 13)),
                    value: isVideo,
                    activeThumbColor: const Color(0xFFFBBF24),
                    onChanged: (val) => setDialogState(() => isVideo = val),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text("Annuler", style: TextStyle(color: Color(0xFF64748B))),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF97316),
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.cloud_upload_outlined, size: 18),
              label: const Text("Ajouter et synchroniser"),
              onPressed: () async {
                final driveId = CloudSyncService.extractDriveId(driveLinkController.text);
                final fn = filenameController.text.trim().isEmpty
                    ? 'media-${DateTime.now().millisecondsSinceEpoch}.jpg'
                    : filenameController.text.trim();
                final yr = yearController.text.trim().isEmpty ? '2026' : yearController.text.trim();
                Navigator.of(dialogCtx).pop();

                final newId = DateTime.now().millisecondsSinceEpoch;
                final nowIso = DateTime.now().toUtc().toIso8601String();
                final albums = selectedAlbumId != null ? [selectedAlbumId!] : <String>[];

                final record = CustomPhotoRecord(
                  id: newId,
                  filename: fn,
                  year: yr,
                  dateFolder: yr,
                  captureDate: nowIso,
                  isVideo: isVideo,
                  driveId: driveId,
                  country: countryController.text.trim().isEmpty ? null : countryController.text.trim(),
                  city: cityController.text.trim().isEmpty ? null : cityController.text.trim(),
                  albums: albums,
                );

                final newItem = PhotoItem(
                  id: newId,
                  filename: fn,
                  year: yr,
                  dateFolder: yr,
                  captureDate: nowIso,
                  width: 0,
                  height: 0,
                  fileSize: 0,
                  isVideo: isVideo,
                  driveId: driveId,
                  country: record.country,
                  city: record.city,
                  albums: albums,
                  addedByName: _auth.isSignedIn ? _auth.shortLabel : null,
                  addedByEmail: _auth.isSignedIn ? _auth.email : null,
                );

                setState(() {
                  _allPhotos.insert(0, newItem);
                  if (isVideo) {
                    _videosOnly.insert(0, newItem);
                  } else {
                    _photosOnly.insert(0, newItem);
                  }
                  _recalculateAlbumCounts();
                });

                final ok = await CloudSyncService.addCustomPhoto(record);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: const Color(0xFF1E293B),
                    content: Text(
                      ok
                          ? '✔ Média "$fn" ajouté et partagé en temps réel avec toute la famille !'
                          : '⚠ Média ajouté localement (exécutez scripts/supabase_schema.sql dans Supabase).',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleAssignAlbumToPhoto(PhotoItem photo, String albumId) async {
    if (!photo.albums.contains(albumId)) {
      setState(() {
        photo.albums.add(albumId);
        _recalculateAlbumCounts();
      });
    }
    final existing = _overridesByPhotoId[photo.id];
    final added = <String>{...(existing?.addedAlbums ?? []), albumId}.toList();
    final removed = <String>{...(existing?.removedAlbums ?? [])}..remove(albumId);
    final rec = PhotoOverrideRecord(
      photoId: photo.id,
      addedAlbums: added,
      removedAlbums: removed.toList(),
      isDeleted: existing?.isDeleted ?? false,
    );
    _overridesByPhotoId[photo.id] = rec;
    final ok = await CloudSyncService.savePhotoOverride(rec);
    if (!mounted) return;
    final albumName = _nodesById[albumId]?.name ?? albumId;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF1E293B),
        content: Text(
          ok
              ? '✔ Photo classée dans "$albumName" pour toute la famille.'
              : '⚠ Classée localement (vérifiez la table photo_overrides dans Supabase).',
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
      ),
    );
  }

  Future<void> _handleBulkAssignAlbumToPhotos(List<PhotoItem> photos, String albumId) async {
    if (photos.isEmpty) return;
    setState(() {
      for (final photo in photos) {
        if (!photo.albums.contains(albumId)) {
          photo.albums.add(albumId);
        }
      }
      _recalculateAlbumCounts();
    });
    bool allOk = true;
    for (final photo in photos) {
      final existing = _overridesByPhotoId[photo.id];
      final added = <String>{...(existing?.addedAlbums ?? []), albumId}.toList();
      final removed = <String>{...(existing?.removedAlbums ?? [])}..remove(albumId);
      final rec = PhotoOverrideRecord(
        photoId: photo.id,
        addedAlbums: added,
        removedAlbums: removed.toList(),
        isDeleted: existing?.isDeleted ?? false,
      );
      _overridesByPhotoId[photo.id] = rec;
      final ok = await CloudSyncService.savePhotoOverride(rec);
      if (!ok) allOk = false;
    }
    if (!mounted) return;
    final albumName = _nodesById[albumId]?.name ?? albumId;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF1E293B),
        content: Text(
          allOk
              ? '✔ ${photos.length} média(s) classé(s) dans "$albumName" pour toute la famille.'
              : '⚠ ${photos.length} média(s) classé(s) localement.',
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
      ),
    );
  }

  Future<void> _handleBulkDeletePhotos(List<PhotoItem> photos) async {
    if (photos.isEmpty) return;
    final ids = photos.map((p) => p.id).toSet();
    final now = DateTime.now();
    setState(() {
      _allPhotos.removeWhere((p) => ids.contains(p.id));
      _photosOnly.removeWhere((p) => ids.contains(p.id));
      _videosOnly.removeWhere((p) => ids.contains(p.id));
      for (final p in photos) {
        if (!_trashedPhotos.any((t) => t.id == p.id)) {
          _trashedPhotos.insert(0, p);
        }
        _trashedAtByPhotoId[p.id] = now;
      }
      _recalculateAlbumCounts();
    });
    bool allOk = true;
    for (final photo in photos) {
      final existing = _overridesByPhotoId[photo.id];
      final rec = PhotoOverrideRecord(
        photoId: photo.id,
        addedAlbums: existing?.addedAlbums ?? [],
        removedAlbums: existing?.removedAlbums ?? [],
        isDeleted: true,
      );
      _overridesByPhotoId[photo.id] = rec;
      final ok = await CloudSyncService.savePhotoOverride(rec);
      await CloudSyncService.createCustomAlbum(
        id: '__trash__${photo.id}',
        name: now.toIso8601String(),
        parentId: _kTrashMetaParentId,
        isFolder: false,
      );
      if (!ok) allOk = false;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF1E293B),
        content: Text(
          allOk
              ? '✔ ${photos.length} média(s) mis à la corbeille (conservés 30 jours).'
              : '⚠ ${photos.length} média(s) mis à la corbeille localement.',
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
      ),
    );
  }

  Future<void> _handleDeletePhoto(PhotoItem photo) async {
    final now = DateTime.now();
    setState(() {
      _allPhotos.removeWhere((p) => p.id == photo.id);
      _photosOnly.removeWhere((p) => p.id == photo.id);
      _videosOnly.removeWhere((p) => p.id == photo.id);
      if (!_trashedPhotos.any((t) => t.id == photo.id)) {
        _trashedPhotos.insert(0, photo);
      }
      _trashedAtByPhotoId[photo.id] = now;
      _recalculateAlbumCounts();
    });
    final existing = _overridesByPhotoId[photo.id];
    final rec = PhotoOverrideRecord(
      photoId: photo.id,
      addedAlbums: existing?.addedAlbums ?? [],
      removedAlbums: existing?.removedAlbums ?? [],
      isDeleted: true,
    );
    _overridesByPhotoId[photo.id] = rec;
    final ok = await CloudSyncService.savePhotoOverride(rec);
    await CloudSyncService.createCustomAlbum(
      id: '__trash__${photo.id}',
      name: now.toIso8601String(),
      parentId: _kTrashMetaParentId,
      isFolder: false,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF1E293B),
        content: Text(
          ok
              ? '✔ "${photo.filename}" mise à la corbeille (30 jours).'
              : '⚠ Mise à la corbeille localement.',
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
      ),
    );
  }

  Future<void> _restoreFromTrash(PhotoItem photo) async {
    setState(() {
      _trashedPhotos.removeWhere((t) => t.id == photo.id);
      _trashedAtByPhotoId.remove(photo.id);
      if (!_allPhotos.any((p) => p.id == photo.id)) {
        _allPhotos.insert(0, photo);
        if (photo.isVideo) {
          _videosOnly.insert(0, photo);
        } else {
          _photosOnly.insert(0, photo);
        }
      }
      _recalculateAlbumCounts();
    });
    final existing = _overridesByPhotoId[photo.id];
    final rec = PhotoOverrideRecord(
      photoId: photo.id,
      addedAlbums: existing?.addedAlbums ?? [],
      removedAlbums: existing?.removedAlbums ?? [],
      isDeleted: false,
    );
    _overridesByPhotoId[photo.id] = rec;
    await CloudSyncService.savePhotoOverride(rec);
    await CloudSyncService.createCustomAlbum(
      id: '__trash__${photo.id}',
      name: '',
      parentId: _kTrashMetaParentId,
      isFolder: false,
      isDeleted: true,
    );
  }

  Future<void> _permanentlyPurgePhotos(List<PhotoItem> photos) async {
    if (photos.isEmpty) return;
    final ids = photos.map((p) => p.id).toSet();
    setState(() {
      _trashedPhotos.removeWhere((p) => ids.contains(p.id));
      _purgedPhotoIds.addAll(ids);
      for (final id in ids) {
        _trashedAtByPhotoId.remove(id);
      }
    });
    for (final p in photos) {
      if (p.driveId != null && p.driveId!.isNotEmpty) {
        await CloudSyncService.deleteFileFromGoogleDrive(p.driveId!);
      }
      await CloudSyncService.createCustomAlbum(
        id: '__purged__${p.id}',
        name: 'purged',
        parentId: _kPurgeMetaParentId,
        isFolder: false,
      );
      await CloudSyncService.createCustomAlbum(
        id: '__trash__${p.id}',
        name: '',
        parentId: _kTrashMetaParentId,
        isFolder: false,
        isDeleted: true,
      );
    }
  }

  Future<void> _openTrashScreen() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _TrashScreen(
          getTrashedPhotos: () => _trashedPhotos,
          trashedAtByPhotoId: _trashedAtByPhotoId,
          onRestore: _restoreFromTrash,
          onEmptyOrDeletePermanent: _permanentlyPurgePhotos,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _handleUpdatePhotoRating(PhotoItem photo, int rating, PhotoFlagStatus status) async {
    final rec = PhotoRatingRecord(rating: rating.clamp(0, 5), status: status);
    setState(() {
      _ratingsByPhotoId[photo.id] = rec;
    });
    await CloudSyncService.createCustomAlbum(
      id: '__rate__${photo.id}',
      name: '${rec.rating}:${rec.status.name}',
      parentId: _kRateMetaParentId,
      isFolder: false,
    );
  }

  Future<void> _handleTogglePhotoLike(PhotoItem photo) async {
    if (!_auth.isSignedIn || _auth.email == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF1E293B),
          content: const Text(
            'Connectez-vous avec Google (en haut à droite) pour aimer des photos ❤️',
            style: TextStyle(color: Colors.white, fontSize: 12),
          ),
          action: SnackBarAction(
            label: 'Connexion',
            textColor: const Color(0xFF0EA5E9),
            onPressed: _handleGoogleSignIn,
          ),
        ),
      );
      return;
    }

    final email = _auth.email!;
    final name = _auth.shortLabel;
    final list = List<PhotoLikeRecord>.from(_likesByPhotoId[photo.id] ?? []);
    final alreadyLiked = list.any((l) => l.userEmail == email);

    setState(() {
      if (alreadyLiked) {
        list.removeWhere((l) => l.userEmail == email);
      } else {
        list.add(PhotoLikeRecord(photoId: photo.id, userEmail: email, userName: name));
      }
      _likesByPhotoId[photo.id] = list;
    });

    await CloudSyncService.togglePhotoLike(
      photoId: photo.id,
      isCurrentlyLiked: alreadyLiked,
    );
  }
}

class PhotoGridScreen extends StatefulWidget {
  final String title;
  final String? albumId;
  final List<PhotoItem> photos;
  final Map<String, AlbumNode> nodesById;
  final String gdriveUrl;
  final Map<int, List<PhotoLikeRecord>>? likesByPhotoId;
  final Map<int, PhotoRatingRecord>? ratingsByPhotoId;
  final String? currentUserEmail;
  final Future<void> Function(PhotoItem photo)? onToggleLike;
  final Future<void> Function(PhotoItem photo, int rating, PhotoFlagStatus status)? onUpdateRating;
  final Future<void> Function(PhotoItem photo, String albumId)? onAssignAlbum;
  final Future<void> Function(PhotoItem photo)? onDeletePhoto;
  final Future<void> Function(List<PhotoItem> photos, String albumId)? onBulkAssignAlbum;
  final Future<void> Function(List<PhotoItem> photos)? onBulkDeletePhotos;
  final Future<void> Function(PhotoItem photo)? onSetAlbumCover;
  final Future<List<PhotoItem>> Function()? onUploadToAlbum;

  const PhotoGridScreen({
    super.key,
    required this.title,
    this.albumId,
    required this.photos,
    required this.nodesById,
    required this.gdriveUrl,
    this.likesByPhotoId,
    this.ratingsByPhotoId,
    this.currentUserEmail,
    this.onToggleLike,
    this.onUpdateRating,
    this.onAssignAlbum,
    this.onDeletePhoto,
    this.onBulkAssignAlbum,
    this.onBulkDeletePhotos,
    this.onSetAlbumCover,
    this.onUploadToAlbum,
  });

  @override
  State<PhotoGridScreen> createState() => _PhotoGridScreenState();
}

class _PhotoGridScreenState extends State<PhotoGridScreen> {
  bool _isUploading = false;

  Future<void> _handleUpload() async {
    if (widget.onUploadToAlbum == null || _isUploading) return;
    setState(() => _isUploading = true);
    try {
      final added = await widget.onUploadToAlbum!();
      if (added.isNotEmpty && mounted) {
        setState(() {
          widget.photos.insertAll(0, added);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF1E293B),
            content: Text(
              '✔ ${added.length} média(s) envoyé(s) sur Drive et ajouté(s) à l\'album !',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF1E293B),
            content: Text('Erreur envoi Drive : $e', style: const TextStyle(color: Colors.white, fontSize: 12)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _downloadAlbum({required bool hd}) async {
    final items = widget.photos.where((p) => p.driveId != null).toList();
    if (items.isEmpty) return;
    for (final p in items) {
      final urlStr = hd
          ? 'https://drive.google.com/uc?export=download&id=${p.driveId}'
          : (p.largePreviewUrl ?? 'https://lh3.googleusercontent.com/d/${p.driveId}=w1920');
      await launchUrl(Uri.parse(urlStr), mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFFFFF),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
            Text("${widget.photos.length} éléments", style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          ],
        ),
        actions: [
          if (widget.onUploadToAlbum != null)
            _isUploading
                ? const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF059669)),
                    ),
                  )
                : IconButton(
                    tooltip: 'Envoyer des photos dans cet album (Wi-Fi)',
                    icon: const Icon(Icons.add_photo_alternate_outlined, color: Color(0xFF059669)),
                    onPressed: _handleUpload,
                  ),
          PopupMenuButton<String>(
            tooltip: 'Télécharger l\'album',
            icon: const Icon(Icons.download_rounded, color: Color(0xFF0EA5E9)),
            onSelected: (val) => _downloadAlbum(hd: val == 'hd'),
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'light',
                child: Row(
                  children: [
                    Icon(Icons.photo_size_select_large_rounded, size: 18, color: Color(0xFF0EA5E9)),
                    SizedBox(width: 8),
                    Text('Télécharger version Light (aperçu)'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'hd',
                child: Row(
                  children: [
                    Icon(Icons.hd_rounded, size: 18, color: Color(0xFFF97316)),
                    SizedBox(width: 8),
                    Text('Télécharger version HD originale'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: PhotoGridBody(
        photos: widget.photos,
        nodesById: widget.nodesById,
        gdriveUrl: widget.gdriveUrl,
        likesByPhotoId: widget.likesByPhotoId,
        ratingsByPhotoId: widget.ratingsByPhotoId,
        currentUserEmail: widget.currentUserEmail,
        onToggleLike: widget.onToggleLike,
        onUpdateRating: widget.onUpdateRating,
        onAssignAlbum: widget.onAssignAlbum,
        onDeletePhoto: widget.onDeletePhoto,
        onBulkAssignAlbum: widget.onBulkAssignAlbum,
        onBulkDeletePhotos: widget.onBulkDeletePhotos,
        onSetAlbumCover: widget.onSetAlbumCover,
      ),
    );
  }
}

class PhotoGridBody extends StatefulWidget {
  final List<PhotoItem> photos;
  final Map<String, AlbumNode> nodesById;
  final String gdriveUrl;
  final Widget? header;
  final Map<int, List<PhotoLikeRecord>>? likesByPhotoId;
  final Map<int, PhotoRatingRecord>? ratingsByPhotoId;
  final String? currentUserEmail;
  final Future<void> Function(PhotoItem photo)? onToggleLike;
  final Future<void> Function(PhotoItem photo, int rating, PhotoFlagStatus status)? onUpdateRating;
  final Future<void> Function(PhotoItem photo, String albumId)? onAssignAlbum;
  final Future<void> Function(PhotoItem photo)? onDeletePhoto;
  final Future<void> Function(List<PhotoItem> photos, String albumId)? onBulkAssignAlbum;
  final Future<void> Function(List<PhotoItem> photos)? onBulkDeletePhotos;
  final Future<void> Function(PhotoItem photo)? onSetAlbumCover;

  const PhotoGridBody({
    super.key,
    required this.photos,
    required this.nodesById,
    required this.gdriveUrl,
    this.header,
    this.likesByPhotoId,
    this.ratingsByPhotoId,
    this.currentUserEmail,
    this.onToggleLike,
    this.onUpdateRating,
    this.onAssignAlbum,
    this.onDeletePhoto,
    this.onBulkAssignAlbum,
    this.onBulkDeletePhotos,
    this.onSetAlbumCover,
  });

  @override
  State<PhotoGridBody> createState() => _PhotoGridBodyState();
}

class _PhotoGridBodyState extends State<PhotoGridBody> {
  static const int _pageSize = 60;
  int _visibleCount = _pageSize;
  final ScrollController _scrollController = ScrollController();
  bool _isSelectionMode = false;
  final Set<int> _selectedPhotoIds = {};
  bool _filterLikedOnly = false;
  int _filterMinRating = 0;
  PhotoFlagStatus? _filterStatus;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(covariant PhotoGridBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.photos != widget.photos) {
      if (_visibleCount > widget.photos.length && widget.photos.length > _pageSize) {
        _visibleCount = _pageSize;
      } else if (_visibleCount < _pageSize) {
        _visibleCount = _pageSize;
      }
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 600) {
      _loadMore();
    }
  }

  void _loadMore() {
    if (_visibleCount >= widget.photos.length) return;
    setState(() {
      _visibleCount = (_visibleCount + _pageSize).clamp(0, widget.photos.length);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _toggleSelection(int photoId) {
    setState(() {
      if (_selectedPhotoIds.contains(photoId)) {
        _selectedPhotoIds.remove(photoId);
        if (_selectedPhotoIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _isSelectionMode = true;
        _selectedPhotoIds.add(photoId);
      }
    });
  }

  Future<void> _promptBulkAssignAlbum(BuildContext context, List<PhotoItem> selectedPhotos) async {
    if (selectedPhotos.isEmpty) return;
    final albumsSorted = widget.nodesById.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    String? selectedAlbumId = albumsSorted.isNotEmpty ? albumsSorted.first.id : null;

    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFFFFFFFF),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFEBDDC6)),
          ),
          title: Text(
            'Ranger ${selectedPhotos.length} média(s) dans un album',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B)),
          ),
          content: DropdownButtonFormField<String>(
            value: selectedAlbumId,
            isExpanded: true,
            dropdownColor: const Color(0xFFF6EFE2),
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFFF6EFE2),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
            items: albumsSorted
                .map(
                  (a) => DropdownMenuItem<String>(
                    value: a.id,
                    child: Text("${a.isFolder ? '📁' : '🖼️'} ${a.name}", overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(),
            onChanged: (val) => setDialogState(() => selectedAlbumId = val),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text("Annuler", style: TextStyle(color: Color(0xFF64748B))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF97316),
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                Navigator.of(dialogCtx).pop();
                if (selectedAlbumId == null) return;
                if (widget.onBulkAssignAlbum != null) {
                  await widget.onBulkAssignAlbum!(selectedPhotos, selectedAlbumId!);
                } else if (widget.onAssignAlbum != null) {
                  for (final p in selectedPhotos) {
                    await widget.onAssignAlbum!(p, selectedAlbumId!);
                  }
                }
                if (mounted) {
                  setState(() {
                    _isSelectionMode = false;
                    _selectedPhotoIds.clear();
                  });
                }
              },
              child: const Text("Valider"),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmBulkDelete(BuildContext context, List<PhotoItem> selectedPhotos) async {
    if (selectedPhotos.isEmpty) return;
    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: const Color(0xFFFFFFFF),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFEBDDC6)),
        ),
        title: Text(
          'Mettre ${selectedPhotos.length} média(s) à la corbeille ?',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B)),
        ),
        content: const Text(
          'Ces photos/vidéos seront masquées de la galerie et des albums pour toute la famille.',
          style: TextStyle(fontSize: 12, color: Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text("Annuler", style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.delete_outline, size: 17),
            label: Text('Supprimer (${selectedPhotos.length})'),
            onPressed: () async {
              Navigator.of(dialogCtx).pop();
              if (widget.onBulkDeletePhotos != null) {
                await widget.onBulkDeletePhotos!(selectedPhotos);
              } else if (widget.onDeletePhoto != null) {
                for (final p in selectedPhotos) {
                  await widget.onDeletePhoto!(p);
                }
              }
              if (mounted) {
                setState(() {
                  final deletedIds = selectedPhotos.map((p) => p.id).toSet();
                  widget.photos.removeWhere((p) => deletedIds.contains(p.id));
                  _isSelectionMode = false;
                  _selectedPhotoIds.clear();
                });
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allPhotos = widget.photos;
    if (allPhotos.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.image_not_supported_outlined, size: 48, color: Color(0xFFCBD5E1)),
            const SizedBox(height: 12),
            const Text("Aucun média disponible", style: TextStyle(color: Color(0xFF94A3B8))),
          ],
        ),
      );
    }

    final hasFilterBar = widget.ratingsByPhotoId != null || widget.likesByPhotoId != null;
    final hasActiveFilter = _filterLikedOnly || _filterMinRating > 0 || _filterStatus != null;
    final photos = !hasActiveFilter
        ? allPhotos
        : allPhotos.where((p) {
            if (_filterLikedOnly) {
              final likes = widget.likesByPhotoId?[p.id] ?? const <PhotoLikeRecord>[];
              if (likes.isEmpty) return false;
            }
            final rec = widget.ratingsByPhotoId?[p.id] ?? const PhotoRatingRecord();
            if (_filterMinRating > 0 && rec.rating < _filterMinRating) return false;
            if (_filterStatus != null && rec.status != _filterStatus) return false;
            return true;
          }).toList();

    final displayCount = _visibleCount < photos.length ? _visibleCount : photos.length;
    final supportsBulk = widget.onAssignAlbum != null ||
        widget.onDeletePhoto != null ||
        widget.onBulkAssignAlbum != null ||
        widget.onBulkDeletePhotos != null;
    final selectedPhotos = photos.where((p) => _selectedPhotoIds.contains(p.id)).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 900;
        final crossAxisCount = isWide
            ? (constraints.maxWidth / 210).clamp(3, 7).toInt()
            : (constraints.maxWidth / 130).clamp(2, 6).toInt();
        final gridSpacing = isWide ? 10.0 : 6.0;
        final gridPadding = isWide ? 16.0 : 8.0;
        return Column(
          children: [
            if (widget.header != null) widget.header!,
            if (hasFilterBar)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: const BoxDecoration(
                  color: Color(0xFFFFFFFF),
                  border: Border(bottom: BorderSide(color: Color(0xFFF1E6D2))),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      FilterChip(
                        avatar: Icon(
                          _filterLikedOnly ? Icons.favorite : Icons.favorite_border,
                          size: 14,
                          color: _filterLikedOnly ? Colors.white : const Color(0xFFF43F5E),
                        ),
                        label: Text(
                          'Likées',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: _filterLikedOnly ? Colors.white : const Color(0xFF475569),
                            fontWeight: _filterLikedOnly ? FontWeight.bold : FontWeight.w500,
                          ),
                        ),
                        selected: _filterLikedOnly,
                        selectedColor: const Color(0xFFF43F5E),
                        backgroundColor: const Color(0xFFF6EFE2),
                        visualDensity: VisualDensity.compact,
                        onSelected: (v) => setState(() => _filterLikedOnly = v),
                      ),
                      const SizedBox(width: 6),
                      PopupMenuButton<int>(
                        tooltip: 'Filtrer par étoiles',
                        onSelected: (v) => setState(() => _filterMinRating = v),
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 0, child: Text('Toutes les notes')),
                          PopupMenuItem(value: 1, child: Text('★ 1+ étoile')),
                          PopupMenuItem(value: 2, child: Text('★★ 2+ étoiles')),
                          PopupMenuItem(value: 3, child: Text('★★★ 3+ étoiles')),
                          PopupMenuItem(value: 4, child: Text('★★★★ 4+ étoiles')),
                          PopupMenuItem(value: 5, child: Text('★★★★★ 5 étoiles')),
                        ],
                        child: Chip(
                          avatar: const Icon(Icons.star_rounded, size: 15, color: Color(0xFFF59E0B)),
                          label: Text(
                            _filterMinRating == 0 ? 'Note' : '★ $_filterMinRating+',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: _filterMinRating > 0 ? FontWeight.bold : FontWeight.w500,
                              color: _filterMinRating > 0 ? const Color(0xFFB45309) : const Color(0xFF475569),
                            ),
                          ),
                          backgroundColor: _filterMinRating > 0
                              ? const Color(0xFFFEF3C7)
                              : const Color(0xFFF6EFE2),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                      const SizedBox(width: 6),
                      PopupMenuButton<PhotoFlagStatus?>(
                        tooltip: 'Filtrer par statut',
                        onSelected: (v) => setState(() => _filterStatus = v),
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: null, child: Text('Tous les statuts')),
                          PopupMenuItem(value: PhotoFlagStatus.pick, child: Text('✓ Validées')),
                          PopupMenuItem(value: PhotoFlagStatus.neutral, child: Text('○ Neutres')),
                          PopupMenuItem(value: PhotoFlagStatus.reject, child: Text('✕ Rejetées')),
                        ],
                        child: Chip(
                          avatar: Icon(
                            _filterStatus == PhotoFlagStatus.pick
                                ? Icons.check_circle
                                : (_filterStatus == PhotoFlagStatus.reject ? Icons.cancel : Icons.flag_outlined),
                            size: 15,
                            color: _filterStatus == PhotoFlagStatus.pick
                                ? const Color(0xFF10B981)
                                : (_filterStatus == PhotoFlagStatus.reject ? const Color(0xFFEF4444) : const Color(0xFF64748B)),
                          ),
                          label: Text(
                            _filterStatus == null
                                ? 'Statut'
                                : (_filterStatus == PhotoFlagStatus.pick
                                    ? 'Validées'
                                    : (_filterStatus == PhotoFlagStatus.reject ? 'Rejetées' : 'Neutres')),
                            style: const TextStyle(fontSize: 11.5, color: Color(0xFF475569)),
                          ),
                          backgroundColor: const Color(0xFFF6EFE2),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                      if (hasActiveFilter) ...[
                        const SizedBox(width: 6),
                        ActionChip(
                          label: Text(
                            'Réinit. (${photos.length}/${allPhotos.length})',
                            style: const TextStyle(fontSize: 11, color: Color(0xFFEA580C), fontWeight: FontWeight.w600),
                          ),
                          backgroundColor: const Color(0xFFFFEDD5),
                          visualDensity: VisualDensity.compact,
                          onPressed: () => setState(() {
                            _filterLikedOnly = false;
                            _filterMinRating = 0;
                            _filterStatus = null;
                          }),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            if (supportsBulk)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _isSelectionMode ? const Color(0xFF0C4A6E).withValues(alpha: 0.45) : const Color(0xFFFFF7E8),
                  border: const Border(bottom: BorderSide(color: Color(0xFFF1E6D2))),
                ),
                child: Row(
                  children: [
                    if (_isSelectionMode) ...[
                      Text(
                        '${selectedPhotos.length} sélectionné(s)',
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF7DD3FC)),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            if (selectedPhotos.length == photos.length) {
                              _selectedPhotoIds.clear();
                            } else {
                              _selectedPhotoIds.addAll(photos.map((p) => p.id));
                            }
                          });
                        },
                        child: Text(
                          selectedPhotos.length == photos.length ? 'Aucun' : 'Tout sélect. (${photos.length})',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF0EA5E9)),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => setState(() {
                          _isSelectionMode = false;
                          _selectedPhotoIds.clear();
                        }),
                        icon: const Icon(Icons.close, size: 15, color: Color(0xFF475569)),
                        label: const Text('Annuler', style: TextStyle(fontSize: 12, color: Color(0xFF475569))),
                      ),
                    ] else ...[
                      Text(
                        'Appui long ou bouton pour sélectionner',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF0EA5E9),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: () => setState(() => _isSelectionMode = true),
                        icon: const Icon(Icons.checklist_rounded, size: 16),
                        label: const Text('Sélectionner', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ],
                ),
              ),
            Expanded(
              child: NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  if (notification.metrics.pixels >= notification.metrics.maxScrollExtent - 600) {
                    _loadMore();
                  }
                  return false;
                },
                child: GridView.builder(
                  controller: _scrollController,
                  padding: EdgeInsets.all(gridPadding),
                  cacheExtent: 250,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: gridSpacing,
                    mainAxisSpacing: gridSpacing,
                  ),
                  itemCount: displayCount,
                  itemBuilder: (context, idx) {
                    final photo = photos[idx];
                    final photoLikes = widget.likesByPhotoId?[photo.id] ?? const <PhotoLikeRecord>[];
                    final isLikedByMe = widget.currentUserEmail != null &&
                        photoLikes.any((l) => l.userEmail == widget.currentUserEmail);
                    final ratingRec = widget.ratingsByPhotoId?[photo.id] ?? const PhotoRatingRecord();
                    final isSelected = _selectedPhotoIds.contains(photo.id);
                    return _PhotoGridTile(
                      key: ValueKey(photo.id),
                      photo: photo,
                      likeCount: photoLikes.length,
                      isLikedByMe: isLikedByMe,
                      rating: ratingRec.rating,
                      flagStatus: ratingRec.status,
                      isSelectionMode: _isSelectionMode,
                      isSelected: isSelected,
                      onLongPress: supportsBulk ? () => _toggleSelection(photo.id) : null,
                      onToggleLike: widget.onToggleLike != null
                          ? () async {
                              await widget.onToggleLike!(photo);
                              if (mounted) setState(() {});
                            }
                          : null,
                      onTap: () {
                        if (_isSelectionMode) {
                          _toggleSelection(photo.id);
                        } else {
                          _openLightbox(context, photo);
                        }
                      },
                    );
                  },
                ),
              ),
            ),
            if (_isSelectionMode && selectedPhotos.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: const BoxDecoration(
                  color: Color(0xFFFFFFFF),
                  border: Border(top: BorderSide(color: Color(0xFFEBDDC6))),
                ),
                child: SafeArea(
                  top: false,
                  child: Row(
                    children: [
                      if (widget.onAssignAlbum != null || widget.onBulkAssignAlbum != null)
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF0EA5E9),
                              side: const BorderSide(color: Color(0xFFF97316)),
                              padding: const EdgeInsets.symmetric(vertical: 11),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () => _promptBulkAssignAlbum(context, selectedPhotos),
                            icon: const Icon(Icons.create_new_folder_outlined, size: 17),
                            label: Text('Album (${selectedPhotos.length})', style: const TextStyle(fontSize: 12.5)),
                          ),
                        ),
                      if ((widget.onAssignAlbum != null || widget.onBulkAssignAlbum != null) &&
                          (widget.onDeletePhoto != null || widget.onBulkDeletePhotos != null))
                        const SizedBox(width: 10),
                      if (widget.onDeletePhoto != null || widget.onBulkDeletePhotos != null)
                        Expanded(
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFFEF4444),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 11),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () => _confirmBulkDelete(context, selectedPhotos),
                            icon: const Icon(Icons.delete_outline, size: 17),
                            label: Text('Corbeille (${selectedPhotos.length})', style: const TextStyle(fontSize: 12.5)),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _launchDriveUrl(BuildContext context, String url) async {
    try {
      final uri = Uri.parse(url);
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFFFFFFF),
          content: Text("Impossible d'ouvrir le lien Drive : $e", style: const TextStyle(color: Colors.white)),
        ),
      );
    }
  }

  void _openFullScreenZoom(BuildContext context, PhotoItem photo, String fileViewUrl) {
    final gallery = widget.photos.where((p) => !p.isVideo && (p.largePreviewUrl ?? p.thumbnailUrl) != null).toList();
    var initialIdx = gallery.indexWhere((p) => p.id == photo.id);
    if (initialIdx < 0) {
      final fallbackUrl = photo.largePreviewUrl ?? photo.thumbnailUrl;
      if (fallbackUrl == null) {
        _launchDriveUrl(context, fileViewUrl);
        return;
      }
      gallery.insert(0, photo);
      initialIdx = 0;
    }

    Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: Colors.black.withValues(alpha: 0.96),
        pageBuilder: (_, __, ___) => _FullScreenPhotoViewer(
          photos: gallery,
          initialIndex: initialIdx,
          defaultGdriveUrl: widget.gdriveUrl,
          onLaunchDrive: _launchDriveUrl,
          likesByPhotoId: widget.likesByPhotoId,
          ratingsByPhotoId: widget.ratingsByPhotoId,
          currentUserEmail: widget.currentUserEmail,
          onToggleLike: widget.onToggleLike,
          onUpdateRating: widget.onUpdateRating,
        ),
      ),
    );
  }

  Widget _buildRatingAndStatusBar(PhotoItem photo, void Function(VoidCallback) setInnerState) {
    final current = widget.ratingsByPhotoId?[photo.id] ?? const PhotoRatingRecord();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF6EFE2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEBDDC6)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Note : ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
              for (int star = 1; star <= 5; star++)
                IconButton(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  constraints: const BoxConstraints(),
                  icon: Icon(
                    star <= current.rating ? Icons.star_rounded : Icons.star_border_rounded,
                    color: star <= current.rating ? const Color(0xFFF59E0B) : const Color(0xFF94A3B8),
                    size: 26,
                  ),
                  onPressed: widget.onUpdateRating == null
                      ? null
                      : () async {
                          final nextRating = current.rating == star ? 0 : star;
                          await widget.onUpdateRating!(photo, nextRating, current.status);
                          setInnerState(() {});
                          if (mounted) setState(() {});
                        },
                ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  label: const Center(child: Text('✓ Validée', style: TextStyle(fontSize: 11.5))),
                  selected: current.status == PhotoFlagStatus.pick,
                  selectedColor: const Color(0xFFD1FAE5),
                  onSelected: widget.onUpdateRating == null
                      ? null
                      : (_) async {
                          await widget.onUpdateRating!(photo, current.rating, PhotoFlagStatus.pick);
                          setInnerState(() {});
                          if (mounted) setState(() {});
                        },
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: ChoiceChip(
                  label: const Center(child: Text('○ Neutre', style: TextStyle(fontSize: 11.5))),
                  selected: current.status == PhotoFlagStatus.neutral,
                  selectedColor: const Color(0xFFE2E8F0),
                  onSelected: widget.onUpdateRating == null
                      ? null
                      : (_) async {
                          await widget.onUpdateRating!(photo, current.rating, PhotoFlagStatus.neutral);
                          setInnerState(() {});
                          if (mounted) setState(() {});
                        },
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: ChoiceChip(
                  label: const Center(child: Text('✕ Rejetée', style: TextStyle(fontSize: 11.5))),
                  selected: current.status == PhotoFlagStatus.reject,
                  selectedColor: const Color(0xFFFEE2E2),
                  onSelected: widget.onUpdateRating == null
                      ? null
                      : (_) async {
                          await widget.onUpdateRating!(photo, current.rating, PhotoFlagStatus.reject);
                          setInnerState(() {});
                          if (mounted) setState(() {});
                        },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _openLightbox(BuildContext context, PhotoItem photo) {
    final isWide = MediaQuery.of(context).size.width >= 900;
    final photoAlbumNames = photo.albums
        .map((id) => widget.nodesById[id]?.name)
        .where((name) => name != null)
        .cast<String>()
        .toList();
    final sizeMo = (photo.fileSize / (1024 * 1024)).toStringAsFixed(1);
    final fileViewUrl = photo.getDriveViewUrl(widget.gdriveUrl);

    if (isWide) {
      showDialog(
        context: context,
        builder: (dialogCtx) => StatefulBuilder(
          builder: (_, setInnerState) => Dialog(
          backgroundColor: const Color(0xFFFFFFFF),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFEBDDC6)),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 920, maxHeight: 860),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          photo.filename,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        tooltip: "Agrandir en plein écran",
                        icon: const Icon(Icons.fullscreen, color: Color(0xFF0EA5E9)),
                        onPressed: () => _openFullScreenZoom(context, photo, fileViewUrl),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Color(0xFF475569)),
                        onPressed: () => Navigator.of(dialogCtx).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (photo.largePreviewUrl != null)
                    Flexible(
                      child: GestureDetector(
                        onTap: () {
                          if (photo.isVideo) {
                            _launchDriveUrl(context, fileViewUrl);
                          } else {
                            _openFullScreenZoom(context, photo, fileViewUrl);
                          }
                        },
                        child: MouseRegion(
                          cursor: SystemMouseCursors.zoomIn,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              constraints: const BoxConstraints(maxHeight: 520),
                              color: Colors.black45,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Image.network(
                                    photo.largePreviewUrl!,
                                    fit: BoxFit.contain,
                                    loadingBuilder: (ctx, child, progress) {
                                      if (progress == null) return child;
                                      return const Center(
                                        child: Padding(
                                          padding: EdgeInsets.all(32),
                                          child: CircularProgressIndicator(color: Color(0xFF0EA5E9)),
                                        ),
                                      );
                                    },
                                    errorBuilder: (ctx, err, stack) => const SizedBox.shrink(),
                                  ),
                                  if (photo.isVideo)
                                    Container(
                                      width: 56,
                                      height: 56,
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(alpha: 0.6),
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Color(0xFF94A3B8)),
                                      ),
                                      child: const Icon(Icons.play_arrow, color: Colors.white, size: 34),
                                    )
                                  else
                                    Positioned(
                                      bottom: 8,
                                      right: 8,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(alpha: 0.65),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.zoom_out_map, size: 13, color: Color(0xFF475569)),
                                            SizedBox(width: 4),
                                            Text("Cliquer pour agrandir", style: TextStyle(fontSize: 10, color: Color(0xFF475569))),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 16,
                    runSpacing: 6,
                    children: [
                      Text("Type : ${photo.isVideo ? 'Vidéo' : 'Photo'}",
                          style: TextStyle(fontSize: 12, color: photo.isVideo ? const Color(0xFFFBBF24) : const Color(0xFF0EA5E9), fontWeight: FontWeight.w600)),
                      Text("Date : ${photo.captureDate.isNotEmpty ? photo.captureDate : 'Non renseignée'}",
                          style: const TextStyle(fontSize: 12, color: Color(0xFF475569))),
                      Text("Taille : $sizeMo Mo (${photo.width} × ${photo.height} px)",
                          style: const TextStyle(fontSize: 12, color: Color(0xFF475569))),
                      if (photo.cameraModel != null && photo.cameraModel!.isNotEmpty)
                        Text("Appareil : ${photo.cameraModel}", style: const TextStyle(fontSize: 12, color: Color(0xFF475569))),
                      if (photo.country != null && photo.country!.isNotEmpty)
                        Text("Lieu : ${photo.city != null && photo.city!.isNotEmpty ? '${photo.city}, ' : ''}${photo.country}",
                            style: const TextStyle(fontSize: 12, color: Color(0xFF475569))),
                      if (photo.addedByName != null && photo.addedByName!.isNotEmpty)
                        Text("Ajouté par : ${photo.addedByName}",
                            style: const TextStyle(fontSize: 12, color: Color(0xFF0EA5E9), fontWeight: FontWeight.w600)),
                      Text("Statut Drive : ${photo.driveId != null ? '✔ Synchronisé en HD' : '⏳ Non chargé sur Drive'}",
                          style: TextStyle(fontSize: 12, color: photo.driveId != null ? const Color(0xFF4ADE80) : const Color(0xFFFBBF24))),
                    ],
                  ),
                  if ((widget.likesByPhotoId?[photo.id] ?? const []).isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(Icons.favorite, size: 15, color: Color(0xFFF43F5E)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            "Aimé par : ${(widget.likesByPhotoId![photo.id]!).map((l) => l.userName).join(', ')}",
                            style: const TextStyle(fontSize: 12, color: Color(0xFFFDA4AF), fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (!photo.isVideo && photoAlbumNames.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: photoAlbumNames
                          .map((name) => Chip(
                                label: Text(name, style: const TextStyle(fontSize: 11)),
                                backgroundColor: const Color(0xFFF6EFE2),
                                visualDensity: VisualDensity.compact,
                              ))
                          .toList(),
                    ),
                  ],
                  const SizedBox(height: 16),
                  const SizedBox(height: 12),
                  _buildRatingAndStatusBar(photo, setInnerState),
                  Row(
                    children: [
                      if (widget.onToggleLike != null) ...[
                        Builder(
                          builder: (_) {
                            final likes = widget.likesByPhotoId?[photo.id] ?? const <PhotoLikeRecord>[];
                            final isLiked = widget.currentUserEmail != null &&
                                likes.any((l) => l.userEmail == widget.currentUserEmail);
                            return OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: isLiked ? Colors.white : const Color(0xFFF43F5E),
                                backgroundColor: isLiked ? const Color(0xFFE11D48) : Colors.transparent,
                                side: const BorderSide(color: Color(0xFFF43F5E)),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: Icon(isLiked ? Icons.favorite : Icons.favorite_border, size: 17),
                              label: Text("J'aime (${likes.length})", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              onPressed: () async {
                                Navigator.of(dialogCtx).pop();
                                await widget.onToggleLike!(photo);
                              },
                            );
                          },
                        ),
                        const SizedBox(width: 10),
                      ],
                      if (widget.onAssignAlbum != null)
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF0EA5E9),
                              side: const BorderSide(color: Color(0xFFF97316)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: const Icon(Icons.create_new_folder_outlined, size: 17),
                            label: const Text("Ranger dans un album", style: TextStyle(fontSize: 12)),
                            onPressed: () {
                              Navigator.of(dialogCtx).pop();
                              _promptPickAlbumForPhoto(context, photo);
                            },
                          ),
                        ),
                      if (widget.onAssignAlbum != null && widget.onDeletePhoto != null)
                        const SizedBox(width: 10),
                      if (widget.onDeletePhoto != null)
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFF87171),
                            side: const BorderSide(color: Color(0xFFEF4444)),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.delete_outline, size: 17),
                          label: const Text("Corbeille", style: TextStyle(fontSize: 12)),
                          onPressed: () async {
                            Navigator.of(dialogCtx).pop();
                            await widget.onDeletePhoto!(photo);
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (widget.onSetAlbumCover != null && !photo.isVideo) ...[
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF0EA5E9),
                        side: const BorderSide(color: Color(0xFF0EA5E9)),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.photo_album_outlined, size: 17),
                      label: const Text("Mettre en couverture d'album", style: TextStyle(fontSize: 12.5)),
                      onPressed: () async {
                        Navigator.of(dialogCtx).pop();
                        await widget.onSetAlbumCover!(photo);
                      },
                    ),
                    const SizedBox(height: 10),
                  ],
                  Row(
                    children: [
                      if (!photo.isVideo && photo.largePreviewUrl != null) ...[
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF0EA5E9),
                              side: const BorderSide(color: Color(0xFF0EA5E9)),
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: const Icon(Icons.photo_size_select_large_rounded, size: 17),
                            label: const Text("Télécharger Light", style: TextStyle(fontSize: 12.5)),
                            onPressed: () => _launchDriveUrl(dialogCtx, photo.largePreviewUrl!),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF97316),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: Icon(photo.isVideo ? Icons.play_circle_outline : Icons.download_rounded, size: 18),
                          label: Text(
                            photo.isVideo
                                ? (photo.driveId != null ? "Lire la vidéo HD" : "Ouvrir Drive")
                                : "Télécharger la version HD originale",
                            style: const TextStyle(fontSize: 12.5),
                          ),
                          onPressed: () => _launchDriveUrl(
                            dialogCtx,
                            photo.driveId != null && !photo.isVideo
                                ? 'https://drive.google.com/uc?export=download&id=${photo.driveId}'
                                : fileViewUrl,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFFFFFFF),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (_, setSheetState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.78,
              maxChildSize: 0.95,
              minChildSize: 0.4,
              expand: false,
              builder: (context, scrollController) {
            return ListView(
              controller: scrollController,
              padding: const EdgeInsets.all(20),
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (photo.largePreviewUrl != null)
                  GestureDetector(
                    onTap: () {
                      if (photo.isVideo) {
                        _launchDriveUrl(sheetCtx, fileViewUrl);
                      } else {
                        _openFullScreenZoom(sheetCtx, photo, fileViewUrl);
                      }
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        constraints: const BoxConstraints(maxHeight: 360),
                        color: Colors.black38,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Image.network(
                              photo.largePreviewUrl!,
                              fit: BoxFit.contain,
                              loadingBuilder: (ctx, child, progress) {
                                if (progress == null) return child;
                                return const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(32),
                                    child: CircularProgressIndicator(color: Color(0xFF0EA5E9)),
                                  ),
                                );
                              },
                              errorBuilder: (ctx, err, stack) => const SizedBox.shrink(),
                            ),
                            if (photo.isVideo)
                              Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.6),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Color(0xFF94A3B8)),
                                ),
                                child: const Icon(Icons.play_arrow, color: Colors.white, size: 32),
                              )
                            else
                              Positioned(
                                bottom: 8,
                                right: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.65),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.zoom_out_map, size: 13, color: Color(0xFF475569)),
                                      SizedBox(width: 4),
                                      Text("Toucher pour agrandir", style: TextStyle(fontSize: 10, color: Color(0xFF475569))),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                Text(photo.filename, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text("Type : ${photo.isVideo ? 'Vidéo' : 'Photo'}",
                    style: TextStyle(fontSize: 12, color: photo.isVideo ? const Color(0xFFFBBF24) : const Color(0xFF0EA5E9), fontWeight: FontWeight.w600)),
                Text("Date : ${photo.captureDate.isNotEmpty ? photo.captureDate : 'Non renseignée'}",
                    style: const TextStyle(fontSize: 12, color: Color(0xFF475569))),
                Text("Taille : $sizeMo Mo (${photo.width} × ${photo.height} px)",
                    style: const TextStyle(fontSize: 12, color: Color(0xFF475569))),
                if (photo.cameraModel != null && photo.cameraModel!.isNotEmpty)
                  Text("Appareil : ${photo.cameraModel}", style: const TextStyle(fontSize: 12, color: Color(0xFF475569))),
                if (photo.country != null && photo.country!.isNotEmpty)
                  Text("Lieu : ${photo.city != null && photo.city!.isNotEmpty ? '${photo.city}, ' : ''}${photo.country}",
                      style: const TextStyle(fontSize: 12, color: Color(0xFF475569))),
                if (photo.addedByName != null && photo.addedByName!.isNotEmpty)
                  Text("Ajouté par : ${photo.addedByName}",
                      style: const TextStyle(fontSize: 12, color: Color(0xFF0EA5E9), fontWeight: FontWeight.w600)),
                Text("Statut Drive : ${photo.driveId != null ? '✔ Synchronisé en HD' : '⏳ Non chargé sur Drive'}",
                    style: TextStyle(fontSize: 12, color: photo.driveId != null ? const Color(0xFF4ADE80) : const Color(0xFFFBBF24))),
                if ((widget.likesByPhotoId?[photo.id] ?? const []).isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.favorite, size: 15, color: Color(0xFFF43F5E)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          "Aimé par : ${(widget.likesByPhotoId![photo.id]!).map((l) => l.userName).join(', ')}",
                          style: const TextStyle(fontSize: 12, color: Color(0xFFFDA4AF), fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                if (!photo.isVideo) ...[
                  const Text("Dossiers & Albums Lightroom :", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: photoAlbumNames.isEmpty
                        ? [const Text("Aucune thématique spécifique", style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Color(0xFF94A3B8)))]
                        : photoAlbumNames
                            .map((name) => Chip(
                                  label: Text(name, style: const TextStyle(fontSize: 10)),
                                  backgroundColor: const Color(0xFFF6EFE2),
                                  padding: EdgeInsets.zero,
                                ))
                            .toList(),
                  ),
                  const SizedBox(height: 16),
                ],
                _buildRatingAndStatusBar(photo, setSheetState),
                Row(
                  children: [
                    if (widget.onToggleLike != null) ...[
                      Builder(
                        builder: (_) {
                          final likes = widget.likesByPhotoId?[photo.id] ?? const <PhotoLikeRecord>[];
                          final isLiked = widget.currentUserEmail != null &&
                              likes.any((l) => l.userEmail == widget.currentUserEmail);
                          return OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: isLiked ? Colors.white : const Color(0xFFF43F5E),
                              backgroundColor: isLiked ? const Color(0xFFE11D48) : Colors.transparent,
                              side: const BorderSide(color: Color(0xFFF43F5E)),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: Icon(isLiked ? Icons.favorite : Icons.favorite_border, size: 17),
                            label: Text("(${likes.length})", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            onPressed: () async {
                              await widget.onToggleLike!(photo);
                              if (sheetCtx.mounted) setSheetState(() {});
                            },
                          );
                        },
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (widget.onAssignAlbum != null)
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF0EA5E9),
                            side: const BorderSide(color: Color(0xFFF97316)),
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.create_new_folder_outlined, size: 17),
                          label: const Text("Ranger dans un album", style: TextStyle(fontSize: 12)),
                          onPressed: () {
                            Navigator.of(context).pop();
                            _promptPickAlbumForPhoto(this.context, photo);
                          },
                        ),
                      ),
                    if (widget.onAssignAlbum != null && widget.onDeletePhoto != null)
                      const SizedBox(width: 8),
                    if (widget.onDeletePhoto != null)
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFF87171),
                          side: const BorderSide(color: Color(0xFFEF4444)),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.delete_outline, size: 17),
                        label: const Text("Corbeille", style: TextStyle(fontSize: 12)),
                        onPressed: () async {
                          Navigator.of(context).pop();
                          await widget.onDeletePhoto!(photo);
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                if (widget.onSetAlbumCover != null && !photo.isVideo) ...[
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF0EA5E9),
                      side: const BorderSide(color: Color(0xFF0EA5E9)),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.photo_album_outlined, size: 17),
                    label: const Text("Mettre en couverture d'album", style: TextStyle(fontSize: 12)),
                    onPressed: () async {
                      Navigator.of(context).pop();
                      await widget.onSetAlbumCover!(photo);
                    },
                  ),
                  const SizedBox(height: 8),
                ],
                Row(
                  children: [
                    if (!photo.isVideo && photo.largePreviewUrl != null) ...[
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF0EA5E9),
                            side: const BorderSide(color: Color(0xFF0EA5E9)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.photo_size_select_large_rounded, size: 16),
                          label: const Text("Télécharger Light", style: TextStyle(fontSize: 12)),
                          onPressed: () => _launchDriveUrl(sheetCtx, photo.largePreviewUrl!),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF97316),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: Icon(photo.isVideo ? Icons.play_circle_outline : Icons.download_rounded, size: 18),
                        label: Text(
                          photo.isVideo
                              ? (photo.driveId != null ? "Lire la vidéo HD" : "Ouvrir Drive")
                              : "Télécharger HD originale",
                          style: const TextStyle(fontSize: 12),
                        ),
                        onPressed: () => _launchDriveUrl(
                          sheetCtx,
                          photo.driveId != null && !photo.isVideo
                              ? 'https://drive.google.com/uc?export=download&id=${photo.driveId}'
                              : fileViewUrl,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        );
          },
        );
      },
    );
  }

  void _promptPickAlbumForPhoto(BuildContext context, PhotoItem photo) {
    if (widget.onAssignAlbum == null) return;
    final albumsSorted = widget.nodesById.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    String? selectedAlbumId = albumsSorted.isNotEmpty ? albumsSorted.first.id : null;

    showDialog<void>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFFFFFFFF),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFEBDDC6)),
          ),
          title: const Text(
            "Ranger dans un album / dossier",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B)),
          ),
          content: SizedBox(
            width: 380,
            child: DropdownButtonFormField<String>(
              value: selectedAlbumId,
              isExpanded: true,
              dropdownColor: const Color(0xFFF6EFE2),
              decoration: InputDecoration(
                labelText: "Choisir l'album ou dossier",
                filled: true,
                fillColor: const Color(0xFFF6EFE2),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              items: albumsSorted
                  .map(
                    (a) => DropdownMenuItem<String>(
                      value: a.id,
                      child: Text(
                        "${a.isFolder ? '📁' : '🖼️'} ${a.name}",
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (val) => setDialogState(() => selectedAlbumId = val),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text("Annuler", style: TextStyle(color: Color(0xFF64748B))),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF97316),
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.check, size: 18),
              label: const Text("Valider"),
              onPressed: () async {
                Navigator.of(dialogCtx).pop();
                if (selectedAlbumId != null) {
                  await widget.onAssignAlbum!(photo, selectedAlbumId!);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoGridTile extends StatefulWidget {
  final PhotoItem photo;
  final int likeCount;
  final bool isLikedByMe;
  final int rating;
  final PhotoFlagStatus flagStatus;
  final bool isSelectionMode;
  final bool isSelected;
  final VoidCallback? onLongPress;
  final VoidCallback? onToggleLike;
  final VoidCallback onTap;

  const _PhotoGridTile({
    super.key,
    required this.photo,
    this.likeCount = 0,
    this.isLikedByMe = false,
    this.rating = 0,
    this.flagStatus = PhotoFlagStatus.neutral,
    this.isSelectionMode = false,
    this.isSelected = false,
    this.onLongPress,
    this.onToggleLike,
    required this.onTap,
  });

  @override
  State<_PhotoGridTile> createState() => _PhotoGridTileState();
}

class _PhotoGridTileState extends State<_PhotoGridTile> {
  int _retryAttempt = 0;
  static const int _maxRetries = 3;
  bool _isHovered = false;

  String? get _effectiveThumbUrl {
    final base = widget.photo.thumbnailUrl;
    if (base == null) return null;
    if (_retryAttempt == 0) return base;
    return '$base?retry=$_retryAttempt';
  }

  void _scheduleRetry() {
    if (_retryAttempt >= _maxRetries) return;
    final nextAttempt = _retryAttempt + 1;
    final delayMs = 600 * nextAttempt + (widget.photo.id % 5) * 150;
    Future<void>.delayed(Duration(milliseconds: delayMs), () {
      if (mounted && _retryAttempt < nextAttempt) {
        setState(() {
          _retryAttempt = nextAttempt;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final photo = widget.photo;
    final thumbUrl = _effectiveThumbUrl;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          decoration: BoxDecoration(
            color: const Color(0xFFF6EFE2),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: widget.isSelected
                  ? const Color(0xFF0EA5E9)
                  : (_isHovered ? const Color(0xFF0EA5E9).withValues(alpha: 0.6) : Color(0xFFF1E6D2)),
              width: widget.isSelected ? 2.5 : (_isHovered ? 1.5 : 1.0),
            ),
            boxShadow: _isHovered
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (thumbUrl != null)
                Image.network(
                  thumbUrl,
                  key: ValueKey(thumbUrl),
                  fit: BoxFit.cover,
                  cacheWidth: 360,
                  frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                    if (wasSynchronouslyLoaded) return child;
                    return AnimatedOpacity(
                      opacity: frame == null ? 0 : 1,
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOut,
                      child: child,
                    );
                  },
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      color: const Color(0xFFF6EFE2),
                      child: const Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0EA5E9)),
                        ),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    if (_retryAttempt < _maxRetries) {
                      _scheduleRetry();
                      return Container(
                        color: const Color(0xFFF6EFE2),
                        child: const Center(
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 1.5, color: Color(0xFFCBD5E1)),
                          ),
                        ),
                      );
                    }
                    return Center(
                      child: Icon(
                        photo.isVideo ? Icons.movie_outlined : Icons.image_outlined,
                        color: Color(0xFFCBD5E1),
                        size: 28,
                      ),
                    );
                  },
                )
              else
                Center(
                  child: Icon(
                    photo.isVideo ? Icons.movie_outlined : Icons.cloud_upload_outlined,
                    color: Color(0xFFCBD5E1),
                    size: 28,
                  ),
                ),
              if (photo.isVideo)
                Positioned(
                  bottom: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.78),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Color(0xFFCBD5E1)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.play_arrow, size: 11, color: const Color(0xFF1E293B)),
                        SizedBox(width: 2),
                        Text("Vidéo", style: TextStyle(fontSize: 9, color: const Color(0xFF1E293B), fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              if (widget.flagStatus != PhotoFlagStatus.neutral)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      widget.flagStatus == PhotoFlagStatus.pick ? Icons.check_circle : Icons.cancel,
                      size: 16,
                      color: widget.flagStatus == PhotoFlagStatus.pick
                          ? const Color(0xFF10B981)
                          : const Color(0xFFEF4444),
                    ),
                  ),
                ),
              if (widget.rating > 0)
                Positioned(
                  bottom: 6,
                  left: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.68),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '★' * widget.rating,
                      style: const TextStyle(
                        fontSize: 9.5,
                        color: Color(0xFFFBBF24),
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              if (widget.isSelectionMode)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Container(
                      color: widget.isSelected
                          ? const Color(0xFF0EA5E9).withValues(alpha: 0.25)
                          : Colors.black.withValues(alpha: 0.15),
                    ),
                  ),
                ),
              if (widget.isSelectionMode)
                Positioned(
                  top: 6,
                  left: 6,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      widget.isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                      size: 22,
                      color: widget.isSelected ? const Color(0xFF0EA5E9) : Color(0xFF475569),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class PhotoSearchScreen extends StatefulWidget {
  final List<PhotoItem> allPhotos;
  final Map<String, AlbumNode> nodesById;
  final String gdriveUrl;
  final Map<int, List<PhotoLikeRecord>>? likesByPhotoId;
  final Map<int, PhotoRatingRecord>? ratingsByPhotoId;
  final String? currentUserEmail;
  final Future<void> Function(PhotoItem photo)? onToggleLike;
  final Future<void> Function(PhotoItem photo, int rating, PhotoFlagStatus status)? onUpdateRating;
  final Future<void> Function(PhotoItem photo, String albumId)? onAssignAlbum;
  final Future<void> Function(PhotoItem photo)? onDeletePhoto;

  const PhotoSearchScreen({
    super.key,
    required this.allPhotos,
    required this.nodesById,
    required this.gdriveUrl,
    this.likesByPhotoId,
    this.ratingsByPhotoId,
    this.currentUserEmail,
    this.onToggleLike,
    this.onUpdateRating,
    this.onAssignAlbum,
    this.onDeletePhoto,
  });

  @override
  State<PhotoSearchScreen> createState() => _PhotoSearchScreenState();
}

class _PhotoSearchScreenState extends State<PhotoSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<PhotoItem> _results = [];
  String _query = '';

  void _onSearch(String query) {
    setState(() {
      _query = query.trim().toLowerCase();
      if (_query.isEmpty) {
        _results = [];
      } else {
        _results = widget.allPhotos.where((p) {
          final fnMatch = p.filename.toLowerCase().contains(_query);
          final yearMatch = p.year.toLowerCase().contains(_query);
          final albumMatch = p.albums.any((id) {
            final node = widget.nodesById[id];
            return node != null && node.name.toLowerCase().contains(_query);
          });
          return fnMatch || yearMatch || albumMatch;
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: "Rechercher par nom, année, album...",
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _query.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        _onSearch('');
                      },
                    )
                  : null,
              filled: true,
              fillColor: const Color(0xFFF6EFE2),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
            onChanged: _onSearch,
          ),
        ),
        Expanded(
          child: _query.isNotEmpty && _results.isEmpty
              ? const Center(
                  child: Text("Aucun résultat", style: TextStyle(color: Color(0xFF94A3B8))),
                )
              : PhotoGridBody(
                  photos: _query.isEmpty ? widget.allPhotos : _results,
                  nodesById: widget.nodesById,
                  gdriveUrl: widget.gdriveUrl,
                  likesByPhotoId: widget.likesByPhotoId,
                  ratingsByPhotoId: widget.ratingsByPhotoId,
                  currentUserEmail: widget.currentUserEmail,
                  onToggleLike: widget.onToggleLike,
                  onUpdateRating: widget.onUpdateRating,
                  onAssignAlbum: widget.onAssignAlbum,
                  onDeletePhoto: widget.onDeletePhoto,
                ),
        ),
      ],
    );
  }
}
class _FullScreenPhotoViewer extends StatefulWidget {
  final List<PhotoItem> photos;
  final int initialIndex;
  final String defaultGdriveUrl;
  final Future<void> Function(BuildContext context, String url) onLaunchDrive;
  final Map<int, List<PhotoLikeRecord>>? likesByPhotoId;
  final Map<int, PhotoRatingRecord>? ratingsByPhotoId;
  final String? currentUserEmail;
  final Future<void> Function(PhotoItem photo)? onToggleLike;
  final Future<void> Function(PhotoItem photo, int rating, PhotoFlagStatus status)? onUpdateRating;

  const _FullScreenPhotoViewer({
    required this.photos,
    required this.initialIndex,
    required this.defaultGdriveUrl,
    required this.onLaunchDrive,
    this.likesByPhotoId,
    this.ratingsByPhotoId,
    this.currentUserEmail,
    this.onToggleLike,
    this.onUpdateRating,
  });

  @override
  State<_FullScreenPhotoViewer> createState() => _FullScreenPhotoViewerState();
}

class _FullScreenPhotoViewerState extends State<_FullScreenPhotoViewer> {
  late final PageController _pageController;
  late int _currentIndex;
  bool _isCurrentZoomed = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentPhoto = widget.photos[_currentIndex];
    final driveUrl = currentPhoto.getDriveViewUrl(widget.defaultGdriveUrl);

    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: 0.96),
      appBar: AppBar(
        backgroundColor: Colors.black54,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              currentPhoto.filename,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              '${_currentIndex + 1} / ${widget.photos.length}',
              style: const TextStyle(fontSize: 11, color: Colors.white54),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: const Color(0xFF22D3EE)),
            onPressed: () => widget.onLaunchDrive(context, driveUrl),
            icon: const Icon(Icons.open_in_new, size: 17),
            label: const Text('Drive', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            controller: _pageController,
            physics: _isCurrentZoomed
                ? const NeverScrollableScrollPhysics()
                : const PageScrollPhysics(),
            itemCount: widget.photos.length,
            onPageChanged: (idx) {
              setState(() {
                _currentIndex = idx;
                _isCurrentZoomed = false;
              });
            },
            itemBuilder: (_, idx) {
              final p = widget.photos[idx];
              final url = p.largePreviewUrl ?? p.thumbnailUrl ?? '';
              return _ZoomablePhotoPage(
                key: ValueKey(p.id),
                imageUrl: url,
                onZoomChanged: (zoomed) {
                  if (idx == _currentIndex && zoomed != _isCurrentZoomed) {
                    setState(() => _isCurrentZoomed = zoomed);
                  }
                },
              );
            },
          ),
          if (widget.photos.length > 1 && _currentIndex > 0)
            Positioned(
              left: 10,
              top: 0,
              bottom: 0,
              child: Center(
                child: CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.black.withValues(alpha: 0.55),
                  child: IconButton(
                    icon: const Icon(Icons.chevron_left, color: Colors.white),
                    onPressed: () => _pageController.previousPage(
                      duration: const Duration(milliseconds: 240),
                      curve: Curves.easeOut,
                    ),
                  ),
                ),
              ),
            ),
          if (widget.photos.length > 1 && _currentIndex < widget.photos.length - 1)
            Positioned(
              right: 10,
              top: 0,
              bottom: 0,
              child: Center(
                child: CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.black.withValues(alpha: 0.55),
                  child: IconButton(
                    icon: const Icon(Icons.chevron_right, color: Colors.white),
                    onPressed: () => _pageController.nextPage(
                      duration: const Duration(milliseconds: 240),
                      curve: Curves.easeOut,
                    ),
                  ),
                ),
              ),
            ),
          Positioned(
            bottom: 12,
            left: 12,
            right: 12,
            child: SafeArea(
              top: false,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.72),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Builder(
                    builder: (_) {
                      final likes = widget.likesByPhotoId?[currentPhoto.id] ?? const <PhotoLikeRecord>[];
                      final isLiked = widget.currentUserEmail != null &&
                          likes.any((l) => l.userEmail == widget.currentUserEmail);
                      final rateRec = widget.ratingsByPhotoId?[currentPhoto.id] ?? const PhotoRatingRecord();
                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (widget.onToggleLike != null) ...[
                              InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () async {
                                  await widget.onToggleLike!(currentPhoto);
                                  if (mounted) setState(() {});
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                  child: Row(
                                    children: [
                                      Icon(
                                        isLiked ? Icons.favorite : Icons.favorite_border,
                                        color: isLiked ? const Color(0xFFF43F5E) : Colors.white70,
                                        size: 20,
                                      ),
                                      if (likes.isNotEmpty) ...[
                                        const SizedBox(width: 4),
                                        Text('${likes.length}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            for (int star = 1; star <= 5; star++)
                              InkWell(
                                onTap: widget.onUpdateRating == null
                                    ? null
                                    : () async {
                                        final next = rateRec.rating == star ? 0 : star;
                                        await widget.onUpdateRating!(currentPhoto, next, rateRec.status);
                                        if (mounted) setState(() {});
                                      },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                                  child: Icon(
                                    star <= rateRec.rating ? Icons.star_rounded : Icons.star_border_rounded,
                                    color: star <= rateRec.rating ? const Color(0xFFFBBF24) : Colors.white54,
                                    size: 22,
                                  ),
                                ),
                              ),
                            const SizedBox(width: 8),
                            IconButton(
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              tooltip: 'Validée',
                              icon: Icon(
                                Icons.check_circle,
                                size: 20,
                                color: rateRec.status == PhotoFlagStatus.pick ? const Color(0xFF10B981) : Colors.white54,
                              ),
                              onPressed: widget.onUpdateRating == null
                                  ? null
                                  : () async {
                                      final next = rateRec.status == PhotoFlagStatus.pick
                                          ? PhotoFlagStatus.neutral
                                          : PhotoFlagStatus.pick;
                                      await widget.onUpdateRating!(currentPhoto, rateRec.rating, next);
                                      if (mounted) setState(() {});
                                    },
                            ),
                            const SizedBox(width: 6),
                            IconButton(
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              tooltip: 'Rejetée',
                              icon: Icon(
                                Icons.cancel,
                                size: 20,
                                color: rateRec.status == PhotoFlagStatus.reject ? const Color(0xFFEF4444) : Colors.white54,
                              ),
                              onPressed: widget.onUpdateRating == null
                                  ? null
                                  : () async {
                                      final next = rateRec.status == PhotoFlagStatus.reject
                                          ? PhotoFlagStatus.neutral
                                          : PhotoFlagStatus.reject;
                                      await widget.onUpdateRating!(currentPhoto, rateRec.rating, next);
                                      if (mounted) setState(() {});
                                    },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ZoomablePhotoPage extends StatefulWidget {
  final String imageUrl;
  final ValueChanged<bool> onZoomChanged;

  const _ZoomablePhotoPage({
    super.key,
    required this.imageUrl,
    required this.onZoomChanged,
  });

  @override
  State<_ZoomablePhotoPage> createState() => _ZoomablePhotoPageState();
}

class _ZoomablePhotoPageState extends State<_ZoomablePhotoPage> {
  final TransformationController _ctrl = TransformationController();
  Offset? _doubleTapLocalPos;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_handleTransform);
  }

  void _handleTransform() {
    final zoomed = _ctrl.value.getMaxScaleOnAxis() > 1.05;
    widget.onZoomChanged(zoomed);
  }

  void _handleDoubleTap() {
    final currentScale = _ctrl.value.getMaxScaleOnAxis();
    if (currentScale > 1.15) {
      _ctrl.value = Matrix4.identity();
      return;
    }
    const double targetScale = 2.8;
    final pos = _doubleTapLocalPos;
    if (pos != null) {
      final dx = -pos.dx * (targetScale - 1);
      final dy = -pos.dy * (targetScale - 1);
      _ctrl.value = Matrix4.identity()
        ..translate(dx, dy)
        ..scale(targetScale);
    } else {
      _ctrl.value = Matrix4.identity()..scale(targetScale);
    }
  }

  @override
  void dispose() {
    _ctrl.removeListener(_handleTransform);
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTapDown: (details) => _doubleTapLocalPos = details.localPosition,
      onDoubleTap: _handleDoubleTap,
      child: InteractiveViewer(
        transformationController: _ctrl,
        minScale: 1.0,
        maxScale: 5.0,
        child: Center(
          child: Image.network(
            widget.imageUrl,
            fit: BoxFit.contain,
            loadingBuilder: (ctx, child, progress) {
              if (progress == null) return child;
              return const Center(
                child: CircularProgressIndicator(color: Color(0xFF22D3EE)),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ActiveTripScreen extends StatefulWidget {
  final ActiveTripConfig trip;
  final List<PhotoItem> Function() getTripMedia;
  final String currentUserName;
  final String? currentUserEmail;
  final String gdriveUrl;
  final Future<void> Function(List<PlatformFile> files, void Function(int done, int total) onProgress)
      onUploadSelectedFiles;
  final Future<void> Function() onAddViaLink;
  final Future<void> Function() onTerminateTrip;
  final Future<void> Function(List<PhotoItem> photos) onBulkDeleteTripPhotos;
  final void Function(PhotoItem photo, List<PhotoItem> allTripMedia) onOpenPhoto;

  const _ActiveTripScreen({
    required this.trip,
    required this.getTripMedia,
    required this.currentUserName,
    this.currentUserEmail,
    required this.gdriveUrl,
    required this.onUploadSelectedFiles,
    required this.onAddViaLink,
    required this.onTerminateTrip,
    required this.onBulkDeleteTripPhotos,
    required this.onOpenPhoto,
  });

  @override
  State<_ActiveTripScreen> createState() => _ActiveTripScreenState();
}

class _ActiveTripScreenState extends State<_ActiveTripScreen> {
  bool _isUploading = false;
  int _uploadDone = 0;
  int _uploadTotal = 0;
  bool _isSelectionMode = false;
  final Set<int> _selectedIds = {};

  Future<bool> _confirmWifiBeforeUpload() async {
    try {
      final results = await Connectivity().checkConnectivity();
      final hasWifi = results.contains(ConnectivityResult.wifi) ||
          results.contains(ConnectivityResult.ethernet);
      if (hasWifi) return true;
      if (!mounted) return false;
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Row(
            children: [
              Icon(Icons.wifi_off_rounded, color: Color(0xFFF97316)),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Protection Wi-Fi',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                ),
              ),
            ],
          ),
          content: const Text(
            'Vous n\'êtes pas connecté en Wi-Fi (données mobiles ou réseau non vérifié).\n'
            'L\'envoi de photos vers Google Drive peut consommer votre forfait mobile.\n\n'
            'Voulez-vous envoyer quand même ?',
            style: TextStyle(fontSize: 13, color: Color(0xFF475569)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Attendre le Wi-Fi'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFFF97316)),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Envoyer quand même'),
            ),
          ],
        ),
      );
      return proceed == true;
    } catch (_) {
      return true;
    }
  }

  Future<void> _pickAndUpload() async {
    final okWifi = await _confirmWifiBeforeUpload();
    if (!okWifi || !mounted) return;

    final picked = await FilePicker.platform.pickFiles(
      type: FileType.media,
      allowMultiple: true,
      withData: true,
    );
    if (picked == null || picked.files.isEmpty || !mounted) return;

    setState(() {
      _isUploading = true;
      _uploadDone = 0;
      _uploadTotal = picked.files.length;
    });

    try {
      await widget.onUploadSelectedFiles(picked.files, (done, total) {
        if (mounted) {
          setState(() {
            _uploadDone = done;
            _uploadTotal = total;
          });
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF1E293B),
            content: Text(
              '✔ ${picked.files.length} média(s) envoyé(s) sur Drive et partagé(s) !',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF1E293B),
            content: Text(
              'Erreur envoi Drive : $e',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _downloadAllPhotos(List<PhotoItem> media) async {
    final withDrive = media.where((m) => m.driveId != null).toList();
    if (withDrive.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFF1E293B),
          content: Text('Aucune photo Google Drive à télécharger.', style: TextStyle(color: Colors.white)),
        ),
      );
      return;
    }
    for (final m in withDrive) {
      final url = Uri.parse('https://drive.google.com/uc?export=download&id=${m.driveId}');
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _confirmTerminateTrip() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          'Terminer et supprimer le voyage ?',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
        ),
        content: const Text(
          'Une fois les vacances terminées, vous pouvez supprimer cet album collaboratif afin de pouvoir créer un prochain voyage en cours.\n\n(Pensez à télécharger les photos avant si besoin.)',
          style: TextStyle(fontSize: 13, color: Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            onPressed: () => Navigator.of(ctx).pop(true),
            icon: const Icon(Icons.delete_outline, size: 17),
            label: const Text('Supprimer le voyage'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await widget.onTerminateTrip();
      if (mounted) Navigator.of(context).pop();
    }
  }

  String _dayKey(PhotoItem p) {
    if (p.dateFolder.isNotEmpty && p.dateFolder.length >= 10) {
      return p.dateFolder.substring(0, 10);
    }
    if (p.captureDate.isNotEmpty && p.captureDate.length >= 10) {
      return p.captureDate.substring(0, 10);
    }
    return 'Autres';
  }

  String _formatDayTitle(String key, DateTime? tripStart) {
    final dt = DateTime.tryParse(key);
    if (dt == null) return key;
    final dd = dt.day.toString().padLeft(2, '0');
    final mm = dt.month.toString().padLeft(2, '0');
    if (tripStart != null) {
      final dayNum = dt.difference(tripStart).inDays + 1;
      if (dayNum >= 1 && dayNum <= 60) {
        return 'Jour $dayNum · $dd/$mm/${dt.year}';
      }
    }
    return '$dd/$mm/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final media = widget.getTripMedia();
    final tripStart = DateTime.tryParse(widget.trip.startDate);
    final Map<String, List<PhotoItem>> byDay = {};
    for (final m in media) {
      byDay.putIfAbsent(_dayKey(m), () => []).add(m);
    }
    final dayKeys = byDay.keys.toList()..sort((a, b) => a.compareTo(b));

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.trip.countryFlag} ${widget.trip.title}',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
            ),
            Text(
              '${widget.trip.countryName} · ${widget.trip.startDate} → ${widget.trip.endDate}',
              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
            ),
          ],
        ),
        actions: [
          if (media.isNotEmpty)
            IconButton(
              tooltip: _isSelectionMode ? 'Annuler la sélection' : 'Sélection multiple',
              icon: Icon(
                _isSelectionMode ? Icons.close : Icons.checklist_rounded,
                color: const Color(0xFFF97316),
              ),
              onPressed: () => setState(() {
                _isSelectionMode = !_isSelectionMode;
                if (!_isSelectionMode) _selectedIds.clear();
              }),
            ),
          IconButton(
            tooltip: 'Télécharger toutes les photos',
            icon: const Icon(Icons.download_rounded, color: Color(0xFF0EA5E9)),
            onPressed: () => _downloadAllPhotos(media),
          ),
          IconButton(
            tooltip: 'Terminer / supprimer ce voyage',
            icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444)),
            onPressed: _confirmTerminateTrip,
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isUploading)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: const Color(0xFFE0F7FA),
              child: Row(
                children: [
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0EA5E9)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Envoi vers Google Drive : $_uploadDone / $_uploadTotal...',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0369A1)),
                    ),
                  ),
                ],
              ),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFFFFF7E8),
              border: Border(bottom: BorderSide(color: Color(0xFFF1E6D2))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                    ),
                    onPressed: _isUploading ? null : _pickAndUpload,
                    icon: const Icon(Icons.wifi_tethering_rounded, size: 18),
                    label: const Text('Envoyer photos (Wi-Fi)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () async {
                    await widget.onAddViaLink();
                    if (mounted) setState(() {});
                  },
                  icon: const Icon(Icons.link, size: 17),
                  label: const Text('Lien Drive', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
          Expanded(
            child: media.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.beach_access_rounded, size: 48, color: Color(0xFFF97316)),
                          const SizedBox(height: 12),
                          Text(
                            'Bienvenue en ${widget.trip.countryName} ${widget.trip.countryFlag}',
                            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Sélectionnez des photos depuis votre téléphone ou PC (avec vérification Wi-Fi) pour alimenter l\'album jour par jour.',
                            style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(14),
                    itemCount: dayKeys.length,
                    itemBuilder: (_, idx) {
                      final key = dayKeys[idx];
                      final dayItems = byDay[key]!;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF97316).withValues(alpha: 0.14),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    _formatDayTitle(key, tripStart),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFFEA580C),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${dayItems.length} souvenir(s)',
                                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          ),
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 175,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                              childAspectRatio: 0.85,
                            ),
                            itemCount: dayItems.length,
                            itemBuilder: (_, pIdx) {
                              final p = dayItems[pIdx];
                              final thumb = p.thumbnailUrl;
                              final isSel = _selectedIds.contains(p.id);
                              return InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onLongPress: () {
                                  setState(() {
                                    _isSelectionMode = true;
                                    if (isSel) {
                                      _selectedIds.remove(p.id);
                                    } else {
                                      _selectedIds.add(p.id);
                                    }
                                  });
                                },
                                onTap: () {
                                  if (_isSelectionMode) {
                                    setState(() {
                                      if (isSel) {
                                        _selectedIds.remove(p.id);
                                        if (_selectedIds.isEmpty) _isSelectionMode = false;
                                      } else {
                                        _selectedIds.add(p.id);
                                      }
                                    });
                                  } else {
                                    widget.onOpenPhoto(p, media);
                                  }
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSel ? const Color(0xFF0EA5E9) : const Color(0xFFEBDDC6),
                                      width: isSel ? 2.5 : 1.0,
                                    ),
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      Expanded(
                                        child: Stack(
                                          fit: StackFit.expand,
                                          children: [
                                            thumb != null
                                                ? Image.network(thumb, fit: BoxFit.cover)
                                                : const Center(child: Icon(Icons.photo, color: Color(0xFF94A3B8))),
                                            if (_isSelectionMode)
                                              Positioned(
                                                top: 6,
                                                left: 6,
                                                child: Container(
                                                  decoration: BoxDecoration(
                                                    color: Colors.black.withValues(alpha: 0.65),
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: Icon(
                                                    isSel ? Icons.check_circle : Icons.radio_button_unchecked,
                                                    size: 20,
                                                    color: isSel ? const Color(0xFF0EA5E9) : Colors.white,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.person_outline, size: 12, color: Color(0xFF0EA5E9)),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                p.addedByName ?? 'Famille',
                                                style: const TextStyle(
                                                  fontSize: 10.5,
                                                  fontWeight: FontWeight.w600,
                                                  color: Color(0xFF475569),
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 12),
                        ],
                      );
                    },
                  ),
          ),
          if (_isSelectionMode && _selectedIds.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFEBDDC6))),
              ),
              child: SafeArea(
                top: false,
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
                    onPressed: () async {
                      final toDelete = media.where((m) => _selectedIds.contains(m.id)).toList();
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          backgroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                          title: Text(
                            'Supprimer ${toDelete.length} photo(s) ?',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                          ),
                          content: const Text(
                            'Elles seront retirées de l\'album de voyage (les originaux restent conservés sur Google Drive).',
                            style: TextStyle(fontSize: 13, color: Color(0xFF475569)),
                          ),
                          actions: [
                            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Annuler')),
                            FilledButton(
                              style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
                              onPressed: () => Navigator.of(ctx).pop(true),
                              child: const Text('Supprimer'),
                            ),
                          ],
                        ),
                      );
                      if (ok == true) {
                        await widget.onBulkDeleteTripPhotos(toDelete);
                        if (mounted) {
                          setState(() {
                            _isSelectionMode = false;
                            _selectedIds.clear();
                          });
                        }
                      }
                    },
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: Text('Supprimer (${_selectedIds.length})'),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TrashScreen extends StatefulWidget {
  final List<PhotoItem> Function() getTrashedPhotos;
  final Map<int, DateTime> trashedAtByPhotoId;
  final Future<void> Function(PhotoItem photo) onRestore;
  final Future<void> Function(List<PhotoItem> photos) onEmptyOrDeletePermanent;

  const _TrashScreen({
    required this.getTrashedPhotos,
    required this.trashedAtByPhotoId,
    required this.onRestore,
    required this.onEmptyOrDeletePermanent,
  });

  @override
  State<_TrashScreen> createState() => _TrashScreenState();
}

class _TrashScreenState extends State<_TrashScreen> {
  bool _isPurging = false;

  int _daysRemaining(int photoId) {
    final dt = widget.trashedAtByPhotoId[photoId];
    if (dt == null) return 30;
    final elapsed = DateTime.now().difference(dt).inDays;
    return (30 - elapsed).clamp(0, 30);
  }

  Future<void> _confirmEmptyTrash(List<PhotoItem> items) async {
    if (items.isEmpty) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          'Vider la corbeille ?',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
        ),
        content: Text(
          '${items.length} média(s) seront supprimés définitivement de l\'application ET de Google Drive.\n\nCette action est irréversible.',
          style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Annuler')),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            onPressed: () => Navigator.of(ctx).pop(true),
            icon: const Icon(Icons.delete_forever_rounded, size: 18),
            label: const Text('Tout supprimer'),
          ),
        ],
      ),
    );
    if (ok == true) {
      setState(() => _isPurging = true);
      await widget.onEmptyOrDeletePermanent(List<PhotoItem>.from(items));
      if (mounted) {
        setState(() => _isPurging = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFF1E293B),
            content: Text('✔ Corbeille vidée (app + Google Drive).', style: TextStyle(color: Colors.white)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.getTrashedPhotos();
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Corbeille (30 jours)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
            Text('${items.length} élément(s)', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          ],
        ),
        actions: [
          if (items.isNotEmpty)
            TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: const Color(0xFFEF4444)),
              onPressed: _isPurging ? null : () => _confirmEmptyTrash(items),
              icon: const Icon(Icons.delete_forever_rounded, size: 18),
              label: const Text('Vider', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            color: const Color(0xFFFFF7E8),
            child: const Row(
              children: [
                Icon(Icons.schedule_rounded, size: 16, color: Color(0xFFF97316)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Conservés 30 jours, puis supprimés automatiquement de l\'app et de Google Drive à l\'ouverture.',
                    style: TextStyle(fontSize: 11.5, color: Color(0xFF475569)),
                  ),
                ),
              ],
            ),
          ),
          if (_isPurging) const LinearProgressIndicator(color: Color(0xFFEF4444)),
          Expanded(
            child: items.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.delete_outline_rounded, size: 48, color: Color(0xFFCBD5E1)),
                        SizedBox(height: 10),
                        Text('La corbeille est vide', style: TextStyle(color: Color(0xFF64748B))),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, idx) {
                      final p = items[idx];
                      final days = _daysRemaining(p.id);
                      final thumb = p.thumbnailUrl;
                      return Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFEBDDC6)),
                        ),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                width: 56,
                                height: 56,
                                color: const Color(0xFFF6EFE2),
                                child: thumb != null
                                    ? Image.network(thumb, fit: BoxFit.cover)
                                    : const Icon(Icons.photo, color: Color(0xFF94A3B8)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    p.filename,
                                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 3),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: days <= 5 ? const Color(0xFFFEE2E2) : const Color(0xFFF6EFE2),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'J-$days avant suppression définitive',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w600,
                                        color: days <= 5 ? const Color(0xFFDC2626) : const Color(0xFF64748B),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'Restaurer',
                              icon: const Icon(Icons.restore_from_trash_rounded, color: Color(0xFF10B981)),
                              onPressed: () async {
                                await widget.onRestore(p);
                                if (mounted) setState(() {});
                              },
                            ),
                            IconButton(
                              tooltip: 'Supprimer définitivement (App + Drive)',
                              icon: const Icon(Icons.delete_forever_rounded, color: Color(0xFFEF4444)),
                              onPressed: _isPurging
                                  ? null
                                  : () async {
                                      setState(() => _isPurging = true);
                                      await widget.onEmptyOrDeletePermanent([p]);
                                      if (mounted) setState(() => _isPurging = false);
                                    },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
