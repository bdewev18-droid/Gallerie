import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'services/app_update_service.dart';

const int appBuildNumber = 1;
const String appVersionLabel = "1.0.0";

void main() {
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
      ? 'https://drive.google.com/thumbnail?id=$driveId&sz=w400'
      : null;

  String? get largePreviewUrl => driveId != null
      ? 'https://drive.google.com/thumbnail?id=$driveId&sz=w1200'
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

  AlbumNode({
    required this.id,
    required this.name,
    this.parentId,
    required this.isFolder,
    required this.directCount,
    required this.totalCount,
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
  int _currentIndex = 0; // For Photos: 0 = Albums, 1 = Années, 2 = Recherche
  final List<AlbumNode> _navHistory = [];
  String _albumSearch = '';
  final TextEditingController _albumSearchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCatalog();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppUpdateService.checkAndPrompt(context);
    });
  }

  Future<void> _loadCatalog() async {
    try {
      final jsonString = await rootBundle.loadString('assets/data/catalog.json');
      final data = json.decode(jsonString) as Map<String, dynamic>;

      _gdriveUrl = data['gdrive_url'] ?? _gdriveUrl;

      final rawAlbums = data['albums'] as List<dynamic>;
      final albumsList = rawAlbums.map((e) => AlbumNode.fromJson(e)).toList();

      _nodesById = {for (var a in albumsList) a.id: a};
      _childrenByParent = {};
      for (var a in albumsList) {
        _childrenByParent.putIfAbsent(a.parentId, () => []).add(a);
      }

      for (var list in _childrenByParent.values) {
        list.sort((a, b) {
          if (a.isFolder != b.isFolder) {
            return a.isFolder ? -1 : 1;
          }
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
      }

      final rawYears = data['years'] as List<dynamic>;
      _photoYears = rawYears.map((e) => YearItem.fromJson(e)).toList();

      final rawVideoYears = (data['video_years'] as List<dynamic>?) ?? [];
      _videoYears = rawVideoYears.map((e) => YearItem.fromJson(e)).toList();

      final rawPhotos = data['photos'] as List<dynamic>;
      _allPhotos = rawPhotos.map((e) => PhotoItem.fromJson(e)).toList();

      _photosOnly = _allPhotos.where((p) => !p.isVideo).toList();
      _videosOnly = _allPhotos.where((p) => p.isVideo).toList();
    } catch (e) {
      debugPrint("Error loading catalog: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
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
                  "${photos.length} ${isVideo ? 'vidéos' : 'photos'} • Google Drive HD",
                  style: const TextStyle(fontSize: 11, color: Colors.white54),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return PhotoGridBody(
      photos: photos,
      nodesById: _nodesById,
      gdriveUrl: _gdriveUrl,
      header: header,
    );
  }

  // --- PHOTOS: Lightroom Thematics Tab ---
  Widget _buildAlbumsTab() {
    final currentParentId = _navHistory.isEmpty ? null : _navHistory.last.id;
    final currentChildren = _childrenByParent[currentParentId] ?? [];

    final filtered = _albumSearch.isEmpty
        ? currentChildren
        : _nodesById.values.where((a) => a.name.toLowerCase().contains(_albumSearch.toLowerCase())).toList();

    return Column(
      children: [
        // Breadcrumb bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          color: const Color(0xFF0F172A),
          child: Row(
            children: [
              if (_navHistory.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.arrow_back, size: 20, color: Color(0xFF38BDF8)),
                  onPressed: () => setState(() => _navHistory.removeLast()),
                  tooltip: "Retour au dossier parent",
                ),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      InkWell(
                        onTap: () => setState(() => _navHistory.clear()),
                        child: Text(
                          "Racine",
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: _navHistory.isEmpty ? FontWeight.bold : FontWeight.normal,
                            color: _navHistory.isEmpty ? const Color(0xFF38BDF8) : Colors.white60,
                          ),
                        ),
                      ),
                      for (int i = 0; i < _navHistory.length; i++) ...[
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4),
                          child: Icon(Icons.chevron_right, size: 16, color: Colors.white30),
                        ),
                        InkWell(
                          onTap: () => setState(() {
                            while (_navHistory.length > i + 1) {
                              _navHistory.removeLast();
                            }
                          }),
                          child: Text(
                            _navHistory[i].name,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: i == _navHistory.length - 1 ? FontWeight.bold : FontWeight.normal,
                              color: i == _navHistory.length - 1 ? const Color(0xFF38BDF8) : Colors.white60,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // Search in albums
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _albumSearchController,
            decoration: InputDecoration(
              hintText: _albumSearch.isEmpty && _navHistory.isNotEmpty
                  ? "Filtrer dans ${_navHistory.last.name}..."
                  : "Rechercher une thématique...",
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _albumSearch.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _albumSearchController.clear();
                        setState(() => _albumSearch = '');
                      },
                    )
                  : null,
              filled: true,
              fillColor: const Color(0xFF1E293B),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
            ),
            onChanged: (val) => setState(() => _albumSearch = val),
          ),
        ),

        // "Toutes les photos" at root level
        if (_navHistory.isEmpty && _albumSearch.isEmpty) ...[
          ListTile(
            tileColor: const Color(0xFF1E293B).withValues(alpha: 0.6),
            leading: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFF0284C7).withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.photo_library_outlined, color: Color(0xFF38BDF8), size: 24),
            ),
            title: const Text("Toutes les photos", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            subtitle: const Text("Dernières photos créées en tête (Maroc 10/2026)", style: TextStyle(fontSize: 11, color: Colors.white54)),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF0284C7).withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                "${_photosOnly.length}",
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF38BDF8)),
              ),
            ),
            onTap: () {
              setState(() => _currentIndex = 0);
            },
          ),
          const Divider(height: 1, color: Colors.white10),
        ],

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
                    final hasChildren = (_childrenByParent[node.id] ?? []).isNotEmpty;

                    return ListTile(
                      leading: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          node.isFolder ? Icons.folder_outlined : Icons.photo_library_outlined,
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
                        node.isFolder
                            ? "${node.totalCount} photos cumulées"
                            : "${node.directCount} photos",
                        style: const TextStyle(fontSize: 11, color: Colors.white54),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (node.isFolder && node.totalCount > 0)
                            IconButton(
                              icon: const Icon(Icons.grid_view, size: 18, color: Colors.white38),
                              tooltip: "Voir toutes les photos du dossier",
                              onPressed: () => _openPhotosForNode(node),
                            ),
                          if (hasChildren)
                            const Icon(Icons.chevron_right, size: 20, color: Colors.white38),
                        ],
                      ),
                      onTap: () {
                        if (hasChildren) {
                          setState(() {
                            _navHistory.add(node);
                            _albumSearch = '';
                            _albumSearchController.clear();
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
        ),
      ),
    );
  }

  // --- PHOTOS: Years Tab ---
  Widget _buildPhotoYearsTab() {
    return ListView.builder(
      itemCount: _photoYears.length,
      itemBuilder: (context, idx) {
        final year = _photoYears[idx];
        final label = year.year == 'unknown_date' ? 'Photos sans date' : "Année ${year.year}";
        return ListTile(
          leading: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.date_range_outlined, color: Color(0xFF38BDF8), size: 22),
          ),
          title: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text("${year.count}", style: const TextStyle(fontSize: 11, color: Colors.white70)),
          ),
          onTap: () {
            final yearPhotos = _photosOnly.where((p) => p.year == year.year).toList();
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PhotoGridScreen(
                  title: label,
                  photos: yearPhotos,
                  nodesById: _nodesById,
                  gdriveUrl: _gdriveUrl,
                ),
              ),
            );
          },
        );
      },
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
    );
  }
}

class PhotoGridScreen extends StatelessWidget {
  final String title;
  final List<PhotoItem> photos;
  final Map<String, AlbumNode> nodesById;
  final String gdriveUrl;

  const PhotoGridScreen({
    super.key,
    required this.title,
    required this.photos,
    required this.nodesById,
    required this.gdriveUrl,
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
      ),
    );
  }
}

class PhotoGridBody extends StatelessWidget {
  final List<PhotoItem> photos;
  final Map<String, AlbumNode> nodesById;
  final String gdriveUrl;
  final Widget? header;

  const PhotoGridBody({
    super.key,
    required this.photos,
    required this.nodesById,
    required this.gdriveUrl,
    this.header,
  });

  @override
  Widget build(BuildContext context) {
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = (constraints.maxWidth / 130).clamp(2, 10).toInt();
        return Column(
          children: [
            if (header != null) header!,
            Expanded(
              child: GridView.builder(
            padding: const EdgeInsets.all(8),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 6,
              mainAxisSpacing: 6,
            ),
            itemCount: photos.length,
            itemBuilder: (context, idx) {
              final photo = photos[idx];
              final hasThumb = photo.thumbnailUrl != null;

              return InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => _openLightbox(context, photo),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white10),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (hasThumb)
                        Image.network(
                          photo.thumbnailUrl!,
                          fit: BoxFit.cover,
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
                          bottom: 20,
                          right: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
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
                                Text("Vidéo", style: TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                      if (photo.driveId == null)
                        Positioned(
                          top: 4,
                          left: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
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
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                          color: Colors.black.withValues(alpha: 0.65),
                          child: Text(
                            photo.filename,
                            style: const TextStyle(fontSize: 9, color: Colors.white70),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  void _openLightbox(BuildContext context, PhotoItem photo) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        final photoAlbumNames = photo.albums
            .map((id) => nodesById[id]?.name)
            .where((name) => name != null)
            .cast<String>()
            .toList();
        final sizeMo = (photo.fileSize / (1024 * 1024)).toStringAsFixed(1);
        final fileViewUrl = photo.getDriveViewUrl(gdriveUrl);

        return DraggableScrollableSheet(
          initialChildSize: 0.7,
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
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      constraints: const BoxConstraints(maxHeight: 260),
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
                            ),
                        ],
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
                Text("Statut Drive : ${photo.driveId != null ? '✔ Synchronisé en HD' : '⏳ Non chargé sur Drive'}",
                    style: TextStyle(fontSize: 12, color: photo.driveId != null ? const Color(0xFF4ADE80) : const Color(0xFFFBBF24))),
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
                  const SizedBox(height: 24),
                ],
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
                  onPressed: () async {
                    final uri = Uri.parse(fileViewUrl);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class PhotoSearchScreen extends StatefulWidget {
  final List<PhotoItem> allPhotos;
  final Map<String, AlbumNode> nodesById;
  final String gdriveUrl;

  const PhotoSearchScreen({
    super.key,
    required this.allPhotos,
    required this.nodesById,
    required this.gdriveUrl,
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
                    ),
        ),
      ],
    );
  }
}
