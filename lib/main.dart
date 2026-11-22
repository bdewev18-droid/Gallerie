import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'services/app_update_service.dart';
import 'services/cloud_sync_service.dart';
import 'widgets/world_map_tab.dart';

const int appBuildNumber = 11;
const String appVersionLabel = "1.0.10";

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
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0284C7),
          brightness: Brightness.dark,
          surface: const Color(0xFF0F172A),
        ),
        scaffoldBackgroundColor: const Color(0xFF090D16),
      ),
      home: const HomeScreen(),
    );
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
  final String? createdByName;

  AlbumNode({
    required this.id,
    required this.name,
    this.parentId,
    required this.isFolder,
    required this.directCount,
    required this.totalCount,
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
  int _currentIndex = 0; // For Photos: 0 = La carte, 1 = Galerie, 2 = Thématiques, 3 = Années, 4 = Recherche
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppUpdateService.checkAndPrompt(context);
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
            backgroundColor: const Color(0xFF0F172A),
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
          backgroundColor: const Color(0xFF0F172A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: Colors.white12),
          ),
          title: const Text('Connexion Google impossible', style: TextStyle(color: Colors.white, fontSize: 16)),
          content: SingleChildScrollView(
            child: Text('$error', style: const TextStyle(color: Colors.white70, fontSize: 12)),
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
        backgroundColor: Color(0xFF0F172A),
        content: Text('Déconnecté.', style: TextStyle(color: Colors.white, fontSize: 12)),
      ),
    );
  }

  void _showUserAccountSheet() {
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Colors.white12),
        ),
        title: Row(
          children: [
            Icon(
              _auth.isSignedIn ? Icons.verified_user_outlined : Icons.account_circle_outlined,
              color: _auth.isSignedIn ? const Color(0xFF4ADE80) : const Color(0xFF38BDF8),
              size: 24,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _auth.isSignedIn ? 'Compte connecté' : 'Connexion Google Famille',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
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
                        backgroundColor: const Color(0xFF0284C7),
                        backgroundImage:
                            (_auth.avatarUrl != null && _auth.avatarUrl!.isNotEmpty) ? NetworkImage(_auth.avatarUrl!) : null,
                        child: (_auth.avatarUrl == null || _auth.avatarUrl!.isEmpty)
                            ? Text(
                                _auth.shortLabel.substring(0, 1).toUpperCase(),
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
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
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            Text(
                              _auth.email ?? '',
                              style: const TextStyle(fontSize: 12, color: Colors.white70),
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
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Vos "J\'aime" (❤️), nouveaux dossiers et ajouts de photos sont automatiquement associés à votre prénom pour toute la famille.',
                      style: TextStyle(fontSize: 11, color: Colors.white70),
                    ),
                  ),
                ],
              )
            : const Text(
                'Connectez-vous avec votre compte Google pour aimer des photos (❤️), créer des dossiers ou ajouter des photos associées à votre nom.',
                style: TextStyle(fontSize: 12, color: Colors.white70),
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Fermer', style: TextStyle(color: Colors.white54)),
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
                backgroundColor: const Color(0xFF0284C7),
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
          backgroundColor: const Color(0xFF1E293B),
          avatar: const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF38BDF8)),
          ),
          label: Text(compact ? '...' : 'Connexion...', style: const TextStyle(fontSize: 11)),
        ),
      );
    }

    if (_auth.isSignedIn) {
      return Padding(
        padding: const EdgeInsets.only(right: 6),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: _showUserAccountSheet,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF4ADE80).withValues(alpha: 0.5)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFF4ADE80),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _auth.shortLabel,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.expand_more, size: 14, color: Colors.white70),
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF38BDF8),
          backgroundColor: const Color(0xFF1E293B),
          side: const BorderSide(color: Color(0xFF0284C7)),
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

    int computeTotal(String nodeId, Set<String> visited) {
      if (!visited.add(nodeId)) return 0;
      int sum = directCounts[nodeId] ?? 0;
      for (final child in _childrenByParent[nodeId] ?? const <AlbumNode>[]) {
        sum += computeTotal(child.id, visited);
      }
      return sum;
    }

    final updatedNodes = <String, AlbumNode>{};
    for (final entry in _nodesById.entries) {
      final node = entry.value;
      final dCount = directCounts[node.id] ?? 0;
      final tCount = node.isFolder ? computeTotal(node.id, {}) : dCount;
      updatedNodes[node.id] = AlbumNode(
        id: node.id,
        name: node.name,
        parentId: node.parentId,
        isFolder: node.isFolder,
        directCount: dCount,
        totalCount: tCount,
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

      // 1. Appliquer les nouveaux dossiers & albums (ainsi que déplacements, suppressions et pays assignés)
      for (final ca in delta.customAlbums) {
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

      final updatedAll = <PhotoItem>[];
      for (final p in _allPhotos) {
        final ov = _overridesByPhotoId[p.id];
        if (ov == null) {
          updatedAll.add(p);
          continue;
        }
        if (ov.isDeleted) {
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
      _recalculateAlbumCounts();

      if (!silent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF0F172A),
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
              CircularProgressIndicator(color: Color(0xFF38BDF8)),
              SizedBox(height: 16),
              Text("Chargement de Medias Familly...", style: TextStyle(color: Colors.white70)),
            ],
          ),
        ),
      );
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth >= 900;

    if (isWide) {
      return _buildDesktopScaffold();
    }
    return _buildMobileScaffold();
  }

  Widget _buildDesktopScaffold() {
    final activeNavIndex = _mediaMode == 0 ? _currentIndex : _currentIndex.clamp(0, 2);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        surfaceTintColor: Colors.transparent,
        toolbarHeight: 64,
        titleSpacing: 20,
        shape: const Border(bottom: BorderSide(color: Colors.white10)),
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0284C7), Color(0xFF38BDF8)],
                  begin: Alignment.bottomLeft,
                  end: Alignment.topRight,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.photo_library_outlined, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Text(
                      "Medias Familly",
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, letterSpacing: -0.3),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0284C7).withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.4)),
                      ),
                      child: const Text(
                        "HD",
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF38BDF8)),
                      ),
                    ),
                  ],
                ),
                Text(
                  "${_allPhotos.length} médias indexés",
                  style: const TextStyle(fontSize: 11, color: Colors.white54),
                ),
              ],
            ),
            const SizedBox(width: 32),
            // Sélecteur Photos / Vidéos compact et centré/aligné proprement
            SizedBox(
              width: 320,
              child: SegmentedButton<int>(
                showSelectedIcon: false,
                style: SegmentedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  selectedBackgroundColor: const Color(0xFF0284C7),
                  selectedForegroundColor: Colors.white,
                  backgroundColor: const Color(0xFF1E293B),
                  foregroundColor: Colors.white70,
                  side: const BorderSide(color: Colors.white12),
                ),
                segments: [
                  ButtonSegment(
                    value: 0,
                    icon: const Icon(Icons.camera_alt_outlined, size: 15),
                    label: Text("Photos (${_photosOnly.length})", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                  ButtonSegment(
                    value: 1,
                    icon: const Icon(Icons.videocam_outlined, size: 15),
                    label: Text("Vidéos (${_videosOnly.length})", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                ],
                selected: {_mediaMode},
                onSelectionChanged: (set) => setState(() {
                  _mediaMode = set.first;
                  if (_mediaMode == 1 && _currentIndex > 2) {
                    _currentIndex = 0;
                  }
                }),
              ),
            ),
          ],
        ),
        actions: [
          _buildAuthHeaderChip(compact: false),
          IconButton(
            tooltip: "Ajouter un média Google Drive",
            icon: const Icon(Icons.add_photo_alternate_outlined, color: Color(0xFF4ADE80), size: 22),
            onPressed: () => _showAddPhotoDialog(),
          ),
          IconButton(
            tooltip: "Créer un dossier ou album",
            icon: const Icon(Icons.create_new_folder_outlined, color: Color(0xFFFBBF24), size: 21),
            onPressed: () => _showCreateAlbumDialog(
              defaultParentId: _currentIndex == 3
                  ? (_yearsNavHistory.isEmpty ? _kYearsRootId : _yearsNavHistory.last.id)
                  : (_navHistory.isEmpty ? null : _navHistory.last.id),
            ),
          ),
          IconButton(
            tooltip: "Synchroniser les nouveautés (Supabase Cloud)",
            icon: _isSyncingCloud
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF38BDF8)),
                  )
                : const Icon(Icons.sync, color: Color(0xFF38BDF8), size: 20),
            onPressed: () => _syncWithCloud(silent: false),
          ),
          IconButton(
            tooltip: "Mises à jour (v$appVersionLabel)",
            icon: const Icon(Icons.system_update_alt_outlined, color: Color(0xFF38BDF8), size: 20),
            onPressed: () async {
              final update = await AppUpdateService.checkUpdate();
              if (!context.mounted) return;
              if (update != null) {
                await AppUpdateService.promptUpdate(context, update, isForced: true);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    backgroundColor: Color(0xFF0F172A),
                    content: Text(
                      'Votre application Medias Familly est à jour (v$appVersionLabel).',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                );
              }
            },
          ),
          const SizedBox(width: 4),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: const Color(0xFF1E293B),
                side: const BorderSide(color: Colors.white12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              ),
              onPressed: () => _openUrl(_gdriveUrl),
              icon: const Icon(Icons.cloud_outlined, size: 16, color: Color(0xFF38BDF8)),
              label: const Text("Google Drive HD", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
            ),
          ),
        ],
      ),
      body: Row(
        children: [
          Container(
            width: 220,
            decoration: const BoxDecoration(
              color: Color(0xFF0F172A),
              border: Border(right: BorderSide(color: Colors.white10)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    "NAVIGATION",
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
                      color: Colors.white38,
                    ),
                  ),
                ),
                if (_mediaMode == 0) ...[
                  _buildDesktopNavItem(
                    index: 0,
                    activeIndex: activeNavIndex,
                    icon: Icons.public_outlined,
                    selectedIcon: Icons.public,
                    label: "La carte",
                  ),
                  _buildDesktopNavItem(
                    index: 1,
                    activeIndex: activeNavIndex,
                    icon: Icons.photo_library_outlined,
                    selectedIcon: Icons.photo_library,
                    label: "Galerie",
                    badge: "${_photosOnly.length}",
                  ),
                  _buildDesktopNavItem(
                    index: 2,
                    activeIndex: activeNavIndex,
                    icon: Icons.folder_outlined,
                    selectedIcon: Icons.folder,
                    label: "Thématiques",
                    badge: "${_countPhotosInTree(yearsTree: false)}",
                  ),
                  _buildDesktopNavItem(
                    index: 3,
                    activeIndex: activeNavIndex,
                    icon: Icons.calendar_today_outlined,
                    selectedIcon: Icons.calendar_today,
                    label: "Années",
                    badge: "${_countPhotosInTree(yearsTree: true)}",
                  ),
                  _buildDesktopNavItem(
                    index: 4,
                    activeIndex: activeNavIndex,
                    icon: Icons.search,
                    selectedIcon: Icons.search,
                    label: "Recherche",
                  ),
                ] else ...[
                  _buildDesktopNavItem(
                    index: 0,
                    activeIndex: activeNavIndex,
                    icon: Icons.video_library_outlined,
                    selectedIcon: Icons.video_library,
                    label: "Galerie Vidéos",
                    badge: "${_videosOnly.length}",
                  ),
                  _buildDesktopNavItem(
                    index: 1,
                    activeIndex: activeNavIndex,
                    icon: Icons.calendar_today_outlined,
                    selectedIcon: Icons.calendar_today,
                    label: "Années Vidéos",
                    badge: "${_videoYears.length}",
                  ),
                  _buildDesktopNavItem(
                    index: 2,
                    activeIndex: activeNavIndex,
                    icon: Icons.search,
                    selectedIcon: Icons.search,
                    label: "Recherche",
                  ),
                ],
                const Spacer(),
                Container(
                  margin: const EdgeInsets.all(12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B).withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.cloud_done_outlined, size: 15, color: Color(0xFF4ADE80)),
                          SizedBox(width: 6),
                          Text(
                            "Google Drive synchronisé",
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "v$appVersionLabel • Build $appBuildNumber",
                        style: const TextStyle(fontSize: 10, color: Colors.white38),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _mediaMode == 0
                ? IndexedStack(
                    index: _currentIndex,
                    children: [
                      _buildWorldMapTab(),
                      _buildGalleryTab(_photosOnly, isVideo: false),
                      _buildAlbumsTab(),
                      _buildPhotoYearsTab(),
                      _buildSearchTab(),
                    ],
                  )
                : IndexedStack(
                    index: _currentIndex.clamp(0, 2),
                    children: [
                      _buildGalleryTab(_videosOnly, isVideo: true),
                      _buildVideoYearsTab(),
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
            color: isSelected ? const Color(0xFF0284C7).withValues(alpha: 0.22) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? const Color(0xFF38BDF8).withValues(alpha: 0.35) : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              Icon(
                isSelected ? selectedIcon : icon,
                size: 18,
                color: isSelected ? const Color(0xFF38BDF8) : Colors.white60,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected ? Colors.white : Colors.white70,
                  ),
                ),
              ),
              if (badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF0284C7).withValues(alpha: 0.4) : const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    badge,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? const Color(0xFF38BDF8) : Colors.white54,
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
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        title: const Row(
          children: [
            Icon(Icons.photo_library_outlined, color: Color(0xFF38BDF8), size: 22),
            SizedBox(width: 8),
            Text("Medias Familly", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        actions: [
          _buildAuthHeaderChip(compact: true),
          IconButton(
            tooltip: "Ajouter un média Google Drive",
            icon: const Icon(Icons.add_photo_alternate_outlined, color: Color(0xFF4ADE80)),
            onPressed: () => _showAddPhotoDialog(),
          ),
          IconButton(
            tooltip: "Créer un dossier ou album",
            icon: const Icon(Icons.create_new_folder_outlined, color: Color(0xFFFBBF24)),
            onPressed: () => _showCreateAlbumDialog(
              defaultParentId: _currentIndex == 3
                  ? (_yearsNavHistory.isEmpty ? _kYearsRootId : _yearsNavHistory.last.id)
                  : (_navHistory.isEmpty ? null : _navHistory.last.id),
            ),
          ),
          IconButton(
            tooltip: "Synchroniser les nouveautés (Supabase Cloud)",
            icon: _isSyncingCloud
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF38BDF8)),
                  )
                : const Icon(Icons.sync, color: Color(0xFF38BDF8)),
            onPressed: () => _syncWithCloud(silent: false),
          ),
          IconButton(
            tooltip: "Mises à jour (v$appVersionLabel)",
            icon: const Icon(Icons.system_update_alt_outlined, color: Color(0xFF38BDF8)),
            onPressed: () async {
              final update = await AppUpdateService.checkUpdate();
              if (!context.mounted) return;
              if (update != null) {
                await AppUpdateService.promptUpdate(context, update, isForced: true);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    backgroundColor: Color(0xFF0F172A),
                    content: Text(
                      'Votre application Medias Familly est à jour (v$appVersionLabel).',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                );
              }
            },
          ),
          IconButton(
            tooltip: "Ouvrir Google Drive HD",
            icon: const Icon(Icons.cloud_outlined, color: Color(0xFF38BDF8)),
            onPressed: () => _openUrl(_gdriveUrl),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8, left: 16, right: 16),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<int>(
                style: SegmentedButton.styleFrom(
                  selectedBackgroundColor: const Color(0xFF0284C7).withValues(alpha: 0.3),
                  selectedForegroundColor: const Color(0xFF38BDF8),
                  backgroundColor: const Color(0xFF1E293B),
                ),
                segments: [
                  ButtonSegment(
                    value: 0,
                    icon: const Icon(Icons.camera_alt_outlined, size: 16),
                    label: Text("Photos (${_photosOnly.length})", style: const TextStyle(fontSize: 12)),
                  ),
                  ButtonSegment(
                    value: 1,
                    icon: const Icon(Icons.videocam_outlined, size: 16),
                    label: Text("Vidéos (${_videosOnly.length})", style: const TextStyle(fontSize: 12)),
                  ),
                ],
                selected: {_mediaMode},
                onSelectionChanged: (set) => setState(() {
                  _mediaMode = set.first;
                  if (_mediaMode == 1 && _currentIndex > 2) {
                    _currentIndex = 0;
                  }
                }),
              ),
            ),
          ),
        ),
      ),
      body: _mediaMode == 0
          ? IndexedStack(
              index: _currentIndex,
              children: [
                _buildWorldMapTab(),
                _buildGalleryTab(_photosOnly, isVideo: false),
                _buildAlbumsTab(),
                _buildPhotoYearsTab(),
                _buildSearchTab(),
              ],
            )
          : IndexedStack(
              index: _currentIndex.clamp(0, 2),
              children: [
                _buildGalleryTab(_videosOnly, isVideo: true),
                _buildVideoYearsTab(),
                _buildSearchTab(),
              ],
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _mediaMode == 0 ? _currentIndex : _currentIndex.clamp(0, 2),
        onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
        backgroundColor: const Color(0xFF0F172A),
        indicatorColor: const Color(0xFF0284C7).withValues(alpha: 0.3),
        destinations: _mediaMode == 0
            ? const [
                NavigationDestination(
                  icon: Icon(Icons.public_outlined),
                  selectedIcon: Icon(Icons.public, color: Color(0xFF38BDF8)),
                  label: "La carte",
                ),
                NavigationDestination(
                  icon: Icon(Icons.photo_library_outlined),
                  selectedIcon: Icon(Icons.photo_library, color: Color(0xFF38BDF8)),
                  label: "Galerie",
                ),
                NavigationDestination(
                  icon: Icon(Icons.folder_outlined),
                  selectedIcon: Icon(Icons.folder, color: Color(0xFF38BDF8)),
                  label: "Thématiques",
                ),
                NavigationDestination(
                  icon: Icon(Icons.calendar_today_outlined),
                  selectedIcon: Icon(Icons.calendar_today, color: Color(0xFF38BDF8)),
                  label: "Années",
                ),
                NavigationDestination(
                  icon: Icon(Icons.search),
                  selectedIcon: Icon(Icons.search, color: Color(0xFF38BDF8)),
                  label: "Recherche",
                ),
              ]
            : const [
                NavigationDestination(
                  icon: Icon(Icons.video_library_outlined),
                  selectedIcon: Icon(Icons.video_library, color: Color(0xFF38BDF8)),
                  label: "Galerie",
                ),
                NavigationDestination(
                  icon: Icon(Icons.calendar_today_outlined),
                  selectedIcon: Icon(Icons.calendar_today, color: Color(0xFF38BDF8)),
                  label: "Années",
                ),
                NavigationDestination(
                  icon: Icon(Icons.search),
                  selectedIcon: Icon(Icons.search, color: Color(0xFF38BDF8)),
                  label: "Recherche",
                ),
              ],
      ),
    );
  }

  int _countPhotosInTree({required bool yearsTree}) {
    final targetAlbumIds = <String>{};
    for (final node in _nodesById.values) {
      if (node.id == _kYearsRootId) continue;
      if (_isInsideYearsTree(node.id) == yearsTree) {
        targetAlbumIds.add(node.id);
      }
    }
    int count = 0;
    for (final p in _photosOnly) {
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
            backgroundColor: const Color(0xFF0F172A),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Colors.white12),
            ),
            title: Row(
              children: [
                const Icon(Icons.public_rounded, color: Color(0xFF38BDF8), size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Pays pour "${node.name}"',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
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
                      fillColor: const Color(0xFF1E293B),
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
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: Colors.white,
                            ),
                          ),
                          subtitle: Text(
                            '${c.continent} · ${c.capital}',
                            style: const TextStyle(fontSize: 11, color: Colors.white54),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isUsed)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0EA5E9).withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'Visité',
                                    style: TextStyle(fontSize: 10, color: Color(0xFF7DD3FC)),
                                  ),
                                ),
                              if (isSelected) ...[
                                const SizedBox(width: 6),
                                const Icon(Icons.check_circle, color: Color(0xFF38BDF8), size: 18),
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
                                backgroundColor: const Color(0xFF0F172A),
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
                child: const Text("Fermer", style: TextStyle(color: Colors.white54)),
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

  List<CountryVisitStats> _computeVisitedCountryStats() {
    final Map<String, Set<int>> photoIdsByIso = {};
    final Map<String, Set<int>> videoIdsByIso = {};
    final Map<String, List<CountryAlbumSummary>> albumsByIso = {};
    final Map<String, List<CountrySlideshowPhoto>> slidesByIso = {};
    final Map<String, Set<int>> slideSeenIds = {};
    final Map<String, Set<String>> addedAlbumIdsByIso = {};
    final Map<int, PhotoItem> mediaById = {for (final m in _allPhotos) m.id: m};

    void ensureIso(String iso) {
      photoIdsByIso.putIfAbsent(iso, () => <int>{});
      videoIdsByIso.putIfAbsent(iso, () => <int>{});
      albumsByIso.putIfAbsent(iso, () => <CountryAlbumSummary>[]);
      slidesByIso.putIfAbsent(iso, () => <CountrySlideshowPhoto>[]);
      slideSeenIds.putIfAbsent(iso, () => <int>{});
      addedAlbumIdsByIso.putIfAbsent(iso, () => <String>{});
    }

    // 1. Scan all direct children of "02 - Pays" (_kPaysFolderId) -> populates slideshowPhotos too!
    final paysChildren = _childrenByParent[_kPaysFolderId] ?? const <AlbumNode>[];
    for (final child in paysChildren) {
      final meta = matchCountryMeta(child.name);
      if (meta == null) continue;
      ensureIso(meta.iso3);

      final descendantIds = _getAllDescendantAlbumIds(child.id);
      for (final m in _allPhotos) {
        if (m.albums.any((a) => descendantIds.contains(a))) {
          if (m.isVideo) {
            videoIdsByIso[meta.iso3]!.add(m.id);
          } else {
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

      final subNodes = child.isFolder ? (_childrenByParent[child.id] ?? const <AlbumNode>[]) : const <AlbumNode>[];
      final nodesToList = subNodes.isNotEmpty ? subNodes : [child];
      for (final node in nodesToList) {
        if (!addedAlbumIdsByIso[meta.iso3]!.add(node.id)) continue;
        final targetIds = node.isFolder ? _getAllDescendantAlbumIds(node.id) : {node.id};
        int pCount = 0;
        int vCount = 0;
        for (final m in _allPhotos) {
          if (m.albums.any((a) => targetIds.contains(a))) {
            if (m.isVideo) {
              vCount++;
            } else {
              pCount++;
            }
          }
        }
        albumsByIso[meta.iso3]!.add(
          CountryAlbumSummary(
            albumId: node.id,
            name: node.name,
            dateHint: _extractDateHint(node.name),
            sourceLabel: 'Pays',
            photoCount: pCount,
            videoCount: vCount,
            isFolder: node.isFolder,
          ),
        );
      }
    }

    // 2. Scan all Années albums (default FRA, or overridden via _albumCountryIsoById)
    //    plus any Thématiques album with an explicit _albumCountryIsoById override
    final Map<String, List<PhotoItem>> photosByAlbumId = {};
    for (final m in _allPhotos) {
      for (final aId in m.albums) {
        photosByAlbumId.putIfAbsent(aId, () => []).add(m);
      }
    }

    for (final node in _nodesById.values) {
      if (node.id == _kYearsRootId) continue;
      final inYears = _isInsideYearsTree(node.id);
      final hasExplicit = _albumCountryIsoById.containsKey(node.id);
      if (!inYears && !hasExplicit) continue;
      // In Années, list leaf albums (or folders with direct photos) so we don't duplicate parent year folders
      final directMedia = photosByAlbumId[node.id] ?? const <PhotoItem>[];
      if (node.isFolder && directMedia.isEmpty && !hasExplicit) continue;

      final iso = _getEffectiveCountryIsoForNode(node.id);
      if (iso == null || !kCountriesByIso.containsKey(iso)) continue;
      ensureIso(iso);

      final targetIds = node.isFolder ? _getAllDescendantAlbumIds(node.id) : {node.id};
      int pCount = 0;
      int vCount = 0;
      for (final aId in targetIds) {
        for (final m in (photosByAlbumId[aId] ?? const <PhotoItem>[])) {
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
        albumsByIso[iso]!.add(
          CountryAlbumSummary(
            albumId: node.id,
            name: node.name,
            dateHint: _extractDateHint(node.name),
            sourceLabel: inYears ? 'Années' : 'Thématiques',
            photoCount: pCount,
            videoCount: vCount,
            isFolder: node.isFolder,
          ),
        );
      }
    }

    // 3. Also include photo/video `country` metadata without double counting
    for (final m in _allPhotos) {
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
      final albums = albumsByIso[iso]!
        ..sort((a, b) => (b.photoCount + b.videoCount).compareTo(a.photoCount + a.videoCount));

      final travelDates = iso == 'FRA'
          ? const <String>[]
          : _computeTravelDateRanges(pSet.map((id) => mediaById[id]).whereType<PhotoItem>());

      result.add(
        CountryVisitStats(
          meta: meta,
          photoCount: pSet.length,
          videoCount: vSet.length,
          albums: albums,
          slideshowPhotos: slidesByIso[iso] ?? const [],
          travelDateRanges: travelDates,
        ),
      );
    }

    result.sort((a, b) => b.totalMedia.compareTo(a.totalMedia));
    return result;
  }

  Widget _buildWorldMapTab() {
    final visited = _computeVisitedCountryStats();
    final totalP = visited.fold<int>(0, (acc, c) => acc + c.photoCount);
    final totalV = visited.fold<int>(0, (acc, c) => acc + c.videoCount);

    return WorldMapTab(
      visitedCountries: visited,
      totalPhotos: totalP,
      totalVideos: totalV,
      onAddCountryFolder: () => _showCreateAlbumDialog(defaultParentId: _kPaysFolderId),
      onOpenAlbum: (albumId) {
        final node = _nodesById[albumId];
        if (node != null) {
          _openPhotosForNode(node);
        }
      },
      onOpenCountryMedia: (stats) {
        final matchingAlbumIds = stats.albums.map((a) => a.albumId).expand((id) {
          final n = _nodesById[id];
          return n != null && n.isFolder ? _getAllDescendantAlbumIds(id) : {id};
        }).toSet();

        final countryMedia = _allPhotos.where((m) {
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
              currentUserEmail: _auth.email,
              onToggleLike: _handleTogglePhotoLike,
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
        color: Color(0xFF0F172A),
        border: Border(bottom: BorderSide(color: Colors.white10)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF0284C7).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isVideo ? Icons.movie_outlined : Icons.photo_library_outlined,
              size: 20,
              color: const Color(0xFF38BDF8),
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
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  "${photos.length} ${isVideo ? 'vidéos' : 'photos'} • Google Drive HD & Cloud Familial",
                  style: const TextStyle(fontSize: 11, color: Colors.white54),
                ),
              ],
            ),
          ),
          TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF4ADE80),
              backgroundColor: const Color(0xFF1E293B),
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

  // --- PHOTOS: Lightroom Thematics Tab ---
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
    final currentParentId = history.isEmpty ? rootParentId : history.last.id;
    final currentChildren = _childrenByParent[currentParentId] ?? [];

    final filtered = searchQuery.isEmpty
        ? currentChildren
        : _nodesById.values.where((a) {
            if (a.id == _kYearsRootId) return false;
            final inYears = _isInsideYearsTree(a.id);
            if (isYearsTab != inYears) return false;
            return a.name.toLowerCase().contains(searchQuery.toLowerCase());
          }).toList();

    return Column(
      children: [
        // Breadcrumb bar + Nouveau dossier/album
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          color: const Color(0xFF0F172A),
          child: Row(
            children: [
              if (history.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.arrow_back, size: 20, color: Color(0xFF38BDF8)),
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
                            color: history.isEmpty ? const Color(0xFF38BDF8) : Colors.white60,
                          ),
                        ),
                      ),
                      for (int i = 0; i < history.length; i++) ...[
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4),
                          child: Icon(Icons.chevron_right, size: 16, color: Colors.white30),
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
                              color: i == history.length - 1 ? const Color(0xFF38BDF8) : Colors.white60,
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
                  backgroundColor: const Color(0xFF0284C7),
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
              fillColor: const Color(0xFF1E293B),
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
              style: TextStyle(fontSize: 10, color: Colors.white38),
            ),
          ),
        ),

        // List
        Expanded(
          child: filtered.isEmpty
              ? const Center(
                  child: Text("Aucun dossier ou album trouvé", style: TextStyle(color: Colors.white38)),
                )
              : ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, idx) {
                    final node = filtered[idx];
                    final children = _childrenByParent[node.id] ?? [];
                    final hasChildren = children.isNotEmpty;

                    return ListTile(
                      leading: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          node.isFolder
                              ? (isYearsTab && history.isEmpty ? Icons.calendar_month_outlined : Icons.folder_outlined)
                              : Icons.photo_library_outlined,
                          color: node.isFolder ? const Color(0xFFFBBF24) : const Color(0xFF38BDF8),
                          size: 22,
                        ),
                      ),
                      title: Text(
                        node.name,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: node.isFolder ? FontWeight.bold : FontWeight.w500,
                        ),
                      ),
                      subtitle: Text(
                        "${node.isFolder ? '${children.length} sous-dossiers/albums • ${node.totalCount} photos' : '${node.directCount} photos'}"
                        "${node.createdByName != null && node.createdByName!.isNotEmpty ? ' • par ${node.createdByName}' : ''}",
                        style: const TextStyle(fontSize: 11, color: Colors.white54),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (node.isFolder && node.totalCount > 0)
                            IconButton(
                              icon: const Icon(Icons.grid_view, size: 18, color: Colors.white54),
                              tooltip: "Voir toutes les photos du dossier",
                              onPressed: () => _openPhotosForNode(node),
                            ),
                          IconButton(
                            icon: const Icon(Icons.more_vert, size: 18, color: Colors.white54),
                            tooltip: "Actions (Déplacer, Renommer, Supprimer)",
                            onPressed: () => _showNodeActionsSheet(node),
                          ),
                          if (hasChildren)
                            const Icon(Icons.chevron_right, size: 20, color: Colors.white38),
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

  void _openPhotosForNode(AlbumNode node) {
    final targetIds = node.isFolder ? _getAllDescendantAlbumIds(node.id) : {node.id};
    final albumPhotos = _photosOnly.where((p) => p.albums.any((aId) => targetIds.contains(aId))).toList();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PhotoGridScreen(
          title: node.name,
          photos: albumPhotos,
          nodesById: _nodesById,
          gdriveUrl: _gdriveUrl,
          likesByPhotoId: _likesByPhotoId,
          currentUserEmail: _auth.email,
          onToggleLike: _handleTogglePhotoLike,
          onAssignAlbum: _handleAssignAlbumToPhoto,
          onDeletePhoto: _handleDeletePhoto,
          onBulkAssignAlbum: _handleBulkAssignAlbumToPhotos,
          onBulkDeletePhotos: _handleBulkDeletePhotos,
        ),
      ),
    );
  }

  void _showNodeActionsSheet(AlbumNode node) {
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Colors.white12),
        ),
        title: Row(
          children: [
            Icon(
              node.isFolder ? Icons.folder_outlined : Icons.photo_library_outlined,
              color: node.isFolder ? const Color(0xFFFBBF24) : const Color(0xFF38BDF8),
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                node.name,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.grid_view, color: Color(0xFF38BDF8)),
              title: const Text("Voir toutes les photos", style: TextStyle(fontSize: 14)),
              subtitle: Text("${node.totalCount} photos", style: const TextStyle(fontSize: 11, color: Colors.white54)),
              onTap: () {
                Navigator.of(dialogCtx).pop();
                _openPhotosForNode(node);
              },
            ),
            ListTile(
              leading: const Icon(Icons.public_rounded, color: Color(0xFF38BDF8)),
              title: const Text("Pays sur la carte", style: TextStyle(fontSize: 14)),
              subtitle: Builder(
                builder: (_) {
                  final iso = _getEffectiveCountryIsoForNode(node.id);
                  final meta = iso != null ? kCountriesByIso[iso] : null;
                  final label = meta != null
                      ? '${meta.flag} ${meta.nameFr}${_albumCountryIsoById.containsKey(node.id) ? '' : ' (par défaut)'}'
                      : 'Aucun pays assigné';
                  return Text(label, style: const TextStyle(fontSize: 11, color: Colors.white54));
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
              leading: const Icon(Icons.edit_outlined, color: Colors.white70),
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
            child: const Text("Fermer", style: TextStyle(color: Colors.white54)),
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
          backgroundColor: const Color(0xFF0F172A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Colors.white12),
          ),
          title: Text(
            'Déplacer "${node.name}"',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
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
              dropdownColor: const Color(0xFF1E293B),
              decoration: InputDecoration(
                labelText: "Nouveau dossier parent",
                filled: true,
                fillColor: const Color(0xFF1E293B),
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
              child: const Text("Annuler", style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0284C7),
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
                    backgroundColor: const Color(0xFF0F172A),
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
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Colors.white12),
        ),
        title: const Text(
          "Renommer le dossier / album",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: InputDecoration(
            labelText: "Nouveau nom",
            filled: true,
            fillColor: const Color(0xFF1E293B),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text("Annuler", style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0284C7),
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
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Colors.white12),
        ),
        title: Text(
          'Supprimer "${node.name}" ?',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        content: Text(
          subCount > 0
              ? 'Attention : ce dossier contient $subCount sous-dossier(s) ou sous-album(s). Tout ce qui se trouve en dessous sera également supprimé de l\'arborescence pour tous les utilisateurs (les photos elles-mêmes restent dans la Galerie).'
              : 'Ce dossier ou album sera supprimé de l\'arborescence pour tous les utilisateurs (les photos elles-mêmes restent dans la Galerie).',
          style: const TextStyle(fontSize: 12, color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text("Annuler", style: TextStyle(color: Colors.white54)),
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
                  backgroundColor: const Color(0xFF0F172A),
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
          tileColor: const Color(0xFF1E293B).withValues(alpha: 0.5),
          leading: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFF0284C7).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.movie_filter_outlined, color: Color(0xFF38BDF8), size: 24),
          ),
          title: const Text("Toutes les vidéos", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF0284C7).withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text("${_videosOnly.length}", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF38BDF8))),
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
        const Divider(height: 1, color: Colors.white10),
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
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.movie_outlined, color: Color(0xFFFBBF24), size: 22),
                ),
                title: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text("${vy.count}", style: const TextStyle(fontSize: 11, color: Colors.white70)),
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
      allPhotos: _photosOnly,
      nodesById: _nodesById,
      gdriveUrl: _gdriveUrl,
      likesByPhotoId: _likesByPhotoId,
      currentUserEmail: _auth.email,
      onToggleLike: _handleTogglePhotoLike,
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
            backgroundColor: const Color(0xFF0F172A),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Colors.white12),
            ),
            title: Row(
              children: [
                Icon(
                  isPaysParent ? Icons.public_rounded : Icons.create_new_folder_outlined,
                  color: isPaysParent ? const Color(0xFF38BDF8) : const Color(0xFFFBBF24),
                  size: 24,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isPaysParent ? "Ajouter un pays (lié à La carte)" : "Nouveau dossier ou album",
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
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
                        dropdownColor: const Color(0xFF1E293B),
                        decoration: InputDecoration(
                          labelText: "Choisir un pays (connecté à La carte)",
                          filled: true,
                          fillColor: const Color(0xFF1E293B),
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
                        fillColor: const Color(0xFF1E293B),
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
                      dropdownColor: const Color(0xFF1E293B),
                      decoration: InputDecoration(
                        labelText: "Emplacement (Dossier parent)",
                        filled: true,
                        fillColor: const Color(0xFF1E293B),
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
                        style: const TextStyle(fontSize: 11, color: Colors.white54),
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
              child: const Text("Annuler", style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0284C7),
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
                    backgroundColor: const Color(0xFF0F172A),
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

  Future<void> _showAddPhotoDialog({bool defaultIsVideo = false}) async {
    final driveLinkController = TextEditingController();
    final filenameController = TextEditingController();
    final yearController = TextEditingController(text: DateTime.now().year.toString());
    final countryController = TextEditingController();
    final cityController = TextEditingController();
    bool isVideo = defaultIsVideo;
    String? selectedAlbumId = _navHistory.isNotEmpty ? _navHistory.last.id : null;

    final allAlbumsSorted = _nodesById.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF0F172A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Colors.white12),
          ),
          title: const Row(
            children: [
              Icon(Icons.add_photo_alternate_outlined, color: Color(0xFF4ADE80), size: 24),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  "Ajouter une photo / vidéo Google Drive",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
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
                    style: TextStyle(fontSize: 11, color: Colors.white70),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: driveLinkController,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: "Lien Google Drive ou File ID *",
                      hintText: "https://drive.google.com/file/d/.../view",
                      filled: true,
                      fillColor: const Color(0xFF1E293B),
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
                      fillColor: const Color(0xFF1E293B),
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
                            fillColor: const Color(0xFF1E293B),
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
                            fillColor: const Color(0xFF1E293B),
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
                    dropdownColor: const Color(0xFF1E293B),
                    decoration: InputDecoration(
                      labelText: "Ranger dans l'album / dossier",
                      filled: true,
                      fillColor: const Color(0xFF1E293B),
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
              child: const Text("Annuler", style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0284C7),
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
                    backgroundColor: const Color(0xFF0F172A),
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
        backgroundColor: const Color(0xFF0F172A),
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
        backgroundColor: const Color(0xFF0F172A),
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
    setState(() {
      _allPhotos.removeWhere((p) => ids.contains(p.id));
      _photosOnly.removeWhere((p) => ids.contains(p.id));
      _videosOnly.removeWhere((p) => ids.contains(p.id));
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
      if (!ok) allOk = false;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF0F172A),
        content: Text(
          allOk
              ? '✔ ${photos.length} média(s) mis à la corbeille pour tout le monde.'
              : '⚠ ${photos.length} média(s) masqué(s) localement.',
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
      ),
    );
  }

  Future<void> _handleDeletePhoto(PhotoItem photo) async {
    setState(() {
      _allPhotos.removeWhere((p) => p.id == photo.id);
      _photosOnly.removeWhere((p) => p.id == photo.id);
      _videosOnly.removeWhere((p) => p.id == photo.id);
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
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF0F172A),
        content: Text(
          ok
              ? '✔ "${photo.filename}" masquée / mise à la corbeille pour tout le monde.'
              : '⚠ Masquée localement.',
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
      ),
    );
  }

  Future<void> _handleTogglePhotoLike(PhotoItem photo) async {
    if (!_auth.isSignedIn || _auth.email == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF0F172A),
          content: const Text(
            'Connectez-vous avec Google (en haut à droite) pour aimer des photos ❤️',
            style: TextStyle(color: Colors.white, fontSize: 12),
          ),
          action: SnackBarAction(
            label: 'Connexion',
            textColor: const Color(0xFF38BDF8),
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

class PhotoGridScreen extends StatelessWidget {
  final String title;
  final List<PhotoItem> photos;
  final Map<String, AlbumNode> nodesById;
  final String gdriveUrl;
  final Map<int, List<PhotoLikeRecord>>? likesByPhotoId;
  final String? currentUserEmail;
  final Future<void> Function(PhotoItem photo)? onToggleLike;
  final Future<void> Function(PhotoItem photo, String albumId)? onAssignAlbum;
  final Future<void> Function(PhotoItem photo)? onDeletePhoto;
  final Future<void> Function(List<PhotoItem> photos, String albumId)? onBulkAssignAlbum;
  final Future<void> Function(List<PhotoItem> photos)? onBulkDeletePhotos;

  const PhotoGridScreen({
    super.key,
    required this.title,
    required this.photos,
    required this.nodesById,
    required this.gdriveUrl,
    this.likesByPhotoId,
    this.currentUserEmail,
    this.onToggleLike,
    this.onAssignAlbum,
    this.onDeletePhoto,
    this.onBulkAssignAlbum,
    this.onBulkDeletePhotos,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text("${photos.length} éléments", style: const TextStyle(fontSize: 11, color: Colors.white54)),
          ],
        ),
      ),
      body: PhotoGridBody(
        photos: photos,
        nodesById: nodesById,
        gdriveUrl: gdriveUrl,
        likesByPhotoId: likesByPhotoId,
        currentUserEmail: currentUserEmail,
        onToggleLike: onToggleLike,
        onAssignAlbum: onAssignAlbum,
        onDeletePhoto: onDeletePhoto,
        onBulkAssignAlbum: onBulkAssignAlbum,
        onBulkDeletePhotos: onBulkDeletePhotos,
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
  final String? currentUserEmail;
  final Future<void> Function(PhotoItem photo)? onToggleLike;
  final Future<void> Function(PhotoItem photo, String albumId)? onAssignAlbum;
  final Future<void> Function(PhotoItem photo)? onDeletePhoto;
  final Future<void> Function(List<PhotoItem> photos, String albumId)? onBulkAssignAlbum;
  final Future<void> Function(List<PhotoItem> photos)? onBulkDeletePhotos;

  const PhotoGridBody({
    super.key,
    required this.photos,
    required this.nodesById,
    required this.gdriveUrl,
    this.header,
    this.likesByPhotoId,
    this.currentUserEmail,
    this.onToggleLike,
    this.onAssignAlbum,
    this.onDeletePhoto,
    this.onBulkAssignAlbum,
    this.onBulkDeletePhotos,
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
          backgroundColor: const Color(0xFF0F172A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Colors.white12),
          ),
          title: Text(
            'Ranger ${selectedPhotos.length} média(s) dans un album',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          content: DropdownButtonFormField<String>(
            value: selectedAlbumId,
            isExpanded: true,
            dropdownColor: const Color(0xFF1E293B),
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFF1E293B),
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
              child: const Text("Annuler", style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0284C7),
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
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Colors.white12),
        ),
        title: Text(
          'Mettre ${selectedPhotos.length} média(s) à la corbeille ?',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        content: const Text(
          'Ces photos/vidéos seront masquées de la galerie et des albums pour toute la famille.',
          style: TextStyle(fontSize: 12, color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text("Annuler", style: TextStyle(color: Colors.white54)),
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
    final photos = widget.photos;
    if (photos.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.image_not_supported_outlined, size: 48, color: Colors.white24),
            const SizedBox(height: 12),
            const Text("Aucun média disponible", style: TextStyle(color: Colors.white38)),
          ],
        ),
      );
    }

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
            if (supportsBulk)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _isSelectionMode ? const Color(0xFF0C4A6E).withValues(alpha: 0.45) : const Color(0xFF0B1120),
                  border: const Border(bottom: BorderSide(color: Colors.white10)),
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
                          style: const TextStyle(fontSize: 12, color: Color(0xFF38BDF8)),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => setState(() {
                          _isSelectionMode = false;
                          _selectedPhotoIds.clear();
                        }),
                        icon: const Icon(Icons.close, size: 15, color: Colors.white70),
                        label: const Text('Annuler', style: TextStyle(fontSize: 12, color: Colors.white70)),
                      ),
                    ] else ...[
                      Text(
                        'Appui long ou bouton pour sélectionner',
                        style: const TextStyle(fontSize: 11, color: Colors.white38),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF38BDF8),
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
                    final isSelected = _selectedPhotoIds.contains(photo.id);
                    return _PhotoGridTile(
                      key: ValueKey(photo.id),
                      photo: photo,
                      likeCount: photoLikes.length,
                      isLikedByMe: isLikedByMe,
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
                  color: Color(0xFF0F172A),
                  border: Border(top: BorderSide(color: Colors.white12)),
                ),
                child: SafeArea(
                  top: false,
                  child: Row(
                    children: [
                      if (widget.onAssignAlbum != null || widget.onBulkAssignAlbum != null)
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF38BDF8),
                              side: const BorderSide(color: Color(0xFF0284C7)),
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
          backgroundColor: const Color(0xFF0F172A),
          content: Text("Impossible d'ouvrir le lien Drive : $e", style: const TextStyle(color: Colors.white)),
        ),
      );
    }
  }

  void _openFullScreenZoom(BuildContext context, PhotoItem photo, String fileViewUrl) {
    final previewUrl = photo.largePreviewUrl ?? photo.thumbnailUrl;
    if (previewUrl == null) {
      _launchDriveUrl(context, fileViewUrl);
      return;
    }
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.94),
      builder: (zoomCtx) => Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.black54,
          title: Text(photo.filename, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          actions: [
            TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF38BDF8),
              ),
              onPressed: () => _launchDriveUrl(zoomCtx, fileViewUrl),
              icon: const Icon(Icons.open_in_new, size: 17),
              label: const Text("Ouvrir sur Google Drive", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: Stack(
          fit: StackFit.expand,
          children: [
            InteractiveViewer(
              minScale: 0.8,
              maxScale: 5.0,
              child: Center(
                child: Image.network(
                  previewUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (ctx, child, progress) {
                    if (progress == null) return child;
                    return const Center(
                      child: CircularProgressIndicator(color: Color(0xFF38BDF8)),
                    );
                  },
                ),
              ),
            ),
            const Positioned(
              bottom: 16,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  "Pincez ou utilisez la molette pour zoomer (jusqu'à 5x)",
                  style: TextStyle(fontSize: 11, color: Colors.white54),
                ),
              ),
            ),
          ],
        ),
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
        builder: (dialogCtx) => Dialog(
          backgroundColor: const Color(0xFF0F172A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Colors.white12),
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
                        icon: const Icon(Icons.fullscreen, color: Color(0xFF38BDF8)),
                        onPressed: () => _openFullScreenZoom(context, photo, fileViewUrl),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white70),
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
                                          child: CircularProgressIndicator(color: Color(0xFF38BDF8)),
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
                                        border: Border.all(color: Colors.white38),
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
                                            Icon(Icons.zoom_out_map, size: 13, color: Colors.white70),
                                            SizedBox(width: 4),
                                            Text("Cliquer pour agrandir", style: TextStyle(fontSize: 10, color: Colors.white70)),
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
                          style: TextStyle(fontSize: 12, color: photo.isVideo ? const Color(0xFFFBBF24) : const Color(0xFF38BDF8), fontWeight: FontWeight.w600)),
                      Text("Date : ${photo.captureDate.isNotEmpty ? photo.captureDate : 'Non renseignée'}",
                          style: const TextStyle(fontSize: 12, color: Colors.white70)),
                      Text("Taille : $sizeMo Mo (${photo.width} × ${photo.height} px)",
                          style: const TextStyle(fontSize: 12, color: Colors.white70)),
                      if (photo.cameraModel != null && photo.cameraModel!.isNotEmpty)
                        Text("Appareil : ${photo.cameraModel}", style: const TextStyle(fontSize: 12, color: Colors.white70)),
                      if (photo.country != null && photo.country!.isNotEmpty)
                        Text("Lieu : ${photo.city != null && photo.city!.isNotEmpty ? '${photo.city}, ' : ''}${photo.country}",
                            style: const TextStyle(fontSize: 12, color: Colors.white70)),
                      if (photo.addedByName != null && photo.addedByName!.isNotEmpty)
                        Text("Ajouté par : ${photo.addedByName}",
                            style: const TextStyle(fontSize: 12, color: Color(0xFF38BDF8), fontWeight: FontWeight.w600)),
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
                                backgroundColor: const Color(0xFF1E293B),
                                visualDensity: VisualDensity.compact,
                              ))
                          .toList(),
                    ),
                  ],
                  const SizedBox(height: 16),
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
                              foregroundColor: const Color(0xFF38BDF8),
                              side: const BorderSide(color: Color(0xFF0284C7)),
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
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0284C7),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: Icon(photo.isVideo ? Icons.play_circle_outline : Icons.cloud_download_outlined, size: 18),
                    label: Text(photo.isVideo
                        ? (photo.driveId != null ? "Lire la vidéo HD sur Google Drive" : "Ouvrir Google Drive")
                        : (photo.driveId != null ? "Ouvrir l'original HD sur Google Drive" : "Ouvrir le dossier Google Drive")),
                    onPressed: () => _launchDriveUrl(dialogCtx, fileViewUrl),
                  ),
                ],
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
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) {
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
                      color: Colors.white24,
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
                                    child: CircularProgressIndicator(color: Color(0xFF38BDF8)),
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
                                  border: Border.all(color: Colors.white38),
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
                                      Icon(Icons.zoom_out_map, size: 13, color: Colors.white70),
                                      SizedBox(width: 4),
                                      Text("Toucher pour agrandir", style: TextStyle(fontSize: 10, color: Colors.white70)),
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
                    style: TextStyle(fontSize: 12, color: photo.isVideo ? const Color(0xFFFBBF24) : const Color(0xFF38BDF8), fontWeight: FontWeight.w600)),
                Text("Date : ${photo.captureDate.isNotEmpty ? photo.captureDate : 'Non renseignée'}",
                    style: const TextStyle(fontSize: 12, color: Colors.white70)),
                Text("Taille : $sizeMo Mo (${photo.width} × ${photo.height} px)",
                    style: const TextStyle(fontSize: 12, color: Colors.white70)),
                if (photo.cameraModel != null && photo.cameraModel!.isNotEmpty)
                  Text("Appareil : ${photo.cameraModel}", style: const TextStyle(fontSize: 12, color: Colors.white70)),
                if (photo.country != null && photo.country!.isNotEmpty)
                  Text("Lieu : ${photo.city != null && photo.city!.isNotEmpty ? '${photo.city}, ' : ''}${photo.country}",
                      style: const TextStyle(fontSize: 12, color: Colors.white70)),
                if (photo.addedByName != null && photo.addedByName!.isNotEmpty)
                  Text("Ajouté par : ${photo.addedByName}",
                      style: const TextStyle(fontSize: 12, color: Color(0xFF38BDF8), fontWeight: FontWeight.w600)),
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
                  const Text("Dossiers & Albums Lightroom :", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white70)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: photoAlbumNames.isEmpty
                        ? [const Text("Aucune thématique spécifique", style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.white38))]
                        : photoAlbumNames
                            .map((name) => Chip(
                                  label: Text(name, style: const TextStyle(fontSize: 10)),
                                  backgroundColor: const Color(0xFF1E293B),
                                  padding: EdgeInsets.zero,
                                ))
                            .toList(),
                  ),
                  const SizedBox(height: 16),
                ],
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
                              Navigator.of(context).pop();
                              await widget.onToggleLike!(photo);
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
                            foregroundColor: const Color(0xFF38BDF8),
                            side: const BorderSide(color: Color(0xFF0284C7)),
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
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0284C7),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: Icon(photo.isVideo ? Icons.play_circle_outline : Icons.cloud_download_outlined, size: 18),
                  label: Text(photo.isVideo
                      ? (photo.driveId != null ? "Lire la vidéo HD sur Google Drive" : "Ouvrir Google Drive")
                      : (photo.driveId != null ? "Ouvrir l'original HD sur Google Drive" : "Ouvrir le dossier Google Drive")),
                  onPressed: () => _launchDriveUrl(sheetCtx, fileViewUrl),
                ),
              ],
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
          backgroundColor: const Color(0xFF0F172A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Colors.white12),
          ),
          title: const Text(
            "Ranger dans un album / dossier",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          content: SizedBox(
            width: 380,
            child: DropdownButtonFormField<String>(
              value: selectedAlbumId,
              isExpanded: true,
              dropdownColor: const Color(0xFF1E293B),
              decoration: InputDecoration(
                labelText: "Choisir l'album ou dossier",
                filled: true,
                fillColor: const Color(0xFF1E293B),
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
              child: const Text("Annuler", style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0284C7),
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
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: widget.isSelected
                  ? const Color(0xFF38BDF8)
                  : (_isHovered ? const Color(0xFF38BDF8).withValues(alpha: 0.6) : Colors.white10),
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
                      color: const Color(0xFF1E293B),
                      child: const Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF38BDF8)),
                        ),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    if (_retryAttempt < _maxRetries) {
                      _scheduleRetry();
                      return Container(
                        color: const Color(0xFF1E293B),
                        child: const Center(
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.white24),
                          ),
                        ),
                      );
                    }
                    return Center(
                      child: Icon(
                        photo.isVideo ? Icons.movie_outlined : Icons.image_outlined,
                        color: Colors.white24,
                        size: 28,
                      ),
                    );
                  },
                )
              else
                Center(
                  child: Icon(
                    photo.isVideo ? Icons.movie_outlined : Icons.cloud_upload_outlined,
                    color: Colors.white24,
                    size: 28,
                  ),
                ),
              if (photo.isVideo)
                Positioned(
                  bottom: 24,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.play_arrow, size: 11, color: Colors.white),
                        SizedBox(width: 2),
                        Text("Vidéo", style: TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              if (photo.driveId == null)
                Positioned(
                  top: 6,
                  left: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD97706).withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.cloud_off, size: 10, color: Colors.white),
                        SizedBox(width: 3),
                        Text("En attente Drive", style: TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.bold)),
                      ],
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
                      color: widget.isSelected ? const Color(0xFF38BDF8) : Colors.white70,
                    ),
                  ),
                ),
              // Bouton Like (❤️) en haut à droite de la vignette
              if (widget.onToggleLike != null || widget.likeCount > 0)
                Positioned(
                  top: 6,
                  right: 6,
                  child: GestureDetector(
                    onTap: widget.onToggleLike,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: widget.isLikedByMe
                            ? const Color(0xFFE11D48).withValues(alpha: 0.9)
                            : Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: widget.isLikedByMe ? const Color(0xFFFDA4AF) : Colors.white24,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            widget.isLikedByMe ? Icons.favorite : Icons.favorite_border,
                            size: 13,
                            color: widget.isLikedByMe ? Colors.white : Colors.white70,
                          ),
                          if (widget.likeCount > 0) ...[
                            const SizedBox(width: 3),
                            Text(
                              "${widget.likeCount}",
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.8),
                        Colors.black.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                  child: Text(
                    photo.filename,
                    style: const TextStyle(fontSize: 10, color: Colors.white70, fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
  final String? currentUserEmail;
  final Future<void> Function(PhotoItem photo)? onToggleLike;
  final Future<void> Function(PhotoItem photo, String albumId)? onAssignAlbum;
  final Future<void> Function(PhotoItem photo)? onDeletePhoto;

  const PhotoSearchScreen({
    super.key,
    required this.allPhotos,
    required this.nodesById,
    required this.gdriveUrl,
    this.likesByPhotoId,
    this.currentUserEmail,
    this.onToggleLike,
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
              fillColor: const Color(0xFF1E293B),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
            onChanged: _onSearch,
          ),
        ),
        Expanded(
          child: _query.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.search, size: 48, color: Colors.white24),
                      SizedBox(height: 12),
                      Text("Tapez pour rechercher dans les photos", style: TextStyle(color: Colors.white38)),
                    ],
                  ),
                )
              : _results.isEmpty
                  ? const Center(
                      child: Text("Aucun résultat", style: TextStyle(color: Colors.white38)),
                    )
                  : PhotoGridBody(
                      photos: _results,
                      nodesById: widget.nodesById,
                      gdriveUrl: widget.gdriveUrl,
                      likesByPhotoId: widget.likesByPhotoId,
                      currentUserEmail: widget.currentUserEmail,
                      onToggleLike: widget.onToggleLike,
                      onAssignAlbum: widget.onAssignAlbum,
                      onDeletePhoto: widget.onDeletePhoto,
                    ),
        ),
      ],
    );
  }
}
