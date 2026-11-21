import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const GallerieApp());
}

class GallerieApp extends StatelessWidget {
  const GallerieApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lightroom & Drive Gallery',
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
  final String? driveId;
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
    this.driveId,
    required this.albums,
  });

  factory PhotoItem.fromJson(Map<String, dynamic> json) {
    return PhotoItem(
      id: json['id'] as int,
      filename: json['fn'] as String,
      year: json['y'] as String,
      dateFolder: json['d'] as String? ?? '',
      captureDate: json['dt'] as String? ?? '',
      width: json['w'] as int? ?? 0,
      height: json['h'] as int? ?? 0,
      fileSize: json['s'] as int? ?? 0,
      driveId: json['gid'] as String?,
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
    return AlbumNode(
      id: json['id'] as String,
      name: json['name'] as String,
      parentId: json['parent_id'] as String?,
      isFolder: json['is_folder'] as bool? ?? false,
      directCount: json['direct_count'] as int? ?? 0,
      totalCount: json['count'] as int? ?? 0,
    );
  }
}

class YearItem {
  final String year;
  final int count;

  YearItem({required this.year, required this.count});

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
  Map<String, AlbumNode> _nodesById = {};
  Map<String?, List<AlbumNode>> _childrenByParent = {};
  List<YearItem> _years = [];

  int _currentIndex = 0;
  final List<AlbumNode> _navHistory = [];
  String _albumSearch = '';
  final TextEditingController _albumSearchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCatalog();
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
      _years = rawYears.map((e) => YearItem.fromJson(e)).toList();

      final rawPhotos = data['photos'] as List<dynamic>;
      _allPhotos = rawPhotos.map((e) => PhotoItem.fromJson(e)).toList();
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
              Text("Chargement de la bibliothèque...", style: TextStyle(color: Colors.white70)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        title: Row(
          children: [
            const Icon(Icons.photo_library_outlined, color: Color(0xFF38BDF8), size: 22),
            const SizedBox(width: 8),
            const Text("Gallerie", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const Spacer(),
            Text("${_allPhotos.length} photos", style: const TextStyle(fontSize: 12, color: Colors.white54)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: "Ouvrir Google Drive HD",
            icon: const Icon(Icons.cloud_outlined, color: Color(0xFF38BDF8)),
            onPressed: () => _openUrl(_gdriveUrl),
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildAlbumsTab(),
          _buildYearsTab(),
          _buildSearchTab(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
        backgroundColor: const Color(0xFF0F172A),
        indicatorColor: const Color(0xFF0284C7).withValues(alpha: 0.3),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.folder_outlined),
            selectedIcon: Icon(Icons.folder, color: Color(0xFF38BDF8)),
            label: "Albums & Dossiers",
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
                  : "Rechercher un dossier ou album...",
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

        if (_navHistory.isNotEmpty && _navHistory.last.totalCount > 0 && _albumSearch.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: InkWell(
              onTap: () => _openPhotosForNode(_navHistory.last),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF0284C7).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF0284C7).withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.photo_library, size: 18, color: Color(0xFF38BDF8)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "Afficher toutes les photos de ${_navHistory.last.name}",
                        style: const TextStyle(fontSize: 12, color: Color(0xFF38BDF8), fontWeight: FontWeight.w600),
                      ),
                    ),
                    Text(
                      "${_navHistory.last.totalCount} photos",
                      style: const TextStyle(fontSize: 11, color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ),
          ),

        Expanded(
          child: ListView.builder(
            itemCount: filtered.length,
            itemBuilder: (context, idx) {
              final node = filtered[idx];
              final isFolder = node.isFolder;

              return ListTile(
                leading: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: isFolder
                        ? const Color(0xFF0284C7).withValues(alpha: 0.15)
                        : const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isFolder ? Icons.folder : Icons.photo_album_outlined,
                    color: isFolder ? const Color(0xFF38BDF8) : Colors.white70,
                    size: 22,
                  ),
                ),
                title: Text(node.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                subtitle: isFolder
                    ? Text("Dossier (${node.totalCount} photos)", style: const TextStyle(fontSize: 11, color: Colors.white54))
                    : Text("Album (${node.directCount} photos)", style: const TextStyle(fontSize: 11, color: Colors.white54)),
                trailing: isFolder
                    ? const Icon(Icons.chevron_right, size: 18, color: Colors.white30)
                    : Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text("${node.totalCount}", style: const TextStyle(fontSize: 11, color: Colors.white70)),
                      ),
                onTap: () {
                  if (isFolder) {
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

  void _openPhotosForNode(AlbumNode node) {
    final albumPhotos = _allPhotos.where((p) => p.albums.contains(node.id)).toList();
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

  Widget _buildYearsTab() {
    return ListView.builder(
      itemCount: _years.length,
      itemBuilder: (context, idx) {
        final year = _years[idx];
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
            final yearPhotos = _allPhotos.where((p) => p.year == year.year).toList();
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

  Widget _buildSearchTab() {
    return PhotoSearchScreen(
      allPhotos: _allPhotos,
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
            Text("${photos.length} photos", style: const TextStyle(fontSize: 11, color: Colors.white54)),
          ],
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final crossAxisCount = (constraints.maxWidth / 120).clamp(2, 6).toInt();
          return GridView.builder(
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
                            return const Center(
                              child: Icon(Icons.image_outlined, color: Colors.white24, size: 28),
                            );
                          },
                        )
                      else
                        const Center(
                          child: Icon(Icons.cloud_upload_outlined, color: Colors.white24, size: 28),
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
          );
        },
      ),
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
                      child: Image.network(
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
                    ),
                  ),
                const SizedBox(height: 16),
                Text(photo.filename, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text("Date : ${photo.captureDate.isNotEmpty ? photo.captureDate : 'Non renseignée'}",
                    style: const TextStyle(fontSize: 12, color: Colors.white70)),
                Text("Dimensions : ${photo.width} × ${photo.height} px ($sizeMo Mo)",
                    style: const TextStyle(fontSize: 12, color: Colors.white70)),
                const SizedBox(height: 16),
                const Text("Dossiers & Albums Lightroom :", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white70)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: photoAlbumNames.isEmpty
                      ? [const Text("Aucun album spécifique", style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.white38))]
                      : photoAlbumNames
                          .map((name) => Chip(
                                label: Text(name, style: const TextStyle(fontSize: 10)),
                                backgroundColor: const Color(0xFF1E293B),
                                padding: EdgeInsets.zero,
                              ))
                          .toList(),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0284C7),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.cloud_download_outlined, size: 18),
                  label: Text(photo.driveId != null ? "Ouvrir l'original HD sur Google Drive" : "Ouvrir le dossier Google Drive"),
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
  String _query = '';
  List<PhotoItem> _results = [];

  void _onSearch(String q) {
    setState(() {
      _query = q.trim().toLowerCase();
      if (_query.isEmpty) {
        _results = [];
      } else {
        _results = widget.allPhotos.where((p) {
          if (p.filename.toLowerCase().contains(_query)) return true;
          if (p.year.contains(_query)) return true;
          if (p.dateFolder.toLowerCase().contains(_query)) return true;
          for (var albId in p.albums) {
            final albNode = widget.nodesById[albId];
            if (albNode != null && albNode.name.toLowerCase().contains(_query)) return true;
          }
          return false;
        }).take(200).toList();
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
            decoration: InputDecoration(
              hintText: "Recherche globale (Espagne, Chloé, 2024, Mariage...)",
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: const Color(0xFF1E293B),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
            onChanged: _onSearch,
          ),
        ),
        if (_query.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Text("${_results.length} résultat(s)", style: const TextStyle(fontSize: 12, color: Colors.white54)),
              ],
            ),
          ),
        Expanded(
          child: _query.isEmpty
              ? const Center(
                  child: Text("Tapez un mot-clé pour lancer la recherche...", style: TextStyle(color: Colors.white38)),
                )
              : _results.isEmpty
                  ? const Center(child: Text("Aucun résultat trouvé", style: TextStyle(color: Colors.white38)))
                  : PhotoGridScreen(
                      title: "Recherche : $_query",
                      photos: _results,
                      nodesById: widget.nodesById,
                      gdriveUrl: widget.gdriveUrl,
                    ),
        ),
      ],
    );
  }
}
