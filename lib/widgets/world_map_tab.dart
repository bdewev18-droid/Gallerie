import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

class WorldCountryMeta {
  final String iso3;
  final String nameFr;
  final String flag;
  final String continent;
  final String capital;
  final String population;
  final List<String> aliases;

  const WorldCountryMeta({
    required this.iso3,
    required this.nameFr,
    required this.flag,
    required this.continent,
    required this.capital,
    required this.population,
    this.aliases = const [],
  });
}

class CountryAlbumSummary {
  final String albumId;
  final String name;
  final String? dateHint;
  final String sourceLabel; // e.g. "Pays" or "Années"
  final int photoCount;
  final int videoCount;
  final bool isFolder;

  const CountryAlbumSummary({
    required this.albumId,
    required this.name,
    this.dateHint,
    this.sourceLabel = 'Pays',
    required this.photoCount,
    required this.videoCount,
    this.isFolder = false,
  });
}

class CountrySlideshowPhoto {
  final int id;
  final String filename;
  final String? thumbnailUrl;
  final String? largePreviewUrl;
  final String? captureDate;

  const CountrySlideshowPhoto({
    required this.id,
    required this.filename,
    this.thumbnailUrl,
    this.largePreviewUrl,
    this.captureDate,
  });
}

class CountryVisitStats {
  final WorldCountryMeta meta;
  final int photoCount;
  final int videoCount;
  final List<CountryAlbumSummary> albums;
  final List<CountrySlideshowPhoto> slideshowPhotos;
  final List<String> travelDateRanges;

  const CountryVisitStats({
    required this.meta,
    required this.photoCount,
    required this.videoCount,
    required this.albums,
    this.slideshowPhotos = const [],
    this.travelDateRanges = const [],
  });

  int get totalMedia => photoCount + videoCount;
}

const List<WorldCountryMeta> kWorldCountries = [
  WorldCountryMeta(iso3: 'AFG', nameFr: 'Afghanistan', flag: '🇦🇫', continent: 'Asie', capital: 'Kaboul', population: '42 M'),
  WorldCountryMeta(iso3: 'ZAF', nameFr: 'Afrique du Sud', flag: '🇿🇦', continent: 'Afrique', capital: 'Pretoria', population: '60 M', aliases: ['South Africa']),
  WorldCountryMeta(iso3: 'ALB', nameFr: 'Albanie', flag: '🇦🇱', continent: 'Europe', capital: 'Tirana', population: '2,8 M', aliases: ['Albania']),
  WorldCountryMeta(iso3: 'DZA', nameFr: 'Algérie', flag: '🇩🇿', continent: 'Afrique', capital: 'Alger', population: '45 M', aliases: ['Algeria']),
  WorldCountryMeta(iso3: 'DEU', nameFr: 'Allemagne', flag: '🇩🇪', continent: 'Europe', capital: 'Berlin', population: '84 M', aliases: ['Germany']),
  WorldCountryMeta(iso3: 'SAU', nameFr: 'Arabie saoudite', flag: '🇸🇦', continent: 'Asie', capital: 'Riyad', population: '36 M', aliases: ['Saudi Arabia']),
  WorldCountryMeta(iso3: 'ARG', nameFr: 'Argentine', flag: '🇦🇷', continent: 'Amériques', capital: 'Buenos Aires', population: '46 M', aliases: ['Argentina']),
  WorldCountryMeta(iso3: 'ARM', nameFr: 'Arménie', flag: '🇦🇲', continent: 'Asie', capital: 'Erevan', population: '2,8 M'),
  WorldCountryMeta(iso3: 'AUS', nameFr: 'Australie', flag: '🇦🇺', continent: 'Océanie', capital: 'Canberra', population: '26 M', aliases: ['Australia']),
  WorldCountryMeta(iso3: 'AUT', nameFr: 'Autriche', flag: '🇦🇹', continent: 'Europe', capital: 'Vienne', population: '9,1 M', aliases: ['Austria']),
  WorldCountryMeta(iso3: 'BEL', nameFr: 'Belgique', flag: '🇧🇪', continent: 'Europe', capital: 'Bruxelles', population: '11,7 M', aliases: ['Belgium']),
  WorldCountryMeta(iso3: 'BOL', nameFr: 'Bolivie', flag: '🇧🇴', continent: 'Amériques', capital: 'Sucre / La Paz', population: '12,2 M'),
  WorldCountryMeta(iso3: 'BIH', nameFr: 'Bosnie-Herzégovine', flag: '🇧🇦', continent: 'Europe', capital: 'Sarajevo', population: '3,2 M'),
  WorldCountryMeta(iso3: 'BRA', nameFr: 'Brésil', flag: '🇧🇷', continent: 'Amériques', capital: 'Brasilia', population: '215 M', aliases: ['Brazil', 'Bresil']),
  WorldCountryMeta(iso3: 'BGR', nameFr: 'Bulgarie', flag: '🇧🇬', continent: 'Europe', capital: 'Sofia', population: '6,5 M', aliases: ['Bulgaria']),
  WorldCountryMeta(iso3: 'KHM', nameFr: 'Cambodge', flag: '🇰🇭', continent: 'Asie', capital: 'Phnom Penh', population: '17 M', aliases: ['Cambodia']),
  WorldCountryMeta(iso3: 'CMR', nameFr: 'Cameroun', flag: '🇨🇲', continent: 'Afrique', capital: 'Yaoundé', population: '28 M'),
  WorldCountryMeta(iso3: 'CAN', nameFr: 'Canada', flag: '🇨🇦', continent: 'Amériques', capital: 'Ottawa', population: '40 M'),
  WorldCountryMeta(iso3: 'CPV', nameFr: 'Cap-Vert', flag: '🇨🇻', continent: 'Afrique', capital: 'Praia', population: '0,6 M', aliases: ['Cap Vert', 'Cape Verde']),
  WorldCountryMeta(iso3: 'CHL', nameFr: 'Chili', flag: '🇨🇱', continent: 'Amériques', capital: 'Santiago', population: '19,6 M', aliases: ['Chile']),
  WorldCountryMeta(iso3: 'CHN', nameFr: 'Chine', flag: '🇨🇳', continent: 'Asie', capital: 'Pékin', population: '1,41 Md', aliases: ['China']),
  WorldCountryMeta(iso3: 'CYP', nameFr: 'Chypre', flag: '🇨🇾', continent: 'Europe', capital: 'Nicosie', population: '1,3 M', aliases: ['Cyprus']),
  WorldCountryMeta(iso3: 'COL', nameFr: 'Colombie', flag: '🇨🇴', continent: 'Amériques', capital: 'Bogota', population: '52 M', aliases: ['Colombia']),
  WorldCountryMeta(iso3: 'KOR', nameFr: 'Corée du Sud', flag: '🇰🇷', continent: 'Asie', capital: 'Séoul', population: '51,7 M', aliases: ['South Korea']),
  WorldCountryMeta(iso3: 'CRI', nameFr: 'Costa Rica', flag: '🇨🇷', continent: 'Amériques', capital: 'San José', population: '5,2 M'),
  WorldCountryMeta(iso3: 'HRV', nameFr: 'Croatie', flag: '🇭🇷', continent: 'Europe', capital: 'Zagreb', population: '3,9 M', aliases: ['Croatia']),
  WorldCountryMeta(iso3: 'CUB', nameFr: 'Cuba', flag: '🇨🇺', continent: 'Amériques', capital: 'La Havane', population: '11 M'),
  WorldCountryMeta(iso3: 'DNK', nameFr: 'Danemark', flag: '🇩🇰', continent: 'Europe', capital: 'Copenhague', population: '5,9 M', aliases: ['Denmark']),
  WorldCountryMeta(iso3: 'EGY', nameFr: 'Égypte', flag: '🇪🇬', continent: 'Afrique', capital: 'Le Caire', population: '111 M', aliases: ['Egypte', 'Egypt']),
  WorldCountryMeta(iso3: 'ARE', nameFr: 'Émirats arabes unis', flag: '🇦🇪', continent: 'Asie', capital: 'Abou Dabi', population: '9,5 M', aliases: ['Dubai', 'UAE']),
  WorldCountryMeta(iso3: 'ECU', nameFr: 'Équateur', flag: '🇪🇨', continent: 'Amériques', capital: 'Quito', population: '18 M'),
  WorldCountryMeta(iso3: 'ESP', nameFr: 'Espagne', flag: '🇪🇸', continent: 'Europe', capital: 'Madrid', population: '48 M', aliases: ['Spain', 'Canaries', 'Grand Canaria', 'Baléares', 'Baleares', 'Tenerife', 'Majorque']),
  WorldCountryMeta(iso3: 'EST', nameFr: 'Estonie', flag: '🇪🇪', continent: 'Europe', capital: 'Tallinn', population: '1,3 M'),
  WorldCountryMeta(iso3: 'USA', nameFr: 'États-Unis', flag: '🇺🇸', continent: 'Amériques', capital: 'Washington D.C.', population: '335 M', aliases: ['Etats-Unis', 'USA', 'United States']),
  WorldCountryMeta(iso3: 'ETH', nameFr: 'Éthiopie', flag: '🇪🇹', continent: 'Afrique', capital: 'Addis-Abeba', population: '126 M'),
  WorldCountryMeta(iso3: 'FIN', nameFr: 'Finlande', flag: '🇫🇮', continent: 'Europe', capital: 'Helsinki', population: '5,6 M', aliases: ['Finland']),
  WorldCountryMeta(iso3: 'FRA', nameFr: 'France', flag: '🇫🇷', continent: 'Europe', capital: 'Paris', population: '68 M', aliases: ['Loire', 'Paris', 'Vendée', 'Vendee', 'Corse', 'Bretagne']),
  WorldCountryMeta(iso3: 'GEO', nameFr: 'Géorgie', flag: '🇬🇪', continent: 'Asie', capital: 'Tbilissi', population: '3,7 M'),
  WorldCountryMeta(iso3: 'GRC', nameFr: 'Grèce', flag: '🇬🇷', continent: 'Europe', capital: 'Athènes', population: '10,4 M', aliases: ['Grece', 'Greece', 'Rhodes', 'Crète', 'Crete', 'Santorin']),
  WorldCountryMeta(iso3: 'GTM', nameFr: 'Guatemala', flag: '🇬🇹', continent: 'Amériques', capital: 'Guatemala', population: '18 M'),
  WorldCountryMeta(iso3: 'HUN', nameFr: 'Hongrie', flag: '🇭🇺', continent: 'Europe', capital: 'Budapest', population: '9,6 M', aliases: ['Hungary']),
  WorldCountryMeta(iso3: 'MUS', nameFr: 'Île Maurice', flag: '🇲🇺', continent: 'Afrique', capital: 'Port-Louis', population: '1,3 M', aliases: ['Maurice', 'Mauritius']),
  WorldCountryMeta(iso3: 'IND', nameFr: 'Inde', flag: '🇮🇳', continent: 'Asie', capital: 'New Delhi', population: '1,43 Md', aliases: ['India']),
  WorldCountryMeta(iso3: 'IDN', nameFr: 'Indonésie', flag: '🇮🇩', continent: 'Asie', capital: 'Jakarta', population: '277 M', aliases: ['Indonesia', 'Bali']),
  WorldCountryMeta(iso3: 'IRL', nameFr: 'Irlande', flag: '🇮🇪', continent: 'Europe', capital: 'Dublin', population: '5,2 M', aliases: ['Ireland']),
  WorldCountryMeta(iso3: 'ISL', nameFr: 'Islande', flag: '🇮🇸', continent: 'Europe', capital: 'Reykjavik', population: '0,4 M', aliases: ['Iceland']),
  WorldCountryMeta(iso3: 'ISR', nameFr: 'Israël', flag: '🇮🇱', continent: 'Asie', capital: 'Jérusalem', population: '9,7 M'),
  WorldCountryMeta(iso3: 'ITA', nameFr: 'Italie', flag: '🇮🇹', continent: 'Europe', capital: 'Rome', population: '59 M', aliases: ['Italy', 'Rome', 'Venise', 'Sicile']),
  WorldCountryMeta(iso3: 'JPN', nameFr: 'Japon', flag: '🇯🇵', continent: 'Asie', capital: 'Tokyo', population: '124 M', aliases: ['Japan']),
  WorldCountryMeta(iso3: 'JOR', nameFr: 'Jordanie', flag: '🇯🇴', continent: 'Asie', capital: 'Amman', population: '11,3 M', aliases: ['Jordan']),
  WorldCountryMeta(iso3: 'KEN', nameFr: 'Kenya', flag: '🇰🇪', continent: 'Afrique', capital: 'Nairobi', population: '55 M'),
  WorldCountryMeta(iso3: 'LVA', nameFr: 'Lettonie', flag: '🇱🇻', continent: 'Europe', capital: 'Riga', population: '1,9 M'),
  WorldCountryMeta(iso3: 'LBN', nameFr: 'Liban', flag: '🇱🇧', continent: 'Asie', capital: 'Beyrouth', population: '5,4 M'),
  WorldCountryMeta(iso3: 'LTU', nameFr: 'Lituanie', flag: '🇱🇹', continent: 'Europe', capital: 'Vilnius', population: '2,8 M'),
  WorldCountryMeta(iso3: 'LUX', nameFr: 'Luxembourg', flag: '🇱🇺', continent: 'Europe', capital: 'Luxembourg', population: '0,66 M'),
  WorldCountryMeta(iso3: 'MDG', nameFr: 'Madagascar', flag: '🇲🇬', continent: 'Afrique', capital: 'Antananarivo', population: '30 M'),
  WorldCountryMeta(iso3: 'MYS', nameFr: 'Malaisie', flag: '🇲🇾', continent: 'Asie', capital: 'Kuala Lumpur', population: '34 M', aliases: ['Malaysia']),
  WorldCountryMeta(iso3: 'MDV', nameFr: 'Maldives', flag: '🇲🇻', continent: 'Asie', capital: 'Malé', population: '0,5 M'),
  WorldCountryMeta(iso3: 'MLT', nameFr: 'Malte', flag: '🇲🇹', continent: 'Europe', capital: 'La Valette', population: '0,54 M', aliases: ['Malta']),
  WorldCountryMeta(iso3: 'MAR', nameFr: 'Maroc', flag: '🇲🇦', continent: 'Afrique', capital: 'Rabat', population: '37,5 M', aliases: ['Morocco']),
  WorldCountryMeta(iso3: 'MEX', nameFr: 'Mexique', flag: '🇲🇽', continent: 'Amériques', capital: 'Mexico', population: '128 M', aliases: ['Mexico']),
  WorldCountryMeta(iso3: 'MNE', nameFr: 'Monténégro', flag: '🇲🇪', continent: 'Europe', capital: 'Podgorica', population: '0,62 M'),
  WorldCountryMeta(iso3: 'NAM', nameFr: 'Namibie', flag: '🇳🇦', continent: 'Afrique', capital: 'Windhoek', population: '2,6 M'),
  WorldCountryMeta(iso3: 'NPL', nameFr: 'Népal', flag: '🇳🇵', continent: 'Asie', capital: 'Katmandou', population: '30,9 M'),
  WorldCountryMeta(iso3: 'NOR', nameFr: 'Norvège', flag: '🇳🇴', continent: 'Europe', capital: 'Oslo', population: '5,5 M', aliases: ['Norway']),
  WorldCountryMeta(iso3: 'NZL', nameFr: 'Nouvelle-Zélande', flag: '🇳🇿', continent: 'Océanie', capital: 'Wellington', population: '5,2 M', aliases: ['New Zealand']),
  WorldCountryMeta(iso3: 'OMN', nameFr: 'Oman', flag: '🇴🇲', continent: 'Asie', capital: 'Mascate', population: '4,6 M'),
  WorldCountryMeta(iso3: 'UZB', nameFr: 'Ouzbékistan', flag: '🇺🇿', continent: 'Asie', capital: 'Tachkent', population: '36 M'),
  WorldCountryMeta(iso3: 'PAN', nameFr: 'Panama', flag: '🇵🇦', continent: 'Amériques', capital: 'Panama', population: '4,4 M'),
  WorldCountryMeta(iso3: 'PRY', nameFr: 'Paraguay', flag: '🇵🇾', continent: 'Amériques', capital: 'Asuncion', population: '6,8 M'),
  WorldCountryMeta(iso3: 'NLD', nameFr: 'Pays-Bas', flag: '🇳🇱', continent: 'Europe', capital: 'Amsterdam', population: '17,8 M', aliases: ['Netherlands', 'Hollande', 'Amsterdam']),
  WorldCountryMeta(iso3: 'PER', nameFr: 'Pérou', flag: '🇵🇪', continent: 'Amériques', capital: 'Lima', population: '34 M', aliases: ['Peru']),
  WorldCountryMeta(iso3: 'PHL', nameFr: 'Philippines', flag: '🇵🇭', continent: 'Asie', capital: 'Manille', population: '117 M'),
  WorldCountryMeta(iso3: 'POL', nameFr: 'Pologne', flag: '🇵🇱', continent: 'Europe', capital: 'Varsovie', population: '37 M', aliases: ['Poland']),
  WorldCountryMeta(iso3: 'PRT', nameFr: 'Portugal', flag: '🇵🇹', continent: 'Europe', capital: 'Lisbonne', population: '10,4 M', aliases: ['Madère', 'Madere', 'Lisbonne']),
  WorldCountryMeta(iso3: 'QAT', nameFr: 'Qatar', flag: '🇶🇦', continent: 'Asie', capital: 'Doha', population: '2,7 M'),
  WorldCountryMeta(iso3: 'DOM', nameFr: 'République dominicaine', flag: '🇩🇴', continent: 'Amériques', capital: 'Saint-Domingue', population: '11,3 M'),
  WorldCountryMeta(iso3: 'ROU', nameFr: 'Roumanie', flag: '🇷🇴', continent: 'Europe', capital: 'Bucarest', population: '19 M', aliases: ['Romania']),
  WorldCountryMeta(iso3: 'GBR', nameFr: 'Royaume-Uni', flag: '🇬🇧', continent: 'Europe', capital: 'Londres', population: '67,7 M', aliases: ['Angleterre', 'United Kingdom', 'UK', 'Ecosse', 'Londres', 'England']),
  WorldCountryMeta(iso3: 'RUS', nameFr: 'Russie', flag: '🇷🇺', continent: 'Europe', capital: 'Moscou', population: '144 M', aliases: ['Russia']),
  WorldCountryMeta(iso3: 'SEN', nameFr: 'Sénégal', flag: '🇸🇳', continent: 'Afrique', capital: 'Dakar', population: '18 M', aliases: ['Senegal']),
  WorldCountryMeta(iso3: 'SRB', nameFr: 'Serbie', flag: '🇷🇸', continent: 'Europe', capital: 'Belgrade', population: '6,6 M'),
  WorldCountryMeta(iso3: 'SYC', nameFr: 'Seychelles', flag: '🇸🇨', continent: 'Afrique', capital: 'Victoria', population: '0,1 M'),
  WorldCountryMeta(iso3: 'SGP', nameFr: 'Singapour', flag: '🇸🇬', continent: 'Asie', capital: 'Singapour', population: '5,9 M', aliases: ['Singapore']),
  WorldCountryMeta(iso3: 'SVK', nameFr: 'Slovaquie', flag: '🇸🇰', continent: 'Europe', capital: 'Bratislava', population: '5,4 M'),
  WorldCountryMeta(iso3: 'SVN', nameFr: 'Slovénie', flag: '🇸🇮', continent: 'Europe', capital: 'Ljubljana', population: '2,1 M'),
  WorldCountryMeta(iso3: 'LKA', nameFr: 'Sri Lanka', flag: '🇱🇰', continent: 'Asie', capital: 'Sri Jayawardenapura', population: '22 M'),
  WorldCountryMeta(iso3: 'SWE', nameFr: 'Suède', flag: '🇸🇪', continent: 'Europe', capital: 'Stockholm', population: '10,5 M', aliases: ['Sweden']),
  WorldCountryMeta(iso3: 'CHE', nameFr: 'Suisse', flag: '🇨🇭', continent: 'Europe', capital: 'Berne', population: '8,9 M', aliases: ['Switzerland']),
  WorldCountryMeta(iso3: 'TZA', nameFr: 'Tanzanie', flag: '🇹🇿', continent: 'Afrique', capital: 'Dodoma', population: '67 M', aliases: ['Zanzibar']),
  WorldCountryMeta(iso3: 'CZE', nameFr: 'Tchéquie', flag: '🇨🇿', continent: 'Europe', capital: 'Prague', population: '10,8 M', aliases: ['Prague', 'Czechia']),
  WorldCountryMeta(iso3: 'THA', nameFr: 'Thaïlande', flag: '🇹🇭', continent: 'Asie', capital: 'Bangkok', population: '71,8 M', aliases: ['Thailand']),
  WorldCountryMeta(iso3: 'TUN', nameFr: 'Tunisie', flag: '🇹🇳', continent: 'Afrique', capital: 'Tunis', population: '12,4 M', aliases: ['Tunisia', 'Djerba']),
  WorldCountryMeta(iso3: 'TUR', nameFr: 'Turquie', flag: '🇹🇷', continent: 'Asie', capital: 'Ankara', population: '85 M', aliases: ['Turkey']),
  WorldCountryMeta(iso3: 'UKR', nameFr: 'Ukraine', flag: '🇺🇦', continent: 'Europe', capital: 'Kiev', population: '37 M'),
  WorldCountryMeta(iso3: 'URY', nameFr: 'Uruguay', flag: '🇺🇾', continent: 'Amériques', capital: 'Montevideo', population: '3,4 M'),
  WorldCountryMeta(iso3: 'VNM', nameFr: 'Viêt Nam', flag: '🇻🇳', continent: 'Asie', capital: 'Hanoï', population: '99 M', aliases: ['Vietnam', 'Viet Nam']),
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

  for (final c in kWorldCountries) {
    if (normalizeCountryKey(c.nameFr) == norm) return c;
    for (final a in c.aliases) {
      if (normalizeCountryKey(a) == norm) return c;
    }
  }
  final firstSegment = normalizeCountryKey(rawName.split(RegExp(r'[-–—(:]')).first);
  if (firstSegment.isNotEmpty) {
    for (final c in kWorldCountries) {
      if (normalizeCountryKey(c.nameFr) == firstSegment) return c;
      for (final a in c.aliases) {
        if (normalizeCountryKey(a) == firstSegment) return c;
      }
    }
  }
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
  final Offset centerNorm;
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
  double _currentZoom = 1.0;
  String _selectedContinent = 'Monde';
  String? _highlightedIso;
  bool _showListMode = false;
  Size _lastViewportSize = const Size(800, 420);

  @override
  void initState() {
    super.initState();
    _transformController.addListener(_onTransformChanged);
    _loadGeoJson();
  }

  void _onTransformChanged() {
    final nextZoom = _transformController.value.getMaxScaleOnAxis();
    if ((nextZoom - _currentZoom).abs() > 0.05) {
      setState(() => _currentZoom = nextZoom);
    }
  }

  @override
  void dispose() {
    _transformController.removeListener(_onTransformChanged);
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
    } catch (_) {}
  }

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
    final Offset normTarget;
    final double zoom;
    switch (continent) {
      case 'Europe':
        normTarget = _project(12, 47);
        zoom = 3.6;
        break;
      case 'Afrique':
        normTarget = _project(18, 6);
        zoom = 2.5;
        break;
      case 'Amériques':
        normTarget = _project(-72, 2);
        zoom = 2.0;
        break;
      case 'Asie':
        normTarget = _project(88, 30);
        zoom = 2.4;
        break;
      case 'Océanie':
        normTarget = _project(138, -24);
        zoom = 2.8;
        break;
      default:
        normTarget = const Offset(0.5, 0.5);
        zoom = 1.0;
    }
    final mapBox = _computeMapBoxSize(viewportSize);
    final offsetX = (viewportSize.width - mapBox.width) / 2;
    final offsetY = (viewportSize.height - mapBox.height) / 2;
    final cx = offsetX + normTarget.dx * mapBox.width;
    final cy = offsetY + normTarget.dy * mapBox.height;
    final tx = viewportSize.width / 2 - cx * zoom;
    final ty = viewportSize.height / 2 - cy * zoom;
    final matrix = Matrix4.identity()
      ..translate(
        tx.clamp(-viewportSize.width * (zoom - 1), 0.0),
        ty.clamp(-viewportSize.height * (zoom - 1), 0.0),
      )
      ..scale(zoom);
    _transformController.value = matrix;
  }

  void _stepZoom(double factor) {
    final currentScale = _transformController.value.getMaxScaleOnAxis();
    final targetScale = (currentScale * factor).clamp(1.0, 7.0);
    if ((targetScale - currentScale).abs() < 0.01) return;
    if (targetScale <= 1.02) {
      _transformController.value = Matrix4.identity();
      return;
    }
    final ratio = targetScale / currentScale;
    final cx = _lastViewportSize.width / 2;
    final cy = _lastViewportSize.height / 2;
    final focal = Matrix4.identity()
      ..translate(cx, cy)
      ..scale(ratio)
      ..translate(-cx, -cy);
    _transformController.value = focal * _transformController.value;
  }

  Size _computeMapBoxSize(Size viewport) {
    // On mobile portrait, render map wider than viewport so it fills vertically nicely & can pan/zoom cleanly
    const aspect = 1200.0 / 620.0;
    final maxW = viewport.width;
    final maxH = viewport.height;
    double boxW = maxW;
    double boxH = boxW / aspect;
    if (boxH > maxH) {
      boxH = maxH;
      boxW = boxH * aspect;
    }
    return Size(math.max(boxW, 300), math.max(boxH, 200));
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

  void _zoomToCanvasPoint(Offset scenePoint, Size mapBoxSize, double targetZoom) {
    final zoom = targetZoom.clamp(1.0, 7.0);
    final offsetX = (_lastViewportSize.width - mapBoxSize.width) / 2;
    final offsetY = (_lastViewportSize.height - mapBoxSize.height) / 2;
    final cx = offsetX + scenePoint.dx;
    final cy = offsetY + scenePoint.dy;
    final tx = _lastViewportSize.width / 2 - cx * zoom;
    final ty = _lastViewportSize.height / 2 - cy * zoom;
    final matrix = Matrix4.identity()
      ..translate(
        tx.clamp(-_lastViewportSize.width * (zoom - 1), 0.0),
        ty.clamp(-_lastViewportSize.height * (zoom - 1), 0.0),
      )
      ..scale(zoom);
    _transformController.value = matrix;
  }

  void _handleMapTap(TapUpDetails details, Size mapBoxSize, Map<String, CountryVisitStats> visitedByIso) {
    final shapes = _shapes;
    if (shapes == null) return;

    // GestureDetector is inside InteractiveViewer, so localPosition is already in mapBoxSize coordinates.
    final scenePoint = details.localPosition;
    final normPoint = Offset(
      (scenePoint.dx / mapBoxSize.width).clamp(0.0, 1.0),
      (scenePoint.dy / mapBoxSize.height).clamp(0.0, 1.0),
    );

    final currentScale = _transformController.value.getMaxScaleOnAxis();
    final clusters = _buildMapClusters(
      shapes: shapes,
      visitedByIso: visitedByIso,
      canvasSize: mapBoxSize,
      currentZoom: currentScale,
    );

    // 1. Check cluster/country badges first (generous mobile touch radius)
    final tapRadiusCanvas = 26.0 / currentScale.clamp(1.0, 5.0);
    _MapCluster? hitCluster;
    double bestClusterDist = double.infinity;
    for (final cl in clusters) {
      final d = (cl.centerCanvas - scenePoint).distance;
      if (d <= tapRadiusCanvas && d < bestClusterDist) {
        bestClusterDist = d;
        hitCluster = cl;
      }
    }
    if (hitCluster != null) {
      if (hitCluster.continentName != null) {
        _focusContinent(hitCluster.continentName!, _lastViewportSize);
        return;
      }
      if (hitCluster.countries.length > 1) {
        _zoomToCanvasPoint(hitCluster.centerCanvas, mapBoxSize, math.max(currentScale * 1.85, 3.0));
        return;
      }
      _openCountryDetails(hitCluster.countries.first);
      return;
    }

    for (final s in shapes) {
      if (!visitedByIso.containsKey(s.iso3)) continue;
      for (final poly in s.polygonsNorm) {
        if (_pointInPolygon(normPoint, poly)) {
          _openCountryDetails(visitedByIso[s.iso3]!);
          return;
        }
      }
    }

    for (final s in shapes) {
      for (final poly in s.polygonsNorm) {
        if (_pointInPolygon(normPoint, poly)) {
          final meta = kCountriesByIso[s.iso3];
          final label = meta != null ? '${meta.flag} ${meta.nameFr}' : s.name;
          setState(() => _highlightedIso = s.iso3);
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFFFFFFFF),
              behavior: SnackBarBehavior.floating,
              content: Text(
                '$label — aucun album ou média pour le moment',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
              action: SnackBarAction(
                label: 'Ajouter',
                textColor: const Color(0xFFF97316),
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
        backgroundColor: const Color(0xFFFFFFFF),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) => DraggableScrollableSheet(
          initialChildSize: 0.72,
          minChildSize: 0.42,
          maxChildSize: 0.94,
          expand: false,
          builder: (_, scrollCtrl) => _CountryDetailSheet(
            stats: stats,
            scrollController: scrollCtrl,
            onOpenAlbum: (id) {
              Navigator.of(ctx).pop();
              widget.onOpenAlbum(id);
            },
            onOpenCountryMedia: () {
              Navigator.of(ctx).pop();
              widget.onOpenCountryMedia(stats);
            },
            onClose: () => Navigator.of(ctx).pop(),
          ),
        ),
      );
    } else {
      showDialog<void>(
        context: context,
        builder: (ctx) => Dialog(
          backgroundColor: const Color(0xFFFFFFFF),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xFFEBDDC6)),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540, maxHeight: 680),
            child: _CountryDetailSheet(
              stats: stats,
              scrollController: ScrollController(),
              onOpenAlbum: (id) {
                Navigator.of(ctx).pop();
                widget.onOpenAlbum(id);
              },
              onOpenCountryMedia: () {
                Navigator.of(ctx).pop();
                widget.onOpenCountryMedia(stats);
              },
              onClose: () => Navigator.of(ctx).pop(),
            ),
          ),
        ),
      );
    }
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
        Container(
          padding: EdgeInsets.fromLTRB(isCompact ? 12 : 20, 10, isCompact ? 12 : 20, 8),
          decoration: const BoxDecoration(
            color: Color(0xFFFFF7E8),
            border: Border(bottom: BorderSide(color: Color(0xFFF1E6D2))),
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
                          const Color(0xFFF97316),
                        ),
                        _summaryPill(
                          Icons.photo_outlined,
                          '${widget.totalPhotos}',
                          const Color(0xFF0284C7),
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
                          color: Color(0xFFF6EFE2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Color(0xFFEBDDC6)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _showListMode ? Icons.map_outlined : Icons.format_list_bulleted_rounded,
                              size: 16,
                              color: const Color(0xFF1E293B),
                            ),
                            if (!isCompact) ...[
                              const SizedBox(width: 6),
                              Text(
                                _showListMode ? 'Carte' : 'Liste',
                                style: const TextStyle(fontSize: 12, color: const Color(0xFF1E293B)),
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
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: ['Monde', 'Europe', 'Afrique', 'Amériques', 'Asie', 'Océanie'].map((cont) {
                    final selected = _selectedContinent == cont;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(cont),
                        selected: selected,
                        onSelected: (_) => _focusContinent(cont, _lastViewportSize),
                        labelStyle: TextStyle(
                          fontSize: 11.5,
                          fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                          color: selected ? Colors.white : Color(0xFF475569),
                        ),
                        backgroundColor: const Color(0xFFF6EFE2),
                        selectedColor: const Color(0xFF0EA5E9).withOpacity(0.35),
                        side: BorderSide(
                          color: selected ? const Color(0xFFF97316) : Color(0xFFEBDDC6),
                        ),
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
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
          style: TextStyle(color: Color(0xFF64748B)),
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
          color: const Color(0xFFFFFFFF),
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => _openCountryDetails(c),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFF97316).withOpacity(0.25)),
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
                            color: const Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${c.meta.capital} · ${c.albums.length} album${c.albums.length > 1 ? 's' : ''}',
                          style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
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
                          color: Color(0xFFF97316),
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
                  const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
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
        child: CircularProgressIndicator(color: Color(0xFFF97316)),
      );
    }

    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              LayoutBuilder(
                builder: (ctx, constraints) {
                  _lastViewportSize = Size(constraints.maxWidth, constraints.maxHeight);
                  final mapBoxSize = _computeMapBoxSize(_lastViewportSize);

                  return Container(
                    width: constraints.maxWidth,
                    height: constraints.maxHeight,
                    decoration: const BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment(0, -0.1),
                        radius: 1.15,
                        colors: [Color(0xFFE0F7FA), Color(0xFFBAE6FD)],
                      ),
                    ),
                    child: InteractiveViewer(
                      transformationController: _transformController,
                      minScale: 1.0,
                      maxScale: 7.0,
                      boundaryMargin: const EdgeInsets.all(80),
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
                                currentZoom: _currentZoom,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              Positioned(
                right: 12,
                bottom: 12,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FloatingActionButton.small(
                      heroTag: 'map_zoom_in',
                      backgroundColor: const Color(0xFFFFFFFF).withOpacity(0.9),
                      foregroundColor: Colors.white,
                      tooltip: 'Zoomer',
                      onPressed: () => _stepZoom(1.5),
                      child: const Icon(Icons.add, size: 18),
                    ),
                    const SizedBox(height: 6),
                    FloatingActionButton.small(
                      heroTag: 'map_zoom_out',
                      backgroundColor: const Color(0xFFFFFFFF).withOpacity(0.9),
                      foregroundColor: Color(0xFF475569),
                      tooltip: 'Dézoomer',
                      onPressed: () => _stepZoom(0.66),
                      child: const Icon(Icons.remove, size: 18),
                    ),
                    const SizedBox(height: 6),
                    FloatingActionButton.small(
                      heroTag: 'map_reset_zoom',
                      backgroundColor: const Color(0xFFFFFFFF).withOpacity(0.9),
                      foregroundColor: const Color(0xFFF97316),
                      tooltip: 'Réinitialiser la vue',
                      onPressed: () {
                        setState(() => _selectedContinent = 'Monde');
                        _transformController.value = Matrix4.identity();
                      },
                      child: const Icon(Icons.fit_screen_rounded, size: 18),
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 12,
                top: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7E8).withOpacity(0.84),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Color(0xFFF1E6D2)),
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
                              color: const Color(0xFFF97316).withOpacity(0.6),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _currentZoom < 1.55
                            ? 'Vue Continents · Touchez un compteur pour zoomer'
                            : (_currentZoom < 2.8
                                ? 'Vue Régions · Zoomez pour diviser les groupes'
                                : 'Pays visités · Touchez un pays pour les détails'),
                        style: const TextStyle(fontSize: 11, color: Color(0xFF475569)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Container(
          height: isCompact ? 62 : 66,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: const BoxDecoration(
            color: Color(0xFFFFF7E8),
            border: Border(top: BorderSide(color: Color(0xFFF1E6D2))),
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
                        : const Color(0xFFF6EFE2).withOpacity(0.8),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFFF97316)
                          : const Color(0xFFF97316).withOpacity(0.28),
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
                              color: const Color(0xFF1E293B),
                            ),
                          ),
                          Text(
                            '${c.photoCount}p${c.videoCount > 0 ? ' · ${c.videoCount}v' : ''}',
                            style: const TextStyle(fontSize: 10, color: Color(0xFF0284C7)),
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

class _CountryDetailSheet extends StatefulWidget {
  final CountryVisitStats stats;
  final ScrollController scrollController;
  final void Function(String albumId) onOpenAlbum;
  final VoidCallback onOpenCountryMedia;
  final VoidCallback onClose;

  const _CountryDetailSheet({
    required this.stats,
    required this.scrollController,
    required this.onOpenAlbum,
    required this.onOpenCountryMedia,
    required this.onClose,
  });

  @override
  State<_CountryDetailSheet> createState() => _CountryDetailSheetState();
}

class _CountryDetailSheetState extends State<_CountryDetailSheet> {
  int _slideIndex = 0;

  @override
  Widget build(BuildContext context) {
    final stats = widget.stats;
    final slides = stats.slideshowPhotos;
    final currentSlide = slides.isNotEmpty ? slides[_slideIndex % slides.length] : null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 10),
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Color(0xFFCBD5E1),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 14, 10),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: const Color(0xFF0EA5E9).withOpacity(0.16),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFF97316).withOpacity(0.45)),
                ),
                alignment: Alignment.center,
                child: Text(stats.meta.flag, style: const TextStyle(fontSize: 28)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stats.meta.nameFr,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 10,
                      runSpacing: 4,
                      children: [
                        _infoChip(Icons.location_city_outlined, stats.meta.capital, const Color(0xFFCBD5E1)),
                        _infoChip(Icons.groups_outlined, stats.meta.population, const Color(0xFFCBD5E1)),
                        _infoChip(Icons.public_rounded, stats.meta.continent, const Color(0xFF94A3B8)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 10,
                      runSpacing: 4,
                      children: [
                        _infoChip(Icons.photo_library_outlined, '${stats.photoCount} photos', const Color(0xFFF97316)),
                        if (stats.videoCount > 0)
                          _infoChip(Icons.videocam_outlined, '${stats.videoCount} vidéos', const Color(0xFFA78BFA)),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: widget.onClose,
                icon: const Icon(Icons.close, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: Color(0xFFF1E6D2)),
        Expanded(
          child: ListView(
            controller: widget.scrollController,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            children: [
              // Travel Dates (from / to) for countries other than France
              if (stats.meta.iso3 != 'FRA' && stats.travelDateRanges.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0EA5E9).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFF97316).withOpacity(0.28)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.flight_takeoff_rounded, size: 15, color: Color(0xFFF97316)),
                          SizedBox(width: 6),
                          Text(
                            'DATES DES VOYAGES',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.9,
                              color: Color(0xFF0284C7),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: stats.travelDateRanges
                            .map(
                              (r) => Container(
                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFFFFF),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Color(0xFFEBDDC6)),
                                ),
                                child: Text(
                                  r,
                                  style: const TextStyle(fontSize: 11.5, color: const Color(0xFF1E293B), fontWeight: FontWeight.w500),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ),
                ),
              ],

              // Slideshow ("mode diapo" with prev/next arrows from Thématique / Pays)
              if (currentSlide != null && (currentSlide.largePreviewUrl ?? currentSlide.thumbnailUrl) != null) ...[
                Row(
                  children: [
                    const Text(
                      'DIAPORAMA (THÉMATIQUE PAYS)',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${(_slideIndex % slides.length) + 1} / ${slides.length}',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF0284C7), fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  height: 200,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Color(0xFFEBDDC6)),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(
                        currentSlide.largePreviewUrl ?? currentSlide.thumbnailUrl!,
                        key: ValueKey(currentSlide.id),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Center(
                          child: Icon(Icons.image_outlined, color: Color(0xFFCBD5E1), size: 36),
                        ),
                      ),
                      Positioned(
                        left: 8,
                        top: 0,
                        bottom: 0,
                        child: Center(
                          child: CircleAvatar(
                            radius: 18,
                            backgroundColor: Colors.black.withOpacity(0.6),
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              icon: const Icon(Icons.chevron_left, color: Colors.white),
                              onPressed: () {
                                setState(() {
                                  _slideIndex = (_slideIndex - 1 + slides.length) % slides.length;
                                });
                              },
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        right: 8,
                        top: 0,
                        bottom: 0,
                        child: Center(
                          child: CircleAvatar(
                            radius: 18,
                            backgroundColor: Colors.black.withOpacity(0.6),
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              icon: const Icon(Icons.chevron_right, color: Colors.white),
                              onPressed: () {
                                setState(() {
                                  _slideIndex = (_slideIndex + 1) % slides.length;
                                });
                              },
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [Colors.black.withOpacity(0.8), Colors.transparent],
                            ),
                          ),
                          child: Text(
                            currentSlide.filename,
                            style: const TextStyle(fontSize: 11, color: Color(0xFF475569)),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              Row(
                children: [
                  const Text(
                    'ALBUMS & DOSSIERS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${stats.albums.length} ${stats.albums.length > 1 ? 'éléments' : 'élément'}',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (stats.albums.isEmpty)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Color(0xFFFFF7E8),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Color(0xFFF1E6D2)),
                  ),
                  child: const Text(
                    'Pays détecté via les métadonnées des photos (aucun album dédié assigné).',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                )
              else
                ...stats.albums.map((alb) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Material(
                      color: const Color(0xFFF6EFE2).withOpacity(0.75),
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => widget.onOpenAlbum(alb.albumId),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          child: Row(
                            children: [
                              Icon(
                                alb.isFolder ? Icons.folder_rounded : Icons.photo_album_outlined,
                                color: alb.isFolder ? const Color(0xFFFBBF24) : const Color(0xFFF97316),
                                size: 22,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            alb.name,
                                            style: const TextStyle(
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.w600,
                                              color: const Color(0xFF1E293B),
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: alb.sourceLabel == 'Années'
                                                ? const Color(0xFF6366F1).withOpacity(0.25)
                                                : const Color(0xFF0EA5E9).withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            alb.sourceLabel,
                                            style: TextStyle(
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.w600,
                                              color: alb.sourceLabel == 'Années'
                                                  ? const Color(0xFFA5B4FC)
                                                  : const Color(0xFF0284C7),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        if (alb.dateHint != null) ...[
                                          const Icon(Icons.calendar_today_outlined, size: 11, color: Color(0xFFF97316)),
                                          const SizedBox(width: 4),
                                          Text(
                                            alb.dateHint!,
                                            style: const TextStyle(fontSize: 11, color: Color(0xFF0284C7)),
                                          ),
                                          const SizedBox(width: 10),
                                        ],
                                        Text(
                                          '${alb.photoCount} photos${alb.videoCount > 0 ? ' · ${alb.videoCount} vidéos' : ''}',
                                          style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8), size: 20),
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
              onPressed: widget.onOpenCountryMedia,
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

  Widget _infoChip(IconData icon, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12.5, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 11.5, color: color, fontWeight: FontWeight.w500)),
      ],
    );
  }
}

class _MapCluster {
  final Offset centerCanvas;
  final List<CountryVisitStats> countries;
  final int totalMedia;
  final String? continentName;

  const _MapCluster({
    required this.centerCanvas,
    required this.countries,
    required this.totalMedia,
    this.continentName,
  });
}

Offset _continentNormCenter(String continent) {
  switch (continent) {
    case 'Europe':
      return _WorldMapTabState._project(12, 50);
    case 'Afrique':
      return _WorldMapTabState._project(18, 6);
    case 'Amériques':
      return _WorldMapTabState._project(-68, -4);
    case 'Asie':
      return _WorldMapTabState._project(88, 34);
    case 'Océanie':
      return _WorldMapTabState._project(138, -24);
    default:
      return const Offset(0.5, 0.5);
  }
}

List<_MapCluster> _buildMapClusters({
  required List<_CountryGeoShape> shapes,
  required Map<String, CountryVisitStats> visitedByIso,
  required Size canvasSize,
  required double currentZoom,
}) {
  // Level 1: Continent-level cumulative counters when zoomed out
  if (currentZoom < 1.55) {
    final Map<String, List<CountryVisitStats>> byContinent = {};
    for (final c in visitedByIso.values) {
      byContinent.putIfAbsent(c.meta.continent, () => []).add(c);
    }
    return byContinent.entries.map((entry) {
      final norm = _continentNormCenter(entry.key);
      final total = entry.value.fold<int>(0, (acc, c) => acc + c.totalMedia);
      return _MapCluster(
        centerCanvas: Offset(norm.dx * canvasSize.width, norm.dy * canvasSize.height),
        countries: entry.value,
        totalMedia: total,
        continentName: entry.key,
      );
    }).toList();
  }

  // Gather individual country positions sorted by media count descending
  final visitedShapes = shapes.where((s) => visitedByIso.containsKey(s.iso3)).toList()
    ..sort((a, b) => visitedByIso[b.iso3]!.totalMedia.compareTo(visitedByIso[a.iso3]!.totalMedia));

  // Level 3: Individual country counters when zoomed in >= 2.8x
  if (currentZoom >= 2.8) {
    return visitedShapes.map((s) {
      final stats = visitedByIso[s.iso3]!;
      return _MapCluster(
        centerCanvas: Offset(s.centerNorm.dx * canvasSize.width, s.centerNorm.dy * canvasSize.height),
        countries: [stats],
        totalMedia: stats.totalMedia,
      );
    }).toList();
  }

  // Level 2: Dynamic spatial clustering between 1.55x and 2.8x — nearby countries merge & sum!
  final mergeRadiusCanvas = (canvasSize.width < 550 ? 32.0 : 28.0) / currentZoom;
  final clusters = <({Offset sumPos, List<CountryVisitStats> list, int total})>[];

  for (final s in visitedShapes) {
    final stats = visitedByIso[s.iso3]!;
    final pos = Offset(s.centerNorm.dx * canvasSize.width, s.centerNorm.dy * canvasSize.height);
    int targetIdx = -1;
    double bestDist = double.infinity;
    for (int i = 0; i < clusters.length; i++) {
      final clCenter = clusters[i].sumPos / clusters[i].list.length.toDouble();
      final d = (clCenter - pos).distance;
      if (d <= mergeRadiusCanvas && d < bestDist) {
        bestDist = d;
        targetIdx = i;
      }
    }
    if (targetIdx == -1) {
      clusters.add((sumPos: pos, list: [stats], total: stats.totalMedia));
    } else {
      final prev = clusters[targetIdx];
      clusters[targetIdx] = (
        sumPos: prev.sumPos + pos,
        list: [...prev.list, stats],
        total: prev.total + stats.totalMedia,
      );
    }
  }

  return clusters
      .map(
        (cl) => _MapCluster(
          centerCanvas: cl.sumPos / cl.list.length.toDouble(),
          countries: cl.list,
          totalMedia: cl.total,
        ),
      )
      .toList();
}

class _WorldMapPainter extends CustomPainter {
  final List<_CountryGeoShape> shapes;
  final Map<String, CountryVisitStats> visitedByIso;
  final String? highlightedIso;
  final double currentZoom;

  _WorldMapPainter({
    required this.shapes,
    required this.visitedByIso,
    this.highlightedIso,
    this.currentZoom = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = Color(0xFF0284C7).withOpacity(0.08)
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
      ..color = const Color(0xFFF3ECE0)
      ..style = PaintingStyle.fill;
    final unvisitedStroke = Paint()
      ..color = const Color(0xFFD6C7B2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.65;

    final visitedGlow = Paint()
      ..color = const Color(0xFFFBBF24).withOpacity(0.28)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5.5)
      ..style = PaintingStyle.fill;
    final visitedFill = Paint()
      ..color = const Color(0xFF0EA5E9)
      ..style = PaintingStyle.fill;
    final visitedHighlightFill = Paint()
      ..color = const Color(0xFFFBBF24)
      ..style = PaintingStyle.fill;
    final visitedStroke = Paint()
      ..color = const Color(0xFFFFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;

    for (final s in shapes) {
      if (visitedByIso.containsKey(s.iso3)) continue;
      final path = _buildPath(s, size);
      canvas.drawPath(path, unvisitedFill);
      canvas.drawPath(path, unvisitedStroke);
    }

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

    final clusters = _buildMapClusters(
      shapes: shapes,
      visitedByIso: visitedByIso,
      canvasSize: size,
      currentZoom: currentZoom,
    );

    final invScale = 1.0 / math.sqrt(currentZoom.clamp(1.0, 6.0));
    final singleBg = Paint()..color = Colors.white.withOpacity(0.95);
    final singleBorder = Paint()
      ..color = const Color(0xFFFBBF24)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0 * invScale;

    final clusterBg = Paint()..color = const Color(0xFF0E7490).withOpacity(0.95);
    final clusterRing = Paint()
      ..color = const Color(0xFFFBBF24).withOpacity(0.35)
      ..style = PaintingStyle.fill;
    final clusterBorder = Paint()
      ..color = const Color(0xFFFDE68A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1 * invScale;

    for (final cl in clusters) {
      final c = cl.centerCanvas;
      final isCluster = cl.continentName != null || cl.countries.length > 1;
      final String label;
      if (cl.continentName != null) {
        label = '🌴 ${cl.continentName} (${cl.countries.length}) · ${cl.totalMedia}';
      } else if (cl.countries.length > 1) {
        final flags = cl.countries.take(3).map((e) => e.meta.flag).join();
        final extra = cl.countries.length > 3 ? '+${cl.countries.length - 3}' : '';
        label = '$flags$extra · ${cl.totalMedia}';
      } else {
        label = '${cl.countries.first.meta.flag} ${cl.totalMedia}';
      }

      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            fontSize: (isCluster ? 8.2 : 7.8) * invScale,
            fontWeight: FontWeight.w700,
            color: isCluster ? Colors.white : const Color(0xFF1E293B),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final pillW = math.max((isCluster ? 22.0 : 14.0) * invScale, tp.width + 8.0 * invScale);
      final pillH = (isCluster ? 14.0 : 11.0) * invScale;
      final rect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: c, width: pillW, height: pillH),
        Radius.circular(7.0 * invScale),
      );

      if (isCluster) {
        final outerRect = RRect.fromRectAndRadius(
          Rect.fromCenter(center: c, width: pillW + 4.0 * invScale, height: pillH + 4.0 * invScale),
          Radius.circular(9.0 * invScale),
        );
        canvas.drawRRect(outerRect, clusterRing);
        canvas.drawRRect(rect, clusterBg);
        canvas.drawRRect(rect, clusterBorder);
      } else {
        canvas.drawRRect(rect, singleBg);
        canvas.drawRRect(rect, singleBorder);
      }
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
        oldDelegate.shapes != shapes ||
        (oldDelegate.currentZoom - currentZoom).abs() > 0.05;
  }
}