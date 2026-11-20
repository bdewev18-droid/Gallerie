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
  final String? camera;
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
    this.camera,
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
      camera: json['c'] as String?,
      albums: (json['al'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
    );
  }
}

class AlbumItem {
  final String id;
  final String name;
  final String? parentId;
  final int count;

  AlbumItem({
    required this.id,
    required this.name,
    this.parentId,
    required this.count,
  });

  factory AlbumItem.fromJson(Map<String, dynamic> json) {
    return AlbumItem(
      id: json['id'] as String,
      name: json['name'] as String,
      parentId: json['parent_id'] as String?,
      count: json['photo_count'] as int? ?? 0,
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
  List<AlbumItem> _albums = [];
  List<YearItem> _years = [];
  Map<String, String> _albumNames = {};

  int _currentIndex = 0;
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
      _albums = rawAlbums.map((e) => AlbumItem.fromJson(e)).toList();
      _albumNames = {for (var a in _albums) a.id: a.name};

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
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.bookmark_outline),
            selectedIcon: const Icon(Icons.bookmark, color: Color(0xFF38BDF8)),
            label: "Albums (${_albums.length})",
          ),
          const NavigationDestination(
            icon: Icon(Icons.calendar_today_outlined),
            selectedIcon: Icon(Icons.calendar_today, color: Color(0xFF38BDF8)),
            label: "Années",
          ),
          const NavigationDestination(
            icon: Icon(Icons.search),
            selectedIcon: Icon(Icons.search, color: Color(0xFF38BDF8)),
            label: "Recherche",
          ),
        ],
      ),
    );
  }

  Widget _buildAlbumsTab() {
    final filtered = _albumSearch.isEmpty
        ? _albums
        : _albums.where((a) => a.name.toLowerCase().contains(_albumSearch.toLowerCase())).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _albumSearchController,
            decoration: InputDecoration(
              hintText: "Filtrer les albums...",
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
        Expanded(
          child: ListView.builder(
            itemCount: filtered.length,
            itemBuilder: (context, idx) {
              final album = filtered[idx];
              return ListTile(
                leading: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.photo_album_outlined, color: Color(0xFF38BDF8), size: 22),
                ),
                title: Text(album.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text("${album.count}", style: const TextStyle(fontSize: 11, color: Colors.white70)),
                ),
                onTap: () {
                  final albumPhotos = _allPhotos.where((p) => p.albums.contains(album.id)).toList();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PhotoGridScreen(
                        title: album.name,
                        photos: albumPhotos,
                        albumNames: _albumNames,
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
                  albumNames: _albumNames,
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
      albumNames: _albumNames,
      gdriveUrl: _gdriveUrl,
    );
  }
}

class PhotoGridScreen extends StatelessWidget {
  final String title;
  final List<PhotoItem> photos;
  final Map<String, String> albumNames;
  final String gdriveUrl;

  const PhotoGridScreen({
    super.key,
    required this.title,
    required this.photos,
    required this.albumNames,
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
                      const Center(
                        child: Icon(Icons.image_outlined, color: Colors.white24, size: 28),
                      ),
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          color: Colors.black.withValues(alpha: 0.6),
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
        final photoAlbumNames = photo.albums.map((id) => albumNames[id] ?? id).toList();
        final sizeMo = (photo.fileSize / (1024 * 1024)).toStringAsFixed(1);

        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.9,
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
                Text(photo.filename, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text("Date : ${photo.captureDate.isNotEmpty ? photo.captureDate : 'Non renseignée'}",
                    style: const TextStyle(fontSize: 12, color: Colors.white70)),
                if (photo.camera != null)
                  Text("Appareil : ${photo.camera}", style: const TextStyle(fontSize: 12, color: Colors.white70)),
                Text("Résolution : ${photo.width} × ${photo.height} px ($sizeMo Mo)",
                    style: const TextStyle(fontSize: 12, color: Colors.white70)),
                const SizedBox(height: 16),
                const Text("Albums Lightroom :", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white70)),
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
                  label: const Text("Ouvrir sur Google Drive HD"),
                  onPressed: () async {
                    final uri = Uri.parse(gdriveUrl);
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
  final Map<String, String> albumNames;
  final String gdriveUrl;

  const PhotoSearchScreen({
    super.key,
    required this.allPhotos,
    required this.albumNames,
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
          if (p.camera != null && p.camera!.toLowerCase().contains(_query)) return true;
          for (var albId in p.albums) {
            final albName = widget.albumNames[albId];
            if (albName != null && albName.toLowerCase().contains(_query)) return true;
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
              hintText: "Recherche (mot-clé, album, date, Canon...)",
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
                      albumNames: widget.albumNames,
                      gdriveUrl: widget.gdriveUrl,
                    ),
        ),
      ],
    );
  }
}
