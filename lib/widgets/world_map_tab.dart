import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

class WorldCountryMeta {
  final String iso3;
  final String nameFr;
  final String flag;
  final String continent;
  final List<String> aliases;

  const WorldCountryMeta({
    required this.iso3,
    required this.nameFr,
    required this.flag,
    required this.continent,
    this.aliases = const [],
  });
}

class CountryAlbumSummary {
  final String albumId;
  final String name;
  final String? dateHint;
  final int photoCount;
  final int videoCount;
  final bool isFolder;

  const CountryAlbumSummary({
    required this.albumId,
    required this.name,
    this.dateHint,
    required this.photoCount,
    required this.videoCount,
    this.isFolder = false,
  });
}

class CountryVisitStats {
  final WorldCountryMeta meta;
  final int photoCount;
  final int videoCount;
  final List<CountryAlbumSummary> albums;

  const CountryVisitStats({
    required this.meta,
    required this.photoCount,
    required this.videoCount,
    required this.albums,
  });

  int get totalMedia => photoCount + videoCount;
}

const List<WorldCountryMeta> kWorldCountries = [
  WorldCountryMeta(iso3: 'AFG', nameFr: 'Afghanistan', flag: '🇦🇫', continent: 'Asie'),
  WorldCountryMeta(iso3: 'ZAF', nameFr: 'Afrique du Sud', flag: '🇿🇦', continent: 'Afrique', aliases: ['South Africa']),
  WorldCountryMeta(iso3: 'ALB', nameFr: 'Albanie', flag: '🇦🇱', continent: 'Europe', aliases: ['Albania']),
  WorldCountryMeta(iso3: 'DZA', nameFr: 'Algérie', flag: '🇩🇿', continent: 'Afrique', aliases: ['Algeria']),
  WorldCountryMeta(iso3: 'DEU', nameFr: 'Allemagne', flag: '🇩🇪', continent: 'Europe', aliases: ['Germany']),
  WorldCountryMeta(iso3: 'SAU', nameFr: 'Arabie saoudite', flag: '🇸🇦', continent: 'Asie', aliases: ['Saudi Arabia']),
  WorldCountryMeta(iso3: 'ARG', nameFr: 'Argentine', flag: '🇦🇷', continent: 'Amériques', aliases: ['Argentina']),
  WorldCountryMeta(iso3: 'ARM', nameFr: 'Arménie', flag: '🇦🇲', continent: 'Asie'),
  WorldCountryMeta(iso3: 'AUS', nameFr: 'Australie', flag: '🇦🇺', continent: 'Océanie', aliases: ['Australia']),
  WorldCountryMeta(iso3: 'AUT', nameFr: 'Autriche', flag: '🇦🇹', continent: 'Europe', aliases: ['Austria']),
  WorldCountryMeta(iso3: 'BEL', nameFr: 'Belgique', flag: '🇧🇪', continent: 'Europe', aliases: ['Belgium']),
  WorldCountryMeta(iso3: 'BOL', nameFr: 'Bolivie', flag: '🇧🇴', continent: 'Amériques'),
  WorldCountryMeta(iso3: 'BIH', nameFr: 'Bosnie-Herzégovine', flag: '🇧🇦', continent: 'Europe'),
  WorldCountryMeta(iso3: 'BRA', nameFr: 'Brésil', flag: '🇧🇷', continent: 'Amériques', aliases: ['Brazil', 'Bresil']),
  WorldCountryMeta(iso3: 'BGR', nameFr: 'Bulgarie', flag: '🇧🇬', continent: 'Europe', aliases: ['Bulgaria']),
  WorldCountryMeta(iso3: 'KHM', nameFr: 'Cambodge', flag: '🇰🇭', continent: 'Asie', aliases: ['Cambodia']),
  WorldCountryMeta(iso3: 'CMR', nameFr: 'Cameroun', flag: '🇨🇲', continent: 'Afrique'),
  WorldCountryMeta(iso3: 'CAN', nameFr: 'Canada', flag: '🇨🇦', continent: 'Amériques'),
  WorldCountryMeta(iso3: 'CPV', nameFr: 'Cap-Vert', flag: '🇨🇻', continent: 'Afrique', aliases: ['Cap Vert', 'Cape Verde']),
  WorldCountryMeta(iso3: 'CHL', nameFr: 'Chili', flag: '🇨🇱', continent: 'Amériques', aliases: ['Chile']),
  WorldCountryMeta(iso3: 'CHN', nameFr: 'Chine', flag: '🇨🇳', continent: 'Asie', aliases: ['China']),
  WorldCountryMeta(iso3: 'CYP', nameFr: 'Chypre', flag: '🇨🇾', continent: 'Europe', aliases: ['Cyprus']),
  WorldCountryMeta(iso3: 'COL', nameFr: 'Colombie', flag: '🇨🇴', continent: 'Amériques', aliases: ['Colombia']),
  WorldCountryMeta(iso3: 'KOR', nameFr: 'Corée du Sud', flag: '🇰🇷', continent: 'Asie', aliases: ['South Korea']),
  WorldCountryMeta(iso3: 'CRI', nameFr: 'Costa Rica', flag: '🇨🇷', continent: 'Amériques'),
  WorldCountryMeta(iso3: 'HRV', nameFr: 'Croatie', flag: '🇭🇷', continent: 'Europe', aliases: ['Croatia']),
  WorldCountryMeta(iso3: 'CUB', nameFr: 'Cuba', flag: '🇨🇺', continent: 'Amériques'),
  WorldCountryMeta(iso3: 'DNK', nameFr: 'Danemark', flag: '🇩🇰', continent: 'Europe', aliases: ['Denmark']),
  WorldCountryMeta(iso3: 'DOM', nameFr: 'République dominicaine', flag: '🇩🇴', continent: 'Amériques'),
  WorldCountryMeta(iso3: 'EGY', nameFr: 'Égypte', flag: '🇪🇬', continent: 'Afrique', aliases: ['Egypte', 'Egypt']),
  WorldCountryMeta(iso3: 'ARE', nameFr: 'Émirats arabes unis', flag: '🇦🇪', continent: 'Asie', aliases: ['Dubai', 'UAE']),
  WorldCountryMeta(iso3: 'ECU', nameFr: 'Équateur', flag: '🇪🇨', continent: 'Amériques'),
  WorldCountryMeta(iso3: 'ESP', nameFr: 'Espagne', flag: '🇪🇸', continent: 'Europe', aliases: ['Spain', 'Canaries', 'Grand Canaria', 'Baléares', 'Baleares', 'Tenerife', 'Majorque']),
  WorldCountryMeta(iso3: 'EST', nameFr: 'Estonie', flag: '🇪🇪', continent: 'Europe'),
  WorldCountryMeta(iso3: 'USA', nameFr: 'États-Unis', flag: '🇺🇸', continent: 'Amériques', aliases: ['Etats-Unis', 'USA', 'United States']),
  WorldCountryMeta(iso3: 'ETH', nameFr: 'Éthiopie', flag: '🇪🇹', continent: 'Afrique'),
  WorldCountryMeta(iso3: 'FIN', nameFr: 'Finlande', flag: '🇫🇮', continent: 'Europe', aliases: ['Finland']),
  WorldCountryMeta(iso3: 'FRA', nameFr: 'France', flag: '🇫🇷', continent: 'Europe', aliases: ['Loire', 'Paris', 'Vendée', 'Vendee', 'Corse', 'Bretagne']),
  WorldCountryMeta(iso3: 'GEO', nameFr: 'Géorgie', flag: '🇬🇪', continent: 'Asie'),
  WorldCountryMeta(iso3: 'GRC', nameFr: 'Grèce', flag: '🇬🇷', continent: 'Europe', aliases: ['Grece', 'Greece', 'Rhodes', 'Crète', 'Crete', 'Santorin']),
  WorldCountryMeta(iso3: 'GTM', nameFr: 'Guatemala', flag: '🇬🇹', continent: 'Amériques'),
  WorldCountryMeta(iso3: 'HUN', nameFr: 'Hongrie', flag: '🇭🇺', continent: 'Europe', aliases: ['Hungary']),
  WorldCountryMeta(iso3: 'IND', nameFr: 'Inde', flag: '🇮🇳', continent: 'Asie', aliases: ['India']),
  WorldCountryMeta(iso3: 'IDN', nameFr: 'Indonésie', flag: '🇮🇩', continent: 'Asie', aliases: ['Indonesia', 'Bali']),
  WorldCountryMeta(iso3: 'IRL', nameFr: 'Irlande', flag: '🇮🇪', continent: 'Europe', aliases: ['Ireland']),
  WorldCountryMeta(iso3: 'ISL', nameFr: 'Islande', flag: '🇮🇸', continent: 'Europe', aliases: ['Iceland']),
  WorldCountryMeta(iso3: 'ISR', nameFr: 'Israël', flag: '🇮🇱', continent: 'Asie'),
  WorldCountryMeta(iso3: 'ITA', nameFr: 'Italie', flag: '🇮🇹', continent: 'Europe', aliases: ['Italy', 'Rome', 'Venise', 'Sicile']),
  WorldCountryMeta(iso3: 'JPN', nameFr: 'Japon', flag: '🇯🇵', continent: 'Asie', aliases: ['Japan']),
  WorldCountryMeta(iso3: 'JOR', nameFr: 'Jordanie', flag: '🇯🇴', continent: 'Asie', aliases: ['Jordan']),
  WorldCountryMeta(iso3: 'KEN', nameFr: 'Kenya', flag: '🇰🇪', continent: 'Afrique'),
  WorldCountryMeta(iso3: 'LVA', nameFr: 'Lettonie', flag: '🇱🇻', continent: 'Europe'),
  WorldCountryMeta(iso3: 'LBN', nameFr: 'Liban', flag: '🇱🇧', continent: 'Asie'),
  WorldCountryMeta(iso3: 'LTU', nameFr: 'Lituanie', flag: '🇱🇹', continent: 'Europe'),
  WorldCountryMeta(iso3: 'LUX', nameFr: 'Luxembourg', flag: '🇱🇺', continent: 'Europe'),
  WorldCountryMeta(iso3: 'MDG', nameFr: 'Madagascar', flag: '🇲🇬', continent: 'Afrique'),
  WorldCountryMeta(iso3: 'MYS', nameFr: 'Malaisie', flag: '🇲🇾', continent: 'Asie', aliases: ['Malaysia']),
  WorldCountryMeta(iso3: 'MDV', nameFr: 'Maldives', flag: '🇲🇻', continent: 'Asie'),
  WorldCountryMeta(iso3: 'MLT', nameFr: 'Malte', flag: '🇲🇹', continent: 'Europe', aliases: ['Malta']),
  WorldCountryMeta(iso3: 'MAR', nameFr: 'Maroc', flag: '🇲🇦', continent: 'Afrique', aliases: ['Morocco']),
  WorldCountryMeta(iso3: 'MUS', nameFr: 'Île Maurice', flag: '🇲🇺', continent: 'Afrique', aliases: ['Maurice', 'Mauritius']),
  WorldCountryMeta(iso3: 'MEX', nameFr: 'Mexique', flag: '🇲🇽', continent: 'Amériques', aliases: ['Mexico']),
  WorldCountryMeta(iso3: 'MNE', nameFr: 'Monténégro', flag: '🇲🇪', continent: 'Europe'),
  WorldCountryMeta(iso3: 'NAM', nameFr: 'Namibie', flag: '🇳🇦', continent: 'Afrique'),
  WorldCountryMeta(iso3: 'NPL', nameFr: 'Népal', flag: '🇳🇵', continent: 'Asie'),
  WorldCountryMeta(iso3: 'NOR', nameFr: 'Norvège', flag: '🇳🇴', continent: 'Europe', aliases: ['Norway']),
  WorldCountryMeta(iso3: 'NZL', nameFr: 'Nouvelle-Zélande', flag: '🇳🇿', continent: 'Océanie', aliases: ['New Zealand']),
  WorldCountryMeta(iso3: 'OMN', nameFr: 'Oman', flag: '🇴🇲', continent: 'Asie'),
  WorldCountryMeta(iso3: 'UZB', nameFr: 'Ouzbékistan', flag: '🇺🇿', continent: 'Asie'),
  WorldCountryMeta(iso3: 'PAN', nameFr: 'Panama', flag: '🇵🇦', continent: 'Amériques'),
  WorldCountryMeta(iso3: 'PRY', nameFr: 'Paraguay', flag: '🇵🇾', continent: 'Amériques'),
  WorldCountryMeta(iso3: 'NLD', nameFr: 'Pays-Bas', flag: '🇳🇱', continent: 'Europe', aliases: ['Netherlands', 'Hollande', 'Amsterdam']),
  WorldCountryMeta(iso3: 'PER', nameFr: 'Pérou', flag: '🇵🇪', continent: 'Amériques', aliases: ['Peru']),
  WorldCountryMeta(iso3: 'PHL', nameFr: 'Philippines', flag: '🇵🇭', continent: 'Asie'),
  WorldCountryMeta(iso3: 'POL', nameFr: 'Pologne', flag: '🇵🇱', continent: 'Europe', aliases: ['Poland']),
  WorldCountryMeta(iso3: 'PRT', nameFr: 'Portugal', flag: '🇵🇹', continent: 'Europe', aliases: ['Madère', 'Madere', 'Lisbonne']),
  WorldCountryMeta(iso3: 'QAT', nameFr: 'Qatar', flag: '🇶🇦', continent: 'Asie'),
  WorldCountryMeta(iso3: 'ROU', nameFr: 'Roumanie', flag: '🇷🇴', continent: 'Europe', aliases: ['Romania']),
  WorldCountryMeta(iso3: 'GBR', nameFr: 'Royaume-Uni', flag: '🇬🇧', continent: 'Europe', aliases: ['Angleterre', 'United Kingdom', 'UK', 'Ecosse', 'Londres', 'England']),
  WorldCountryMeta(iso3: 'RUS', nameFr: 'Russie', flag: '🇷🇺', continent: 'Europe', aliases: ['Russia']),
  WorldCountryMeta(iso3: 'SEN', nameFr: 'Sénégal', flag: '🇸🇳', continent: 'Afrique', aliases: ['Senegal']),
  WorldCountryMeta(iso3: 'SRB', nameFr: 'Serbie', flag: '🇷🇸', continent: 'Europe'),
  WorldCountryMeta(iso3: 'SYC', nameFr: 'Seychelles', flag: '🇸🇨', continent: 'Afrique'),
  WorldCountryMeta(iso3: 'SGP', nameFr: 'Singapour', flag: '🇸🇬', continent: 'Asie', aliases: ['Singapore']),
  WorldCountryMeta(iso3: 'SVK', nameFr: 'Slovaquie', flag: '🇸🇰', continent: 'Europe'),
  WorldCountryMeta(iso3: 'SVN', nameFr: 'Slovénie', flag: '🇸🇮', continent: 'Europe'),
  WorldCountryMeta(iso3: 'LKA', nameFr: 'Sri Lanka', flag: '🇱🇰', continent: 'Asie'),
  WorldCountryMeta(iso3: 'SWE', nameFr: 'Suède', flag: '🇸🇪', continent: 'Europe', aliases: ['Sweden']),
  WorldCountryMeta(iso3: 'CHE', nameFr: 'Suisse', flag: '🇨🇭', continent: 'Europe', aliases: ['Switzerland']),
  WorldCountryMeta(iso3: 'TZA', nameFr: 'Tanzanie', flag: '🇹🇿', continent: 'Afrique', aliases: ['Zanzibar']),
  WorldCountryMeta(iso3: 'CZE', nameFr: 'Tchéquie', flag: '🇨🇿', continent: 'Europe', aliases: ['Prague', 'Czechia']),
  WorldCountryMeta(iso3: 'THA', nameFr: 'Thaïlande', flag: '🇹🇭', continent: 'Asie', aliases: ['Thailand']),
  WorldCountryMeta(iso3: 'TUN', nameFr: 'Tunisie', flag: '🇹🇳', continent: 'Afrique', aliases: ['Tunisia', 'Djerba']),
  WorldCountryMeta(iso3: 'TUR', nameFr: 'Turquie', flag: '🇹🇷', continent: 'Asie', aliases: ['Turkey']),
  WorldCountryMeta(iso3: 'UKR', nameFr: 'Ukraine', flag: '🇺🇦', continent: 'Europe'),
  WorldCountryMeta(iso3: 'URY', nameFr: 'Uruguay', flag: '🇺🇾', continent: 'Amériques'),
  WorldCountryMeta(iso3: 'VNM', nameFr: 'Viêt Nam', flag: '🇻🇳', continent: 'Asie', aliases: ['Vietnam', 'Viet Nam']),
];

String normalizeCountryKey(String input) {
  const from = 'àáâãäåçèéêëìíîïñòóôõöùúûüýÿÀÁÂÃÄÅÇÈÉÊËÌÍÎÏÑÒÓÔÕÖÙÚÛÜÝŸ';
  const to = 'aaaaaaceeeeiiiinooooouuuuyyAAAAAACEEEEIIIINOOOOOUUUUYY';
  var s = input.trim().toLowerCase();
  for (var i = 0; i < from.length; i++) {
    s = s.replaceAll(from[i], to[i].toLowerCase());
  }
  return s.replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
}

final Map<String, WorldCountryMeta> kCountriesByIso = {
  for (final c in kWorldCountries) c.iso3: c,
};

WorldCountryMeta? matchCountryMeta(String rawName) {
  final norm = normalizeCountryKey(rawName);
  if (norm.isEmpty) return null;

  // 1. Exact name or alias match
  for (final c in kWorldCountries) {
    if (normalizeCountryKey(c.nameFr) == norm) return c;
    for (final a in c.aliases) {
      if (normalizeCountryKey(a) == norm) return c;
    }
  }
  // 2. Prefix or token match (e.g. "Spain - Grand Canaria", "Grèce - Rhodes", "France - Paris")
  final firstSegment = normalizeCountryKey(rawName.split(RegExp(r'[-–—(:]')).first);
  if (firstSegment.isNotEmpty) {
    for (final c in kWorldCountries) {
      if (normalizeCountryKey(c.nameFr) == firstSegment) return c;
      for (final a in c.aliases) {
        if (normalizeCountryKey(a) == firstSegment) return c;
      }
    }
  }
  // 3. Substring match on normalized words
  for (final c in kWorldCountries) {
    final cNorm = normalizeCountryKey(c.nameFr);
    if (cNorm.length >= 4 && norm.contains(cNorm)) return c;
    for (final a in c.aliases) {
      final aNorm = normalizeCountryKey(a);
      if (aNorm.length >= 4 && norm.contains(aNorm)) return c;
    }
  }
  return null;
}

class _CountryGeoShape {
  final String iso3;
  final String name;
  final Offset centerNorm; // normalized [0..1, 0..1]
  final List<List<Offset>> polygonsNorm;

  const _CountryGeoShape({
    required this.iso3,
    required this.name,
    required this.centerNorm,
    required this.polygonsNorm,
  });
}

class WorldMapTab extends StatefulWidget {
  final List<CountryVisitStats> visitedCountries;
  final int totalPhotos;
  final int totalVideos;
  final VoidCallback onAddCountryFolder;
  final void Function(String albumId) onOpenAlbum;
  final void Function(CountryVisitStats stats) onOpenCountryMedia;

  const WorldMapTab({
    super.key,
    required this.visitedCountries,
    required this.totalPhotos,
    required this.totalVideos,
    required this.onAddCountryFolder,
    required this.onOpenAlbum,
    required this.onOpenCountryMedia,
  });

  @override
  State<WorldMapTab> createState() => _WorldMapTabState();
}

class _WorldMapTabState extends State<WorldMapTab> {
  static List<_CountryGeoShape>? _cachedShapes;
  List<_CountryGeoShape>? _shapes;
  final TransformationController _transformController = TransformationController();
  String _selectedContinent = 'Monde';
  String? _highlightedIso;
  bool _showListMode = false;

  static const Size _mapCanvasSize = Size(1200, 620);

  @override
  void initState() {
    super.initState();
    _loadGeoJson();
  }

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  Future<void> _loadGeoJson() async {
    if (_cachedShapes != null) {
      setState(() => _shapes = _cachedShapes);
      return;
    }
    try {
      final raw = await rootBundle.loadString('assets/data/world_countries.json');
      final list = jsonDecode(raw) as List<dynamic>;
      final parsed = <_CountryGeoShape>[];
      for (final item in list) {
        final m = item as Map<String, dynamic>;
        final iso = m['id'] as String;
        final name = m['name'] as String;
        final center = m['center'] as List<dynamic>;
        final polysRaw = m['polygons'] as List<dynamic>;
        final polys = <List<Offset>>[];
        for (final pr in polysRaw) {
          final pts = (pr as List<dynamic>)
              .map((pt) => _project((pt[0] as num).toDouble(), (pt[1] as num).toDouble()))
              .toList();
          if (pts.length >= 3) polys.add(pts);
        }
        if (polys.isEmpty) continue;
        parsed.add(_CountryGeoShape(
          iso3: iso,
          name: name,
          centerNorm: _project((center[0] as num).toDouble(), (center[1] as num).toDouble()),
          polygonsNorm: polys,
        ));
      }
      _cachedShapes = parsed;
      if (mounted) setState(() => _shapes = parsed);
    } catch (_) {
      // Fallback empty shapes handled gracefully
    }
  }

  /// Equirectangular projection cropped to lat [-58..82] for cleaner framing
  static Offset _project(double lon, double lat) {
    final x = ((lon + 180.0) / 360.0).clamp(0.0, 1.0);
    final clampedLat = lat.clamp(-58.0, 82.0);
    final y = ((82.0 - clampedLat) / 140.0).clamp(0.0, 1.0);
    return Offset(x, y);
  }

  void _focusContinent(String continent, Size viewportSize) {
    setState(() => _selectedContinent = continent);
    if (_showListMode) return;
    if (continent == 'Monde') {
      _transformController.value = Matrix4.identity();
      return;
    }
    // Target normalized focal point and scale per continent
    final Offset normTarget;
    final double zoom;
    switch (continent) {
      case 'Europe':
        normTarget = _project(12, 48);
        zoom = 3.2;
        break;
      case 'Afrique':
        normTarget = _project(18, 6);
        zoom = 2.3;
        break;
      case 'Amériques':
        normTarget = _project(-72, 2);
        zoom = 1.9;
        break;
      case 'Asie':
        normTarget = _project(88, 30);
        zoom = 2.3;
        break;
      case 'Océanie':
        normTarget = _project(138, -24);
        zoom = 2.6;
        break;
      default:
        normTarget = const Offset(0.5, 0.5);
        zoom = 1.0;
    }
    final cx = normTarget.dx * viewportSize.width;
    final cy = normTarget.dy * viewportSize.height;
    final tx = viewportSize.width / 2 - cx * zoom;
    final ty = viewportSize.height / 2 - cy * zoom;
    final matrix = Matrix4.identity()
      ..translate(tx.clamp(-viewportSize.width * (zoom - 1), 0.0), ty.clamp(-viewportSize.height * (zoom - 1), 0.0))
      ..scale(zoom);
    _transformController.value = matrix;
  }

  bool _pointInPolygon(Offset p, List<Offset> poly) {
    var inside = false;
    for (int i = 0, j = poly.length - 1; i < poly.length; j = i++) {
      final xi = poly[i].dx, yi = poly[i].dy;
      final xj = poly[j].dx, yj = poly[j].dy;
      final intersect = ((yi > p.dy) != (yj > p.dy)) &&
          (p.dx < (xj - xi) * (p.dy - yi) / ((yj - yi) == 0 ? 1e-9 : (yj - yi)) + xi);
      if (intersect) inside = !inside;
    }
    return inside;
  }

  void _handleMapTap(TapUpDetails details, Size mapBoxSize, Map<String, CountryVisitStats> visitedByIso) {
    final shapes = _shapes;
    if (shapes == null) return;

    // Convert viewport tap to child coordinates via inverse matrix
    final inverse = Matrix4.inverted(_transformController.value);
    final scenePoint = MatrixUtils.transformPoint(inverse, details.localPosition);
    final normPoint = Offset(
      (scenePoint.dx / mapBoxSize.width).clamp(0.0, 1.0),
      (scenePoint.dy / mapBoxSize.height).clamp(0.0, 1.0),
    );

    // 1. Check visited country badge centers first (generous mobile touch target)
    final currentScale = _transformController.value.getMaxScaleOnAxis();
    final hitRadius = 0.025 / currentScale.clamp(1.0, 4.0);
    _CountryGeoShape? bestBadgeHit;
    double bestDist = double.infinity;
    for (final s in shapes) {
      if (!visitedByIso.containsKey(s.iso3)) continue;
      final d = (s.centerNorm - normPoint).distance;
      if (d <= hitRadius && d < bestDist) {
        bestDist = d;
        bestBadgeHit = s;
      }
    }
    if (bestBadgeHit != null) {
      _openCountryDetails(visitedByIso[bestBadgeHit.iso3]!);
      return;
    }

    // 2. Check polygon hit-testing (visited first, then unvisited)
    for (final s in shapes) {
      if (!visitedByIso.containsKey(s.iso3)) continue;
      for (final poly in s.polygonsNorm) {
        if (_pointInPolygon(normPoint, poly)) {
          _openCountryDetails(visitedByIso[s.iso3]!);
          return;
        }
      }
    }

    // 3. If tapped on an unvisited country, show a friendly snackbar with quick-add CTA
    for (final s in shapes) {
      for (final poly in s.polygonsNorm) {
        if (_pointInPolygon(normPoint, poly)) {
          final meta = kCountriesByIso[s.iso3];
          final label = meta != null ? '${meta.flag} ${meta.nameFr}' : s.name;
          setState(() => _highlightedIso = s.iso3);
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFF0F172A),
              behavior: SnackBarBehavior.floating,
              content: Text(
                '$label — aucun album ou média pour le moment',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
              action: SnackBarAction(
                label: 'Ajouter',
                textColor: const Color(0xFF38BDF8),
                onPressed: widget.onAddCountryFolder,
              ),
              duration: const Duration(seconds: 3),
            ),
          );
          return;
        }
      }
    }
  }

  void _openCountryDetails(CountryVisitStats stats) {
    setState(() => _highlightedIso = stats.meta.iso3);
    final isCompact = MediaQuery.of(context).size.width < 700;
    if (isCompact) {
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: const Color(0xFF0F172A),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) => DraggableScrollableSheet(
          initialChildSize: 0.56,
          minChildSize: 0.35,
          maxChildSize: 0.88,
          expand: false,
          builder: (_, scrollCtrl) => _buildCountryDetailBody(stats, scrollCtrl, ctx),
        ),
      );
    } else {
      showDialog<void>(
        context: context,
        builder: (ctx) => Dialog(
          backgroundColor: const Color(0xFF0F172A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Colors.white12),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480, maxHeight: 580),
            child: _buildCountryDetailBody(stats, ScrollController(), ctx),
          ),
        ),
      );
    }
  }

  Widget _buildCountryDetailBody(
    CountryVisitStats stats,
    ScrollController scrollCtrl,
    BuildContext sheetCtx,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 10),
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.white24,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFF0EA5E9).withOpacity(0.16),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.45)),
                ),
                alignment: Alignment.center,
                child: Text(stats.meta.flag, style: const TextStyle(fontSize: 28)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stats.meta.nameFr,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        _statChip(Icons.public_rounded, stats.meta.continent, const Color(0xFF94A3B8)),
                        _statChip(Icons.photo_library_outlined, '${stats.photoCount} photos', const Color(0xFF38BDF8)),
                        if (stats.videoCount > 0)
                          _statChip(Icons.videocam_outlined, '${stats.videoCount} vidéos', const Color(0xFFA78BFA)),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(sheetCtx).pop(),
                icon: const Icon(Icons.close, color: Colors.white54),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: Colors.white10),
        Expanded(
          child: ListView(
            controller: scrollCtrl,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            children: [
              Row(
                children: [
                  const Text(
                    'ALBUMS & DOSSIERS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
                      color: Colors.white54,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${stats.albums.length} ${stats.albums.length > 1 ? 'éléments' : 'élément'}',
                    style: const TextStyle(fontSize: 11, color: Colors.white38),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (stats.albums.isEmpty)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: const Text(
                    'Pays détecté via les métadonnées des photos (aucun sous-dossier dédié dans 02 - Pays).',
                    style: TextStyle(fontSize: 12, color: Colors.white60),
                  ),
                )
              else
                ...stats.albums.map((alb) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Material(
                      color: const Color(0xFF1E293B).withOpacity(0.75),
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          Navigator.of(sheetCtx).pop();
                          widget.onOpenAlbum(alb.albumId);
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                          child: Row(
                            children: [
                              Icon(
                                alb.isFolder ? Icons.folder_rounded : Icons.photo_album_outlined,
                                color: alb.isFolder ? const Color(0xFFFBBF24) : const Color(0xFF38BDF8),
                                size: 22,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      alb.name,
                                      style: const TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        if (alb.dateHint != null) ...[
                                          const Icon(Icons.calendar_today_outlined, size: 11, color: Color(0xFF38BDF8)),
                                          const SizedBox(width: 4),
                                          Text(
                                            alb.dateHint!,
                                            style: const TextStyle(fontSize: 11, color: Color(0xFF7DD3FC)),
                                          ),
                                          const SizedBox(width: 10),
                                        ],
                                        Text(
                                          '${alb.photoCount} photos${alb.videoCount > 0 ? ' · ${alb.videoCount} vidéos' : ''}',
                                          style: const TextStyle(fontSize: 11.5, color: Colors.white54),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right_rounded, color: Colors.white38, size: 20),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF0EA5E9),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                Navigator.of(sheetCtx).pop();
                widget.onOpenCountryMedia(stats);
              },
              icon: const Icon(Icons.grid_view_rounded, size: 18),
              label: Text(
                'Voir tous les médias (${stats.totalMedia})',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _statChip(IconData icon, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12.5, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 11.5, color: color, fontWeight: FontWeight.w500)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final visitedByIso = {
      for (final c in widget.visitedCountries) c.meta.iso3: c,
    };
    final filteredCountries = _selectedContinent == 'Monde'
        ? widget.visitedCountries
        : widget.visitedCountries.where((c) => c.meta.continent == _selectedContinent).toList();
    final isCompact = MediaQuery.of(context).size.width < 700;

    return Column(
      children: [
        // Top Header + Stats + View Toggle
        Container(
          padding: EdgeInsets.fromLTRB(isCompact ? 12 : 20, 12, isCompact ? 12 : 20, 8),
          decoration: const BoxDecoration(
            color: Color(0xFF0B1120),
            border: Border(bottom: BorderSide(color: Colors.white10)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _summaryPill(
                          Icons.public_rounded,
                          '${widget.visitedCountries.length} pays',
                          const Color(0xFF38BDF8),
                        ),
                        _summaryPill(
                          Icons.photo_outlined,
                          '${widget.totalPhotos}',
                          const Color(0xFF7DD3FC),
                        ),
                        _summaryPill(
                          Icons.videocam_outlined,
                          '${widget.totalVideos}',
                          const Color(0xFFA78BFA),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Tooltip(
                    message: _showListMode ? 'Afficher la carte' : 'Afficher la liste',
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => setState(() => _showListMode = !_showListMode),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _showListMode ? Icons.map_outlined : Icons.format_list_bulleted_rounded,
                              size: 16,
                              color: Colors.white,
                            ),
                            if (!isCompact) ...[
                              const SizedBox(width: 6),
                              Text(
                                _showListMode ? 'Carte' : 'Liste',
                                style: const TextStyle(fontSize: 12, color: Colors.white),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF0EA5E9),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(horizontal: isCompact ? 10 : 12, vertical: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: widget.onAddCountryFolder,
                    icon: const Icon(Icons.add_location_alt_outlined, size: 16),
                    label: Text(
                      isCompact ? 'Pays' : 'Ajouter un pays',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Continent filter chips
              LayoutBuilder(
                builder: (ctx, constraints) {
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: ['Monde', 'Europe', 'Afrique', 'Amériques', 'Asie', 'Océanie'].map((cont) {
                        final selected = _selectedContinent == cont;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text(cont),
                            selected: selected,
                            onSelected: (_) => _focusContinent(cont, Size(constraints.maxWidth, 380)),
                            labelStyle: TextStyle(
                              fontSize: 11.5,
                              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                              color: selected ? Colors.white : Colors.white70,
                            ),
                            backgroundColor: const Color(0xFF1E293B),
                            selectedColor: const Color(0xFF0EA5E9).withOpacity(0.35),
                            side: BorderSide(
                              color: selected ? const Color(0xFF38BDF8) : Colors.white12,
                            ),
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                          ),
                        );
                      }).toList(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),

        // Main Map or List Area
        Expanded(
          child: _showListMode
              ? _buildCountryListView(filteredCountries)
              : _buildInteractiveMap(visitedByIso, filteredCountries, isCompact),
        ),
      ],
    );
  }

  Widget _summaryPill(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.32)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13.5, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildCountryListView(List<CountryVisitStats> countries) {
    if (countries.isEmpty) {
      return const Center(
        child: Text(
          'Aucun pays visité dans cette région.',
          style: TextStyle(color: Colors.white54),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(14),
      itemCount: countries.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, idx) {
        final c = countries[idx];
        return Material(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => _openCountryDetails(c),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.25)),
              ),
              child: Row(
                children: [
                  Text(c.meta.flag, style: const TextStyle(fontSize: 28)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c.meta.nameFr,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${c.meta.continent} · ${c.albums.length} album${c.albums.length > 1 ? 's' : ''}',
                          style: const TextStyle(fontSize: 11.5, color: Colors.white54),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${c.photoCount} photos',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF38BDF8),
                        ),
                      ),
                      if (c.videoCount > 0)
                        Text(
                          '${c.videoCount} vidéos',
                          style: const TextStyle(fontSize: 11.5, color: Color(0xFFA78BFA)),
                        ),
                    ],
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.chevron_right_rounded, color: Colors.white38),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInteractiveMap(
    Map<String, CountryVisitStats> visitedByIso,
    List<CountryVisitStats> filteredCountries,
    bool isCompact,
  ) {
    final shapes = _shapes;
    if (shapes == null) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF38BDF8)),
      );
    }

    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              LayoutBuilder(
                builder: (ctx, constraints) {
                  // Fit 1200:620 aspect ratio comfortably inside available viewport
                  final aspect = _mapCanvasSize.width / _mapCanvasSize.height;
                  final maxW = constraints.maxWidth;
                  final maxH = constraints.maxHeight;
                  double boxW = maxW;
                  double boxH = boxW / aspect;
                  if (boxH > maxH) {
                    boxH = maxH;
                    boxW = boxH * aspect;
                  }
                  final mapBoxSize = Size(math.max(boxW, 300), math.max(boxH, 200));

                  return Container(
                    width: maxW,
                    height: maxH,
                    decoration: const BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment(0, -0.1),
                        radius: 1.1,
                        colors: [Color(0xFF0E1B33), Color(0xFF050A14)],
                      ),
                    ),
                    child: InteractiveViewer(
                      transformationController: _transformController,
                      minScale: 1.0,
                      maxScale: 7.0,
                      boundaryMargin: const EdgeInsets.all(60),
                      child: Center(
                        child: GestureDetector(
                          onTapUp: (details) => _handleMapTap(details, mapBoxSize, visitedByIso),
                          child: SizedBox(
                            width: mapBoxSize.width,
                            height: mapBoxSize.height,
                            child: CustomPaint(
                              painter: _WorldMapPainter(
                                shapes: shapes,
                                visitedByIso: visitedByIso,
                                highlightedIso: _highlightedIso,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              // Reset Zoom floating button
              Positioned(
                right: 12,
                bottom: 12,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FloatingActionButton.small(
                      heroTag: 'map_reset_zoom',
                      backgroundColor: const Color(0xFF0F172A).withOpacity(0.9),
                      foregroundColor: Colors.white70,
                      tooltip: 'Réinitialiser le zoom',
                      onPressed: () {
                        setState(() => _selectedContinent = 'Monde');
                        _transformController.value = Matrix4.identity();
                      },
                      child: const Icon(Icons.fit_screen_rounded, size: 18),
                    ),
                  ],
                ),
              ),
              // Subtle legend top-left
              Positioned(
                left: 12,
                top: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0B1120).withOpacity(0.82),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: const Color(0xFF0EA5E9),
                          borderRadius: BorderRadius.circular(3),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF38BDF8).withOpacity(0.6),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'Pays visités (cliquer pour détails)',
                        style: TextStyle(fontSize: 11, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        // Bottom quick-access horizontal strip of visited countries (super handy on mobile!)
        Container(
          height: isCompact ? 62 : 66,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: const BoxDecoration(
            color: Color(0xFF0B1120),
            border: Border(top: BorderSide(color: Colors.white10)),
          ),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: filteredCountries.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, idx) {
              final c = filteredCountries[idx];
              final isSelected = _highlightedIso == c.meta.iso3;
              return InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _openCountryDetails(c),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF0EA5E9).withOpacity(0.24)
                        : const Color(0xFF1E293B).withOpacity(0.8),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF38BDF8)
                          : const Color(0xFF38BDF8).withOpacity(0.28),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(c.meta.flag, style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: 7),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            c.meta.nameFr,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            '${c.photoCount}p${c.videoCount > 0 ? ' · ${c.videoCount}v' : ''}',
                            style: const TextStyle(fontSize: 10, color: Color(0xFF7DD3FC)),
                          ),
                        ],
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
  }
}

class _WorldMapPainter extends CustomPainter {
  final List<_CountryGeoShape> shapes;
  final Map<String, CountryVisitStats> visitedByIso;
  final String? highlightedIso;

  _WorldMapPainter({
    required this.shapes,
    required this.visitedByIso,
    this.highlightedIso,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Subtle graticule grid
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.04)
      ..strokeWidth = 0.7;
    for (int i = 1; i < 6; i++) {
      final y = size.height * (i / 6);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    for (int i = 1; i < 12; i++) {
      final x = size.width * (i / 12);
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }

    final unvisitedFill = Paint()
      ..color = const Color(0xFF172236)
      ..style = PaintingStyle.fill;
    final unvisitedStroke = Paint()
      ..color = const Color(0xFF28354D)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6;

    final visitedGlow = Paint()
      ..color = const Color(0xFF0EA5E9).withOpacity(0.32)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5.0)
      ..style = PaintingStyle.fill;
    final visitedFill = Paint()
      ..color = const Color(0xFF0284C7)
      ..style = PaintingStyle.fill;
    final visitedHighlightFill = Paint()
      ..color = const Color(0xFF38BDF8)
      ..style = PaintingStyle.fill;
    final visitedStroke = Paint()
      ..color = const Color(0xFF7DD3FC)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // 2. Draw unvisited countries first
    for (final s in shapes) {
      if (visitedByIso.containsKey(s.iso3)) continue;
      final path = _buildPath(s, size);
      canvas.drawPath(path, unvisitedFill);
      canvas.drawPath(path, unvisitedStroke);
    }

    // 3. Draw visited countries on top with glow
    for (final s in shapes) {
      if (!visitedByIso.containsKey(s.iso3)) continue;
      final path = _buildPath(s, size);
      canvas.drawPath(path, visitedGlow);
      canvas.drawPath(
        path,
        s.iso3 == highlightedIso ? visitedHighlightFill : visitedFill,
      );
      canvas.drawPath(path, visitedStroke);
    }

    // 4. Draw count badges on visited countries
    final badgeBg = Paint()..color = const Color(0xFF0B1120).withOpacity(0.92);
    final badgeBorder = Paint()
      ..color = const Color(0xFF38BDF8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (final s in shapes) {
      final stats = visitedByIso[s.iso3];
      if (stats == null) continue;
      final c = Offset(s.centerNorm.dx * size.width, s.centerNorm.dy * size.height);
      final label = '${stats.totalMedia}';
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: const TextStyle(
            fontSize: 7.8,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final pillW = math.max(15.0, tp.width + 7.0);
      const pillH = 11.5;
      final rect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: c, width: pillW, height: pillH),
        const Radius.circular(6),
      );
      canvas.drawRRect(rect, badgeBg);
      canvas.drawRRect(rect, badgeBorder);
      tp.paint(canvas, Offset(c.dx - tp.width / 2, c.dy - tp.height / 2));
    }
  }

  Path _buildPath(_CountryGeoShape shape, Size size) {
    final path = Path();
    for (final poly in shape.polygonsNorm) {
      if (poly.isEmpty) continue;
      path.moveTo(poly[0].dx * size.width, poly[0].dy * size.height);
      for (int i = 1; i < poly.length; i++) {
        path.lineTo(poly[i].dx * size.width, poly[i].dy * size.height);
      }
      path.close();
    }
    return path;
  }

  @override
  bool shouldRepaint(covariant _WorldMapPainter oldDelegate) {
    return oldDelegate.visitedByIso != visitedByIso ||
        oldDelegate.highlightedIso != highlightedIso ||
        oldDelegate.shapes != shapes;
  }
}
