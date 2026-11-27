import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

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
  final String? dateRange;
  final String? coverThumbUrl;
  final int sortTimestamp;
  final String sourceLabel; // e.g. "Pays" or "Années"
  final int photoCount;
  final int videoCount;
  final bool isFolder;

  const CountryAlbumSummary({
    required this.albumId,
    required this.name,
    this.dateHint,
    this.dateRange,
    this.coverThumbUrl,
    this.sortTimestamp = 0,
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
  final CountryAlbumSummary? discoveryAlbum; // Album "02 - Pays" (découverte sans personnes)
  final List<CountryAlbumSummary> albums; // Albums de voyages (Années / Thématiques) triés du plus récent au plus vieux
  final List<CountrySlideshowPhoto> slideshowPhotos;

  const CountryVisitStats({
    required this.meta,
    required this.photoCount,
    required this.videoCount,
    this.discoveryAlbum,
    required this.albums,
    this.slideshowPhotos = const [],
  });

  int get totalMedia => photoCount + videoCount;
}

class MapGeoPhoto {
  final int id;
  final double latitude;
  final double longitude;
  final String? country;
  final String? city;
  final String captureDate;
  final String? thumbnailUrl;

  const MapGeoPhoto({
    required this.id,
    required this.latitude,
    required this.longitude,
    this.country,
    this.city,
    this.captureDate = '',
    this.thumbnailUrl,
  });
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
  final LatLng centerLatLng;
  final List<List<LatLng>> polygonsLatLng;

  const _CountryGeoShape({
    required this.iso3,
    required this.name,
    required this.centerLatLng,
    required this.polygonsLatLng,
  });
}

class WorldMapTab extends StatefulWidget {
  final List<CountryVisitStats> visitedCountries;
  final List<MapGeoPhoto> geoPhotos;
  final int totalPhotos;
  final int totalVideos;
  final bool isVideoMode;
  final VoidCallback onAddCountryFolder;
  final void Function(String albumId) onOpenAlbum;
  final void Function(CountryVisitStats stats) onOpenCountryMedia;

  const WorldMapTab({
    super.key,
    required this.visitedCountries,
    this.geoPhotos = const [],
    required this.totalPhotos,
    required this.totalVideos,
    this.isVideoMode = false,
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
  final MapController _mapController = MapController();
  double _currentZoom = 2.2;
  String _selectedContinent = 'Monde';
  String? _highlightedIso;
  bool _showListMode = false;
  bool _isSatellite = false;
  bool _showRoutes = true;

  @override
  void initState() {
    super.initState();
    _loadGeoJson();
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
        final polys = <List<LatLng>>[];
        for (final pr in polysRaw) {
          final pts = (pr as List<dynamic>)
              .map((pt) => LatLng(
                    (pt[1] as num).toDouble().clamp(-85.0, 85.0),
                    (pt[0] as num).toDouble().clamp(-180.0, 180.0),
                  ))
              .toList();
          if (pts.length >= 3) polys.add(pts);
        }
        if (polys.isEmpty) continue;
        parsed.add(_CountryGeoShape(
          iso3: iso,
          name: name,
          centerLatLng: LatLng(
            (center[1] as num).toDouble().clamp(-85.0, 85.0),
            (center[0] as num).toDouble().clamp(-180.0, 180.0),
          ),
          polygonsLatLng: polys,
        ));
      }
      _cachedShapes = parsed;
      if (mounted) setState(() => _shapes = parsed);
    } catch (_) {}
  }

  void _focusContinent(String continent) {
    setState(() => _selectedContinent = continent);
    if (_showListMode) return;
    final LatLng target;
    final double zoom;
    switch (continent) {
      case 'Europe':
        target = const LatLng(48.0, 12.0);
        zoom = 4.0;
        break;
      case 'Afrique':
        target = const LatLng(6.0, 18.0);
        zoom = 3.2;
        break;
      case 'Amériques':
        target = const LatLng(12.0, -72.0);
        zoom = 2.7;
        break;
      case 'Asie':
        target = const LatLng(30.0, 88.0);
        zoom = 3.2;
        break;
      case 'Océanie':
        target = const LatLng(-24.0, 138.0);
        zoom = 3.6;
        break;
      default:
        target = const LatLng(22.0, 12.0);
        zoom = 2.2;
    }
    _mapController.move(target, zoom);
  }

  void _stepZoom(double delta) {
    final nextZoom = (_currentZoom + delta).clamp(1.5, 16.0);
    _mapController.move(_mapController.camera.center, nextZoom);
  }

  bool _pointInPolygonLatLng(LatLng p, List<LatLng> poly) {
    var inside = false;
    for (int i = 0, j = poly.length - 1; i < poly.length; j = i++) {
      final xi = poly[i].longitude, yi = poly[i].latitude;
      final xj = poly[j].longitude, yj = poly[j].latitude;
      final intersect = ((yi > p.latitude) != (yj > p.latitude)) &&
          (p.longitude <
              (xj - xi) * (p.latitude - yi) / ((yj - yi) == 0 ? 1e-9 : (yj - yi)) + xi);
      if (intersect) inside = !inside;
    }
    return inside;
  }

  void _handleMapTapLatLng(LatLng point, Map<String, CountryVisitStats> visitedByIso) {
    final shapes = _shapes;
    if (shapes == null) return;

    for (final s in shapes) {
      if (!visitedByIso.containsKey(s.iso3)) continue;
      for (final poly in s.polygonsLatLng) {
        if (_pointInPolygonLatLng(point, poly)) {
          _openCountryDetails(visitedByIso[s.iso3]!);
          return;
        }
      }
    }

    for (final s in shapes) {
      for (final poly in s.polygonsLatLng) {
        if (_pointInPolygonLatLng(point, poly)) {
          final meta = kCountriesByIso[s.iso3];
          final label = meta != null ? '${meta.flag} ${meta.nameFr}' : s.name;
          setState(() => _highlightedIso = s.iso3);
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFF1E293B),
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
                          '${widget.visitedCountries.length} pays (${(widget.visitedCountries.length / 195 * 100).clamp(0, 100).toStringAsFixed(0)}%)',
                          const Color(0xFFF97316),
                        ),
                        if (widget.geoPhotos.isNotEmpty)
                          _summaryPill(
                            Icons.gps_fixed_rounded,
                            '${widget.geoPhotos.length} GPS',
                            const Color(0xFF10B981),
                          ),
                        if (!widget.isVideoMode)
                          _summaryPill(
                            Icons.photo_outlined,
                            '${widget.totalPhotos}',
                            const Color(0xFF0284C7),
                          ),
                        if (widget.isVideoMode)
                          _summaryPill(
                            Icons.videocam_outlined,
                            '${widget.totalVideos}',
                            const Color(0xFF8B5CF6),
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
                        onSelected: (_) => _focusContinent(cont),
                        labelStyle: TextStyle(
                          fontSize: 11.5,
                          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                          color: selected ? Colors.white : const Color(0xFF475569),
                        ),
                        backgroundColor: const Color(0xFFF6EFE2),
                        selectedColor: const Color(0xFFF97316),
                        side: BorderSide(
                          color: selected ? const Color(0xFFF97316) : const Color(0xFFEBDDC6),
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

    final shapeByIso = {for (final s in shapes) s.iso3: s};
    final visitedPolygons = _buildVisitedPolygons(shapes, visitedByIso, _highlightedIso);
    final routeLines = (_showRoutes && (widget.geoPhotos.length >= 2 || _currentZoom >= 4.0))
        ? _buildRoutePolylines(
            visitedCountries: widget.visitedCountries,
            shapeByIso: shapeByIso,
            geoPhotos: widget.geoPhotos,
          )
        : const <Polyline>[];
    final markers = _buildPolarstepsMarkers(
      visitedByIso: visitedByIso,
      shapeByIso: shapeByIso,
      geoPhotos: widget.geoPhotos,
      currentZoom: _currentZoom,
      highlightedIso: _highlightedIso,
      onTapContinent: _focusContinent,
      onTapClusterZoom: (center) => _mapController.move(center, (_currentZoom + 1.8).clamp(3.0, 12.0)),
      onTapCountry: (stats) {
        final shape = shapeByIso[stats.meta.iso3];
        if (shape != null && _currentZoom < 4.5) {
          _mapController.move(shape.centerLatLng, 4.5);
        }
        _openCountryDetails(stats);
      },
      onTapGeoStep: (step) {
        _mapController.move(step.center, math.max(_currentZoom, 10.0));
        final matched = step.countryIso != null ? visitedByIso[step.countryIso] : null;
        if (matched != null) {
          _openCountryDetails(matched);
        } else {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFF1E293B),
              behavior: SnackBarBehavior.floating,
              content: Text(
                '${step.label} · ${step.count} photo${step.count > 1 ? 's' : ''}',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      },
    );

    final tileUrl = _isSatellite
        ? 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'
        : 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Topo_Map/MapServer/tile/{z}/{y}/{x}';

    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: const LatLng(22.0, 12.0),
                  initialZoom: 2.2,
                  minZoom: 1.5,
                  maxZoom: 16.0,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                  ),
                  onPositionChanged: (pos, hasGesture) {
                    if ((pos.zoom - _currentZoom).abs() > 0.12) {
                      setState(() => _currentZoom = pos.zoom);
                    }
                  },
                  onTap: (_, latLng) => _handleMapTapLatLng(latLng, visitedByIso),
                ),
                children: [
                  TileLayer(
                    urlTemplate: tileUrl,
                    userAgentPackageName: 'com.gallerie.mediasfamilly',
                    maxZoom: 18,
                  ),
                  if (visitedPolygons.isNotEmpty)
                    PolygonLayer(polygons: visitedPolygons),
                  if (routeLines.isNotEmpty)
                    PolylineLayer(polylines: routeLines),
                  MarkerLayer(markers: markers),
                ],
              ),
              Positioned(
                right: 12,
                bottom: 12,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FloatingActionButton.small(
                      heroTag: 'map_style_toggle',
                      backgroundColor: _isSatellite
                          ? const Color(0xFF0EA5E9)
                          : Colors.white.withValues(alpha: 0.95),
                      foregroundColor: _isSatellite ? Colors.white : const Color(0xFF1E293B),
                      tooltip: _isSatellite ? 'Fond Plan (Voyager)' : 'Fond Satellite',
                      onPressed: () => setState(() => _isSatellite = !_isSatellite),
                      child: Icon(_isSatellite ? Icons.map_outlined : Icons.satellite_alt_rounded, size: 18),
                    ),
                    const SizedBox(height: 6),
                    FloatingActionButton.small(
                      heroTag: 'map_routes_toggle',
                      backgroundColor: _showRoutes
                          ? const Color(0xFFF97316)
                          : Colors.white.withValues(alpha: 0.95),
                      foregroundColor: _showRoutes ? Colors.white : const Color(0xFF1E293B),
                      tooltip: _showRoutes ? 'Masquer l\'itinéraire' : 'Afficher l\'itinéraire',
                      onPressed: () => setState(() => _showRoutes = !_showRoutes),
                      child: const Icon(Icons.route_rounded, size: 18),
                    ),
                    const SizedBox(height: 6),
                    FloatingActionButton.small(
                      heroTag: 'map_zoom_in',
                      backgroundColor: Colors.white.withValues(alpha: 0.95),
                      foregroundColor: const Color(0xFF1E293B),
                      tooltip: 'Zoomer',
                      onPressed: () => _stepZoom(1.2),
                      child: const Icon(Icons.add, size: 18),
                    ),
                    const SizedBox(height: 6),
                    FloatingActionButton.small(
                      heroTag: 'map_zoom_out',
                      backgroundColor: Colors.white.withValues(alpha: 0.95),
                      foregroundColor: const Color(0xFF1E293B),
                      tooltip: 'Dézoomer',
                      onPressed: () => _stepZoom(-1.2),
                      child: const Icon(Icons.remove, size: 18),
                    ),
                    const SizedBox(height: 6),
                    FloatingActionButton.small(
                      heroTag: 'map_reset_zoom',
                      backgroundColor: Colors.white.withValues(alpha: 0.95),
                      foregroundColor: const Color(0xFFF97316),
                      tooltip: 'Réinitialiser la vue',
                      onPressed: () => _focusContinent('Monde'),
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
                    color: Colors.white.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 9,
                        height: 9,
                        decoration: const BoxDecoration(
                          color: Color(0xFFF97316),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _currentZoom < 3.0
                            ? 'Vue Monde · Touchez un groupe pour zoomer'
                            : (_currentZoom >= 5.8 && widget.geoPhotos.isNotEmpty
                                ? 'Étapes GPS & Pays · Touchez un pin'
                                : 'Pays visités · Touchez une vignette'),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF334155),
                        ),
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
                onTap: () {
                  final shape = shapeByIso[c.meta.iso3];
                  if (shape != null) {
                    _mapController.move(shape.centerLatLng, math.max(_currentZoom, 4.5));
                  }
                  _openCountryDetails(c);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF0EA5E9).withValues(alpha: 0.24)
                        : const Color(0xFFF6EFE2).withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFFF97316)
                          : const Color(0xFFF97316).withValues(alpha: 0.28),
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
                              color: Color(0xFF1E293B),
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
                        _infoChip(Icons.location_city_outlined, stats.meta.capital, const Color(0xFF475569)),
                        _infoChip(Icons.groups_outlined, stats.meta.population, const Color(0xFF475569)),
                        _infoChip(Icons.public_rounded, stats.meta.continent, const Color(0xFF64748B)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 10,
                      runSpacing: 4,
                      children: [
                        if (stats.photoCount > 0)
                          _infoChip(Icons.photo_library_outlined, '${stats.photoCount} photos', const Color(0xFFF97316)),
                        if (stats.videoCount > 0)
                          _infoChip(Icons.videocam_outlined, '${stats.videoCount} vidéos', const Color(0xFF8B5CF6)),
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
              // Slideshow ("mode diapo" with prev/next arrows from Thématique / Pays)
              if (currentSlide != null && (currentSlide.largePreviewUrl ?? currentSlide.thumbnailUrl) != null) ...[
                Row(
                  children: [
                    const Text(
                      'DÉCOUVERTE DU PAYS (DIAPORAMA)',
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
                            style: const TextStyle(fontSize: 11, color: Colors.white),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],

              if (stats.discoveryAlbum != null) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF0284C7),
                      backgroundColor: const Color(0xFFE0F2FE),
                      side: const BorderSide(color: Color(0xFF7DD3FC)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => widget.onOpenAlbum(stats.discoveryAlbum!.albumId),
                    icon: const Icon(Icons.explore_rounded, size: 18),
                    label: Text(
                      'Découverte du pays (${stats.discoveryAlbum!.photoCount} photos sans personnes)',
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],

              Row(
                children: [
                  const Text(
                    'ALBUMS DE VACANCES',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${stats.albums.length} ${stats.albums.length > 1 ? 'albums' : 'album'}',
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
                    'Aucun album de voyage rattaché pour le moment.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                )
              else
                ...stats.albums.map((alb) {
                  final dateLabel = alb.dateRange ?? alb.dateHint;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Material(
                      color: const Color(0xFFF6EFE2).withOpacity(0.75),
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => widget.onOpenAlbum(alb.albumId),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  width: 46,
                                  height: 46,
                                  color: Colors.white,
                                  child: alb.coverThumbUrl != null
                                      ? Image.network(alb.coverThumbUrl!, fit: BoxFit.cover, cacheWidth: 100)
                                      : Icon(
                                          alb.isFolder ? Icons.folder_rounded : Icons.photo_album_outlined,
                                          color: alb.isFolder ? const Color(0xFFFBBF24) : const Color(0xFFF97316),
                                          size: 22,
                                        ),
                                ),
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
                                              color: Color(0xFF1E293B),
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: alb.sourceLabel == 'Années'
                                                ? const Color(0xFF6366F1).withOpacity(0.16)
                                                : const Color(0xFF0EA5E9).withOpacity(0.16),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            alb.sourceLabel,
                                            style: TextStyle(
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.w600,
                                              color: alb.sourceLabel == 'Années'
                                                  ? const Color(0xFF4F46E5)
                                                  : const Color(0xFF0284C7),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        if (dateLabel != null) ...[
                                          const Icon(Icons.calendar_today_outlined, size: 11, color: Color(0xFFF97316)),
                                          const SizedBox(width: 4),
                                          Flexible(
                                            child: Text(
                                              dateLabel,
                                              style: const TextStyle(fontSize: 11, color: Color(0xFFEA580C), fontWeight: FontWeight.w500),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                        ],
                                        Text(
                                          '${alb.photoCount > 0 ? '${alb.photoCount} photos' : ''}${alb.photoCount > 0 && alb.videoCount > 0 ? ' · ' : ''}${alb.videoCount > 0 ? '${alb.videoCount} vidéos' : ''}',
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

class _GeoStepPin {
  final LatLng center;
  final String label;
  final String? thumbUrl;
  final int count;
  final String? countryIso;
  final String captureDate;

  const _GeoStepPin({
    required this.center,
    required this.label,
    this.thumbUrl,
    required this.count,
    this.countryIso,
    this.captureDate = '',
  });
}

LatLng _continentLatLngCenter(String continent) {
  switch (continent) {
    case 'Europe':
      return const LatLng(49.0, 12.0);
    case 'Afrique':
      return const LatLng(6.0, 18.0);
    case 'Amériques':
      return const LatLng(12.0, -72.0);
    case 'Asie':
      return const LatLng(32.0, 88.0);
    case 'Océanie':
      return const LatLng(-24.0, 138.0);
    default:
      return const LatLng(22.0, 12.0);
  }
}

List<Polygon> _buildVisitedPolygons(
  List<_CountryGeoShape> shapes,
  Map<String, CountryVisitStats> visitedByIso,
  String? highlightedIso,
) {
  final polygons = <Polygon>[];
  for (final s in shapes) {
    if (!visitedByIso.containsKey(s.iso3)) continue;
    final isHighlighted = s.iso3 == highlightedIso;
    for (final pts in s.polygonsLatLng) {
      polygons.add(
        Polygon(
          points: pts,
          color: isHighlighted
              ? const Color(0xFFFBBF24).withValues(alpha: 0.34)
              : const Color(0xFF0EA5E9).withValues(alpha: 0.18),
          borderColor: isHighlighted ? const Color(0xFFF97316) : Colors.white.withValues(alpha: 0.85),
          borderStrokeWidth: isHighlighted ? 2.0 : 1.1,
        ),
      );
    }
  }
  return polygons;
}

List<_GeoStepPin> _buildGeoSteps(List<MapGeoPhoto> geoPhotos) {
  if (geoPhotos.isEmpty) return const [];
  final Map<String, List<MapGeoPhoto>> buckets = {};
  for (final p in geoPhotos) {
    final day = p.captureDate.length >= 10 ? p.captureDate.substring(0, 10) : '';
    final latKey = (p.latitude * 20).round(); // ~0.05 deg (~5 km)
    final lonKey = (p.longitude * 20).round();
    final key = '$day|$latKey|$lonKey';
    buckets.putIfAbsent(key, () => []).add(p);
  }

  final steps = <_GeoStepPin>[];
  for (final entry in buckets.values) {
    double sumLat = 0;
    double sumLon = 0;
    String? thumb;
    String? city;
    String? country;
    String dt = '';
    for (final p in entry) {
      sumLat += p.latitude;
      sumLon += p.longitude;
      thumb ??= p.thumbnailUrl;
      city ??= (p.city != null && p.city!.isNotEmpty) ? p.city : null;
      country ??= (p.country != null && p.country!.isNotEmpty) ? p.country : null;
      if (dt.isEmpty && p.captureDate.isNotEmpty) dt = p.captureDate;
    }
    final iso = country != null ? matchCountryMeta(country)?.iso3 : null;
    final label = city ?? country ?? 'Étape GPS';
    steps.add(_GeoStepPin(
      center: LatLng(sumLat / entry.length, sumLon / entry.length),
      label: label,
      thumbUrl: thumb,
      count: entry.length,
      countryIso: iso,
      captureDate: dt,
    ));
  }
  steps.sort((a, b) => a.captureDate.compareTo(b.captureDate));
  return steps;
}

List<Polyline> _buildRoutePolylines({
  required List<CountryVisitStats> visitedCountries,
  required Map<String, _CountryGeoShape> shapeByIso,
  required List<MapGeoPhoto> geoPhotos,
}) {
  final pts = <LatLng>[];
  if (geoPhotos.length >= 2) {
    final steps = _buildGeoSteps(geoPhotos);
    for (final s in steps) {
      pts.add(s.center);
    }
  } else {
    final sorted = [...visitedCountries]..sort((a, b) {
        final ta = a.albums.isNotEmpty ? a.albums.first.sortTimestamp : 0;
        final tb = b.albums.isNotEmpty ? b.albums.first.sortTimestamp : 0;
        return ta.compareTo(tb);
      });
    for (final c in sorted) {
      final shape = shapeByIso[c.meta.iso3];
      if (shape != null) pts.add(shape.centerLatLng);
    }
  }

  if (pts.length < 2) return const [];
  return [
    Polyline(
      points: pts,
      color: Colors.white.withValues(alpha: 0.85),
      strokeWidth: 4.5,
    ),
    Polyline(
      points: pts,
      color: const Color(0xFFF97316),
      strokeWidth: 2.5,
    ),
  ];
}

String? _pickCountryThumb(CountryVisitStats stats) {
  for (final p in stats.slideshowPhotos) {
    if (p.thumbnailUrl != null) return p.thumbnailUrl;
  }
  for (final a in stats.albums) {
    if (a.coverThumbUrl != null) return a.coverThumbUrl;
  }
  return stats.discoveryAlbum?.coverThumbUrl;
}

List<Marker> _buildPolarstepsMarkers({
  required Map<String, CountryVisitStats> visitedByIso,
  required Map<String, _CountryGeoShape> shapeByIso,
  required List<MapGeoPhoto> geoPhotos,
  required double currentZoom,
  required String? highlightedIso,
  required void Function(String continent) onTapContinent,
  required void Function(LatLng center) onTapClusterZoom,
  required void Function(CountryVisitStats stats) onTapCountry,
  required void Function(_GeoStepPin step) onTapGeoStep,
}) {
  // Zoom < 2.5 : Continent summary clusters with Polarsteps photo pin
  if (currentZoom < 2.5) {
    final Map<String, List<CountryVisitStats>> byContinent = {};
    for (final c in visitedByIso.values) {
      byContinent.putIfAbsent(c.meta.continent, () => []).add(c);
    }
    return byContinent.entries.map((entry) {
      final list = [...entry.value]..sort((a, b) => b.totalMedia.compareTo(a.totalMedia));
      final total = list.fold<int>(0, (acc, c) => acc + c.totalMedia);
      final center = _continentLatLngCenter(entry.key);
      final thumb = _pickCountryThumb(list.first);
      return Marker(
        point: center,
        width: 145,
        height: 68,
        child: GestureDetector(
          onTap: () => onTapContinent(entry.key),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _PolarstepsPhotoPin(
                thumbUrl: thumb,
                fallbackText: list.first.meta.flag,
                count: total,
                isHighlighted: false,
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF0E7490).withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white, width: 1.2),
                ),
                child: Text(
                  '${entry.key} (${list.length})',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }).toList();
  }

  // Zoom >= 5.8 and GPS steps exist : show GPS step photo pins + fallback countries without GPS
  if (currentZoom >= 5.8 && geoPhotos.isNotEmpty) {
    final steps = _buildGeoSteps(geoPhotos);
    final markers = <Marker>[];
    final isosWithGps = <String>{};
    for (final s in steps) {
      if (s.countryIso != null) isosWithGps.add(s.countryIso!);
      markers.add(
        Marker(
          point: s.center,
          width: 60,
          height: 60,
          child: GestureDetector(
            onTap: () => onTapGeoStep(s),
            child: _PolarstepsPhotoPin(
              thumbUrl: s.thumbUrl,
              fallbackText: '📍',
              count: s.count,
              isHighlighted: false,
            ),
          ),
        ),
      );
    }
    for (final entry in visitedByIso.entries) {
      if (isosWithGps.contains(entry.key)) continue;
      final shape = shapeByIso[entry.key];
      if (shape == null) continue;
      final stats = entry.value;
      markers.add(
        Marker(
          point: shape.centerLatLng,
          width: 64,
          height: 64,
          child: GestureDetector(
            onTap: () => onTapCountry(stats),
            child: _PolarstepsPhotoPin(
              thumbUrl: _pickCountryThumb(stats),
              fallbackText: stats.meta.flag,
              badgeText: stats.meta.flag,
              count: stats.totalMedia,
              isHighlighted: highlightedIso == stats.meta.iso3,
            ),
          ),
        ),
      );
    }
    return markers;
  }

  // Zoom 3.0..5.8 (or no GPS yet): Polarsteps circular photo pins per country (with spatial merge if < threshold)
  final mergeDeg = 18.0 / currentZoom;
  final visitedShapes = shapeByIso.values
      .where((s) => visitedByIso.containsKey(s.iso3))
      .toList()
    ..sort((a, b) => visitedByIso[b.iso3]!.totalMedia.compareTo(visitedByIso[a.iso3]!.totalMedia));

  final clusters = <({double sumLat, double sumLon, List<CountryVisitStats> list})>[];
  for (final s in visitedShapes) {
    final stats = visitedByIso[s.iso3]!;
    int targetIdx = -1;
    double bestDist = double.infinity;
    for (int i = 0; i < clusters.length; i++) {
      final cLat = clusters[i].sumLat / clusters[i].list.length;
      final cLon = clusters[i].sumLon / clusters[i].list.length;
      final d = math.sqrt(
        math.pow(cLat - s.centerLatLng.latitude, 2) +
            math.pow(cLon - s.centerLatLng.longitude, 2),
      );
      if (d <= mergeDeg && d < bestDist) {
        bestDist = d;
        targetIdx = i;
      }
    }
    if (targetIdx == -1) {
      clusters.add((
        sumLat: s.centerLatLng.latitude,
        sumLon: s.centerLatLng.longitude,
        list: [stats],
      ));
    } else {
      final prev = clusters[targetIdx];
      clusters[targetIdx] = (
        sumLat: prev.sumLat + s.centerLatLng.latitude,
        sumLon: prev.sumLon + s.centerLatLng.longitude,
        list: [...prev.list, stats],
      );
    }
  }

  return clusters.map((cl) {
    final center = LatLng(cl.sumLat / cl.list.length, cl.sumLon / cl.list.length);
    if (cl.list.length == 1) {
      final stats = cl.list.first;
      return Marker(
        point: center,
        width: 64,
        height: 64,
        child: GestureDetector(
          onTap: () => onTapCountry(stats),
          child: _PolarstepsPhotoPin(
            thumbUrl: _pickCountryThumb(stats),
            fallbackText: stats.meta.flag,
            badgeText: stats.meta.flag,
            count: stats.totalMedia,
            isHighlighted: highlightedIso == stats.meta.iso3,
          ),
        ),
      );
    }
    final total = cl.list.fold<int>(0, (acc, c) => acc + c.totalMedia);
    final flags = cl.list.take(3).map((e) => e.meta.flag).join();
    return Marker(
      point: center,
      width: 110,
      height: 38,
      child: GestureDetector(
        onTap: () => onTapClusterZoom(center),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF0E7490).withValues(alpha: 0.94),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              '$flags · $total',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    );
  }).toList();
}

class _PolarstepsPhotoPin extends StatelessWidget {
  final String? thumbUrl;
  final String fallbackText;
  final String? badgeText;
  final int count;
  final bool isHighlighted;

  const _PolarstepsPhotoPin({
    this.thumbUrl,
    required this.fallbackText,
    this.badgeText,
    required this.count,
    this.isHighlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFF8FAFC),
            border: Border.all(
              color: isHighlighted ? const Color(0xFFF97316) : Colors.white,
              width: 3,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.28),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ClipOval(
            child: thumbUrl != null
                ? Image.network(
                    thumbUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Center(
                      child: Text(fallbackText, style: const TextStyle(fontSize: 20)),
                    ),
                  )
                : Center(
                    child: Text(fallbackText, style: const TextStyle(fontSize: 20)),
                  ),
          ),
        ),
        if (badgeText != null)
          Positioned(
            left: 2,
            bottom: 2,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.16),
                    blurRadius: 3,
                  ),
                ],
              ),
              child: Text(badgeText!, style: const TextStyle(fontSize: 10)),
            ),
          ),
        Positioned(
          right: 0,
          top: 2,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
            decoration: BoxDecoration(
              color: const Color(0xFFF97316),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white, width: 1.4),
            ),
            child: Text(
              count > 999 ? '${(count / 1000).toStringAsFixed(1)}k' : '$count',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ],
    );
  }
}