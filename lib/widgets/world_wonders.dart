import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum WonderCategory { modern, ancient }

class WorldWonder {
  final String id;
  final String name;
  final WonderCategory category;
  final String countryIso;
  final String countryName;
  final String flag;
  final String locationName;
  final double lat;
  final double lon;
  final String era;
  final String status;
  final String description;
  final String imageUrl;
  final List<String> keywords;

  const WorldWonder({
    required this.id,
    required this.name,
    required this.category,
    required this.countryIso,
    required this.countryName,
    required this.flag,
    required this.locationName,
    required this.lat,
    required this.lon,
    required this.era,
    required this.status,
    required this.description,
    required this.imageUrl,
    required this.keywords,
  });
}

class WonderAlbumOption {
  final String id;
  final String name;
  final int count;

  const WonderAlbumOption({
    required this.id,
    required this.name,
    required this.count,
  });
}

class WonderPhotoPreview {
  final int id;
  final String filename;
  final String? thumbnailUrl;
  final String? largePreviewUrl;
  final String captureDate;

  const WonderPhotoPreview({
    required this.id,
    required this.filename,
    this.thumbnailUrl,
    this.largePreviewUrl,
    this.captureDate = '',
  });
}

class WonderUserState {
  final bool manualVisited;
  final String? assignedAlbumId;

  const WonderUserState({
    this.manualVisited = false,
    this.assignedAlbumId,
  });

  Map<String, dynamic> toJson() => {
        'manualVisited': manualVisited,
        if (assignedAlbumId != null) 'assignedAlbumId': assignedAlbumId,
      };

  factory WonderUserState.fromJson(Map<String, dynamic> json) => WonderUserState(
        manualVisited: json['manualVisited'] as bool? ?? false,
        assignedAlbumId: json['assignedAlbumId'] as String?,
      );
}

class WonderEvaluation {
  final WorldWonder wonder;
  final bool isVisited;
  final String? validationSource; // 'GPS', 'Album', 'Manuel'
  final String? linkedAlbumId;
  final String? linkedAlbumName;
  final List<WonderPhotoPreview> photos;

  const WonderEvaluation({
    required this.wonder,
    required this.isVisited,
    this.validationSource,
    this.linkedAlbumId,
    this.linkedAlbumName,
    this.photos = const [],
  });
}

const List<WorldWonder> kWorldWonders = [
  // --- 7 NOUVELLES MERVEILLES DU MONDE ---
  WorldWonder(
    id: 'great_wall',
    name: 'Grande Muraille de Chine',
    category: WonderCategory.modern,
    countryIso: 'CHN',
    countryName: 'Chine',
    flag: '🇨🇳',
    locationName: 'Pékin / Mutianyu, Chine',
    lat: 40.4319,
    lon: 116.5704,
    era: 'VIIe s. av. J.-C. – XVIIe s.',
    status: 'Intact (sections restaurées)',
    description:
        'Ensemble de fortifications militaires s\'étendant sur plus de 21 000 km à travers le nord de la Chine. Érigée sous plusieurs dynasties impériales pour protéger l\'Empire du Milieu, elle serpente sur les crêtes montagneuses avec ses tours de guet emblématiques.',
    imageUrl: 'https://commons.wikimedia.org/wiki/Special:FilePath/The_Great_Wall_of_China_at_Jinshanling-edit.jpg?width=800',
    keywords: ['muraille', 'great wall', 'pékin', 'pekin', 'beijing', 'mutianyu', 'badaling'],
  ),
  WorldWonder(
    id: 'petra',
    name: 'Pétra',
    category: WonderCategory.modern,
    countryIso: 'JOR',
    countryName: 'Jordanie',
    flag: '🇯🇴',
    locationName: 'Ma\'an, Jordanie',
    lat: 30.3285,
    lon: 35.4444,
    era: 'IVe s. av. J.-C.',
    status: 'Site archéologique intact',
    description:
        'Ancienne cité nabatéenne sculptée à même les falaises de grès rose au cœur du désert jordanien. Accessible par l\'étroit canyon du Siq, elle révèle le célèbre Khazneh (le Trésor), chef-d\'œuvre de l\'architecture rupestre antique.',
    imageUrl: 'https://commons.wikimedia.org/wiki/Special:FilePath/Al_Khazneh_Petra_edit_2.jpg?width=800',
    keywords: ['petra', 'pétra', 'jordanie', 'jordan', 'khazneh', 'wadi rum'],
  ),
  WorldWonder(
    id: 'christ_redeemer',
    name: 'Christ Rédempteur',
    category: WonderCategory.modern,
    countryIso: 'BRA',
    countryName: 'Brésil',
    flag: '🇧🇷',
    locationName: 'Rio de Janeiro, Brésil',
    lat: -22.9519,
    lon: -43.2105,
    era: '1931',
    status: 'Intact',
    description:
        'Statue Art déco monumentale de 38 mètres de haut (socle compris) perchée au sommet du mont Corcovado à 710 m d\'altitude. Symbole de Rio de Janeiro et du Brésil, elle offre un panorama spectaculaire sur la baie de Guanabara et le Pain de Sucre.',
    imageUrl: 'https://commons.wikimedia.org/wiki/Special:FilePath/Christ_the_Redeemer_-_Cristo_Redentor.jpg?width=800',
    keywords: ['corcovado', 'christ rédempteur', 'christ redempteur', 'rio', 'cristo redentor'],
  ),
  WorldWonder(
    id: 'machu_picchu',
    name: 'Machu Picchu',
    category: WonderCategory.modern,
    countryIso: 'PER',
    countryName: 'Pérou',
    flag: '🇵🇪',
    locationName: 'Région de Cuzco, Pérou',
    lat: -13.1631,
    lon: -72.5450,
    era: 'XVe siècle (~1450)',
    status: 'Site archéologique intact',
    description:
        'Citadelle inca perchée à 2 430 m d\'altitude sur un éperon rocheux des Andes péruviennes. Bâtie sous le règne de l\'empereur Pachacutec sans mortier grâce à un ajustement millimétré des pierres, elle est entourée de terrasses agricoles vertigineuses.',
    imageUrl: 'https://commons.wikimedia.org/wiki/Special:FilePath/Machu_Picchu,_Peru.jpg?width=800',
    keywords: ['machu picchu', 'cuzco', 'cusco', 'pérou', 'perou', 'peru', 'inca'],
  ),
  WorldWonder(
    id: 'chichen_itza',
    name: 'Chichén Itzá',
    category: WonderCategory.modern,
    countryIso: 'MEX',
    countryName: 'Mexique',
    flag: '🇲🇽',
    locationName: 'Yucatán, Mexique',
    lat: 20.6843,
    lon: -88.5678,
    era: 'Ve – XIIIe siècle',
    status: 'Site archéologique intact',
    description:
        'Grande cité maya du Yucatán dominée par la pyramide à degrés d\'El Castillo (temple de Kukulcán). À chaque équinoxe, l\'ombre portée dessine un serpent ondulant le long des marches de l\'escalier nord.',
    imageUrl: 'https://commons.wikimedia.org/wiki/Special:FilePath/Chichen_Itza_3.jpg?width=800',
    keywords: ['chichen', 'chichén', 'itza', 'yucatan', 'yucatán', 'kukulcan', 'mexique'],
  ),
  WorldWonder(
    id: 'colosseum',
    name: 'Colisée de Rome',
    category: WonderCategory.modern,
    countryIso: 'ITA',
    countryName: 'Italie',
    flag: '🇮🇹',
    locationName: 'Rome, Italie',
    lat: 41.8902,
    lon: 12.4922,
    era: '70 – 80 ap. J.-C.',
    status: 'Intact (monument)',
    description:
        'Plus grand amphithéâtre jamais construit sous l\'Empire romain, capable d\'accueillir plus de 50 000 spectateurs pour les combats de gladiateurs et les spectacles publics. Chef-d\'œuvre d\'ingénierie romaine avec ses voûtes en travertin et son hypogée souterrain.',
    imageUrl: 'https://commons.wikimedia.org/wiki/Special:FilePath/Colosseo_2020.jpg?width=800',
    keywords: ['colisée', 'colisee', 'colosseum', 'colosseo', 'rome', 'roma'],
  ),
  WorldWonder(
    id: 'taj_mahal',
    name: 'Taj Mahal',
    category: WonderCategory.modern,
    countryIso: 'IND',
    countryName: 'Inde',
    flag: '🇮🇳',
    locationName: 'Agra, Inde',
    lat: 27.1751,
    lon: 78.0421,
    era: '1631 – 1648',
    status: 'Intact',
    description:
        'Mausolée de marbre blanc incrusté de pierres semi-précieuses, commandé par l\'empereur moghol Shâh Jahân en mémoire de son épouse Mumtaz Mahal. Joyau de l\'architecture moghole, il change subtilement de teinte selon la lumière du jour.',
    imageUrl: 'https://commons.wikimedia.org/wiki/Special:FilePath/Taj_Mahal_(Edited).jpeg?width=800',
    keywords: ['taj mahal', 'agra', 'inde', 'india'],
  ),

  // --- 7 MERVEILLES DU MONDE ANTIQUE ---
  WorldWonder(
    id: 'great_pyramid',
    name: 'Grande Pyramide de Gizeh',
    category: WonderCategory.ancient,
    countryIso: 'EGY',
    countryName: 'Égypte',
    flag: '🇪🇬',
    locationName: 'Gizeh (Le Caire), Égypte',
    lat: 29.9792,
    lon: 31.1342,
    era: '~2560 av. J.-C.',
    status: 'Intact (seule merveille antique encore debout)',
    description:
        'Tombeau du pharaon Khéops et la plus ancienne des sept merveilles du monde antique — mais aussi la seule encore debout. Composée de plus de 2,3 millions de blocs de calcaire, elle fut pendant près de 3 800 ans la plus haute structure construite par l\'homme.',
    imageUrl: 'https://commons.wikimedia.org/wiki/Special:FilePath/Kheops-Pyramid.jpg?width=800',
    keywords: ['pyramide', 'gizeh', 'giza', 'khéops', 'kheops', 'caire', 'egypte', 'égypte'],
  ),
  WorldWonder(
    id: 'hanging_gardens',
    name: 'Jardins suspendus de Babylone',
    category: WonderCategory.ancient,
    countryIso: 'IRQ',
    countryName: 'Irak',
    flag: '🇮🇶',
    locationName: 'Babylone (près de Hilla), Irak',
    lat: 32.5364,
    lon: 44.4208,
    era: '~600 av. J.-C.',
    status: 'Disparue',
    description:
        'Légendaires terrasses végétales irriguées attribuées au roi Nabuchodonosor II pour rappeler à son épouse les montagnes verdoyantes de sa patrie. Aucune trace archéologique définitive n\'a été retrouvée, ce qui alimente encore le mystère autour de leur emplacement exact.',
    imageUrl: 'https://commons.wikimedia.org/wiki/Special:FilePath/Hanging_Gardens_of_Babylon.jpg?width=800',
    keywords: ['babylone', 'babylon', 'jardins suspendus'],
  ),
  WorldWonder(
    id: 'temple_artemis',
    name: 'Temple d\'Artémis à Éphèse',
    category: WonderCategory.ancient,
    countryIso: 'TUR',
    countryName: 'Turquie',
    flag: '🇹🇷',
    locationName: 'Selçuk (Éphèse), Turquie',
    lat: 37.9497,
    lon: 27.3639,
    era: '~550 av. J.-C.',
    status: 'Vestiges (colonne restante)',
    description:
        'Sanctuaire monumental de marbre dédié à la déesse Artémis, admiré dans toute la Méditerranée pour ses 127 colonnes ioniques hautes de près de 18 mètres. Incendié puis reconstruit, il ne subsiste aujourd\'hui qu\'une colonne restaurée sur le site d\'Éphèse.',
    imageUrl: 'https://commons.wikimedia.org/wiki/Special:FilePath/Temple_of_Artemis_at_Ephesus_by_Ferdinand_Knab_(1886)_-_cropped.jpg?width=800',
    keywords: ['éphèse', 'ephese', 'ephesus', 'artémis', 'artemis', 'selcuk'],
  ),
  WorldWonder(
    id: 'statue_zeus',
    name: 'Statue de Zeus à Olympie',
    category: WonderCategory.ancient,
    countryIso: 'GRC',
    countryName: 'Grèce',
    flag: '🇬🇷',
    locationName: 'Olympie, Grèce',
    lat: 37.6380,
    lon: 21.6300,
    era: '~435 av. J.-C.',
    status: 'Disparue (site d\'Olympie visitable)',
    description:
        'Sculpture chryséléphantine (or et ivoire) haute d\'environ 12 mètres, réalisée par Phidias pour le temple de Zeus à Olympie. Le dieu assis sur un trône de cèdre incrusté d\'ébène et de pierres précieuses dominait le sanctuaire des Jeux olympiques antiques.',
    imageUrl: 'https://commons.wikimedia.org/wiki/Special:FilePath/Le_Jupiter_Olympien_ou_l%27art_de_la_sculpture_antique.jpg?width=800',
    keywords: ['olympie', 'olympia', 'zeus'],
  ),
  WorldWonder(
    id: 'mausoleum_halicarnassus',
    name: 'Mausolée d\'Halicarnasse',
    category: WonderCategory.ancient,
    countryIso: 'TUR',
    countryName: 'Turquie',
    flag: '🇹🇷',
    locationName: 'Bodrum (Halicarnasse), Turquie',
    lat: 37.0379,
    lon: 27.4241,
    era: '~350 av. J.-C.',
    status: 'Vestiges (fondations à Bodrum)',
    description:
        'Tombeau monumental haut de 45 mètres érigé pour le satrape Mausole et son épouse Artémise II. D\'une telle magnificence que le mot « mausolée » vient de son nom, il fut détruit par des tremblements de terre au Moyen Âge.',
    imageUrl: 'https://commons.wikimedia.org/wiki/Special:FilePath/Mausoleum_at_Halicarnassus_by_Ferdinand_Knab_(1886)_cropped.png?width=800',
    keywords: ['halicarnasse', 'mausolée', 'mausolee', 'bodrum'],
  ),
  WorldWonder(
    id: 'colossus_rhodes',
    name: 'Colosse de Rhodes',
    category: WonderCategory.ancient,
    countryIso: 'GRC',
    countryName: 'Grèce',
    flag: '🇬🇷',
    locationName: 'Île de Rhodes, Grèce',
    lat: 36.4510,
    lon: 28.2278,
    era: '~280 av. J.-C.',
    status: 'Disparue (port de Rhodes visitable)',
    description:
        'Immense statue de bronze d\'environ 32 mètres représentant Hélios, le dieu du Soleil, érigée à l\'entrée du port de Rhodes pour célébrer la victoire sur Démétrios Poliorcète. Elle s\'effondra lors d\'un séisme en 226 av. J.-C.',
    imageUrl: 'https://commons.wikimedia.org/wiki/Special:FilePath/Colossus_of_Rhodes_by_Ferdinand_Knab_(1886)_cropped.png?width=800',
    keywords: ['rhodes', 'colosse', 'colossus'],
  ),
  WorldWonder(
    id: 'lighthouse_alexandria',
    name: 'Phare d\'Alexandrie',
    category: WonderCategory.ancient,
    countryIso: 'EGY',
    countryName: 'Égypte',
    flag: '🇪🇬',
    locationName: 'Alexandrie, Égypte',
    lat: 31.2139,
    lon: 29.8856,
    era: '~280 av. J.-C.',
    status: 'Disparue (Fort Qaitbay sur le site)',
    description:
        'Tour de marbre blanc haute de plus de 100 mètres sur l\'île de Pharos, guidant les navires jusqu\'au port d\'Alexandrie grâce à un miroir de bronze poli et un feu nocturne. Détruit par des séismes au XIVe siècle, ses blocs reposent sous la mer face au fort Qaitbay.',
    imageUrl: 'https://commons.wikimedia.org/wiki/Special:FilePath/Pharos_of_Alexandria_by_Ferdinand_Knab_(1886)_cropped.png?width=800',
    keywords: ['alexandrie', 'alexandria', 'phare', 'pharos', 'qaitbay'],
  ),
];

class WondersStorage {
  static const String _prefsKey = 'wonders_assignments_v1';

  static Future<Map<String, WonderUserState>> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null || raw.isEmpty) return {};
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map(
        (k, v) => MapEntry(k, WonderUserState.fromJson(v as Map<String, dynamic>)),
      );
    } catch (_) {
      return {};
    }
  }

  static Future<void> save(Map<String, WonderUserState> states) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(states.map((k, v) => MapEntry(k, v.toJson())));
      await prefs.setString(_prefsKey, encoded);
    } catch (_) {}
  }
}

double haversineKm(double lat1, double lon1, double lat2, double lon2) {
  const r = 6371.0;
  final dLat = (lat2 - lat1) * math.pi / 180.0;
  final dLon = (lon2 - lon1) * math.pi / 180.0;
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(lat1 * math.pi / 180.0) *
          math.cos(lat2 * math.pi / 180.0) *
          math.sin(dLon / 2) *
          math.sin(dLon / 2);
  return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

class WonderDetailSheet extends StatefulWidget {
  final WonderEvaluation evaluation;
  final List<WonderAlbumOption> availableAlbums;
  final ScrollController scrollController;
  final void Function(WonderUserState newState) onUpdateState;
  final void Function(String albumId) onOpenAlbum;
  final VoidCallback onClose;

  const WonderDetailSheet({
    super.key,
    required this.evaluation,
    required this.availableAlbums,
    required this.scrollController,
    required this.onUpdateState,
    required this.onOpenAlbum,
    required this.onClose,
  });

  @override
  State<WonderDetailSheet> createState() => _WonderDetailSheetState();
}

class _WonderDetailSheetState extends State<WonderDetailSheet> {
  final PageController _carouselCtrl = PageController(viewportFraction: 0.86);
  int _carouselIndex = 0;

  @override
  void dispose() {
    _carouselCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAlbum() async {
    String query = '';
    final picked = await showDialog<WonderAlbumOption>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final q = query.trim().toLowerCase();
          final filtered = q.isEmpty
              ? widget.availableAlbums
              : widget.availableAlbums
                  .where((a) => a.name.toLowerCase().contains(q))
                  .toList();
          return AlertDialog(
            title: const Text('Associer un album', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            content: SizedBox(
              width: 360,
              height: 380,
              child: Column(
                children: [
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Rechercher un album...',
                      prefixIcon: const Icon(Icons.search, size: 18),
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onChanged: (v) => setDialogState(() => query = v),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: filtered.isEmpty
                        ? const Center(child: Text('Aucun album trouvé', style: TextStyle(color: Color(0xFF64748B))))
                        : ListView.separated(
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (_, idx) {
                              final alb = filtered[idx];
                              return ListTile(
                                dense: true,
                                leading: const Icon(Icons.photo_album_outlined, color: Color(0xFFF97316), size: 20),
                                title: Text(alb.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                                trailing: Text('${alb.count}', style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                                onTap: () => Navigator.of(ctx).pop(alb),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Annuler'),
              ),
            ],
          );
        },
      ),
    );

    if (picked != null) {
      widget.onUpdateState(WonderUserState(manualVisited: true, assignedAlbumId: picked.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final eval = widget.evaluation;
    final w = eval.wonder;
    final isModern = w.category == WonderCategory.modern;

    return ListView(
      controller: widget.scrollController,
      padding: EdgeInsets.zero,
      children: [
        Stack(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              child: SizedBox(
                height: 200,
                width: double.infinity,
                child: Image.network(
                  w.imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF0E7490), Color(0xFFF97316)],
                      ),
                    ),
                    child: Center(
                      child: Text(w.flag, style: const TextStyle(fontSize: 56)),
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.12),
                      Colors.black.withValues(alpha: 0.72),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              right: 12,
              top: 12,
              child: CircleAvatar(
                radius: 17,
                backgroundColor: Colors.black.withValues(alpha: 0.45),
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.close, color: Colors.white, size: 18),
                  onPressed: widget.onClose,
                ),
              ),
            ),
            Positioned(
              left: 16,
              top: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isModern ? const Color(0xFFF97316) : const Color(0xFF0E7490),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isModern ? 'Merveille Moderne' : 'Merveille Antique',
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 14,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${w.flag} ${w.name}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      shadows: [Shadow(color: Colors.black54, blurRadius: 6)],
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${w.locationName} · ${w.era}',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 12.5),
                  ),
                ],
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: eval.isVisited
                          ? const Color(0xFF10B981).withValues(alpha: 0.14)
                          : const Color(0xFF64748B).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: eval.isVisited ? const Color(0xFF10B981) : const Color(0xFFCBD5E1),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          eval.isVisited ? Icons.check_circle_rounded : Icons.explore_outlined,
                          size: 15,
                          color: eval.isVisited ? const Color(0xFF059669) : const Color(0xFF64748B),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          eval.isVisited
                              ? 'Visitée (${eval.validationSource ?? 'Validée'})'
                              : 'À découvrir',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: eval.isVisited ? const Color(0xFF059669) : const Color(0xFF475569),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'État : ${w.status}',
                      style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                w.description,
                style: const TextStyle(fontSize: 13.5, height: 1.5, color: Color(0xFF334155)),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _pickAlbum,
                    icon: const Icon(Icons.link_rounded, size: 17),
                    label: Text(
                      eval.linkedAlbumName != null ? 'Changer d\'album' : 'Associer un album',
                      style: const TextStyle(fontSize: 12.5),
                    ),
                  ),
                  if (eval.linkedAlbumId != null)
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFF97316),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => widget.onOpenAlbum(eval.linkedAlbumId!),
                      icon: const Icon(Icons.photo_library_outlined, size: 17),
                      label: Text(
                        'Ouvrir : ${eval.linkedAlbumName ?? 'l\'album'}',
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                      ),
                    ),
                  TextButton.icon(
                    onPressed: () => widget.onUpdateState(
                      WonderUserState(
                        manualVisited: !eval.isVisited,
                        assignedAlbumId: eval.linkedAlbumId,
                      ),
                    ),
                    icon: Icon(
                      eval.isVisited ? Icons.remove_done_rounded : Icons.done_all_rounded,
                      size: 17,
                    ),
                    label: Text(
                      eval.isVisited ? 'Retirer validation' : 'Marquer visitée',
                      style: const TextStyle(fontSize: 12.5),
                    ),
                  ),
                ],
              ),
              if (eval.photos.isNotEmpty) ...[
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Vos photos (${eval.photos.length})',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    Text(
                      '${_carouselIndex + 1} / ${eval.photos.length}',
                      style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 170,
                  child: PageView.builder(
                    controller: _carouselCtrl,
                    itemCount: eval.photos.length,
                    onPageChanged: (i) => setState(() => _carouselIndex = i),
                    itemBuilder: (_, idx) {
                      final p = eval.photos[idx];
                      final url = p.largePreviewUrl ?? p.thumbnailUrl;
                      return Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            color: const Color(0xFFF1F5F9),
                            child: url != null
                                ? Image.network(url, fit: BoxFit.cover)
                                : const Center(child: Icon(Icons.photo_outlined, size: 32, color: Color(0xFF94A3B8))),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ] else ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7E8),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFF1E6D2)),
                  ),
                  child: const Text(
                    'Aucune photo associée pour le moment. Associez un album Lightroom ou ajoutez des photos géotaguées pour remplir le carrousel.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
