import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TravelJournalEntry {
  final String id;
  final String countryIso;
  final String countryName;
  final String countryFlag;
  final String? albumId;
  final String? albumName;
  final String title;
  final String story;
  final String dateLabel;
  final String transport; // 'Avion', 'Voiture', 'Train', 'Bateau', 'À pied'
  final String mood; // 'Soleil', 'Aventure', 'Détente', 'Culture', 'Gastronomie'
  final List<String> topSpots;
  final String? coverThumbUrl;
  final int createdAtMs;

  const TravelJournalEntry({
    required this.id,
    required this.countryIso,
    required this.countryName,
    required this.countryFlag,
    this.albumId,
    this.albumName,
    required this.title,
    required this.story,
    this.dateLabel = '',
    this.transport = 'Avion',
    this.mood = 'Aventure',
    this.topSpots = const [],
    this.coverThumbUrl,
    required this.createdAtMs,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'countryIso': countryIso,
        'countryName': countryName,
        'countryFlag': countryFlag,
        if (albumId != null) 'albumId': albumId,
        if (albumName != null) 'albumName': albumName,
        'title': title,
        'story': story,
        'dateLabel': dateLabel,
        'transport': transport,
        'mood': mood,
        'topSpots': topSpots,
        if (coverThumbUrl != null) 'coverThumbUrl': coverThumbUrl,
        'createdAtMs': createdAtMs,
      };

  factory TravelJournalEntry.fromJson(Map<String, dynamic> json) => TravelJournalEntry(
        id: json['id'] as String? ?? '',
        countryIso: json['countryIso'] as String? ?? 'FRA',
        countryName: json['countryName'] as String? ?? 'France',
        countryFlag: json['countryFlag'] as String? ?? '🌍',
        albumId: json['albumId'] as String?,
        albumName: json['albumName'] as String?,
        title: json['title'] as String? ?? '',
        story: json['story'] as String? ?? '',
        dateLabel: json['dateLabel'] as String? ?? '',
        transport: json['transport'] as String? ?? 'Avion',
        mood: json['mood'] as String? ?? 'Aventure',
        topSpots: (json['topSpots'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
        coverThumbUrl: json['coverThumbUrl'] as String?,
        createdAtMs: (json['createdAtMs'] as num?)?.toInt() ?? 0,
      );
}

class JournalAlbumRef {
  final String id;
  final String name;
  final String? coverThumbUrl;
  final String? dateRange;

  const JournalAlbumRef({
    required this.id,
    required this.name,
    this.coverThumbUrl,
    this.dateRange,
  });
}

class TravelJournalStorage {
  static const String _prefsKey = 'travel_journal_entries_v1';

  static Future<List<TravelJournalEntry>> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null || raw.isEmpty) return [];
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => TravelJournalEntry.fromJson(e as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => b.createdAtMs.compareTo(a.createdAtMs));
    } catch (_) {
      return [];
    }
  }

  static Future<void> save(List<TravelJournalEntry> entries) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(entries.map((e) => e.toJson()).toList());
      await prefs.setString(_prefsKey, encoded);
    } catch (_) {}
  }
}

String transportEmoji(String transport) {
  switch (transport) {
    case 'Avion':
      return '✈️';
    case 'Voiture':
      return '🚗';
    case 'Train':
      return '🚆';
    case 'Bateau':
      return '⛵';
    case 'À pied':
      return '🥾';
    default:
      return '🧭';
  }
}

String moodEmoji(String mood) {
  switch (mood) {
    case 'Soleil':
      return '☀️';
    case 'Aventure':
      return '🏔️';
    case 'Détente':
      return '🌴';
    case 'Culture':
      return '🏛️';
    case 'Gastronomie':
      return '🍽️';
    default:
      return '✨';
  }
}

class TravelJournalEditorDialog extends StatefulWidget {
  final String countryIso;
  final String countryName;
  final String countryFlag;
  final List<JournalAlbumRef> countryAlbums;
  final TravelJournalEntry? existing;

  const TravelJournalEditorDialog({
    super.key,
    required this.countryIso,
    required this.countryName,
    required this.countryFlag,
    this.countryAlbums = const [],
    this.existing,
  });

  @override
  State<TravelJournalEditorDialog> createState() => _TravelJournalEditorDialogState();
}

class _TravelJournalEditorDialogState extends State<TravelJournalEditorDialog> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _storyCtrl;
  late final TextEditingController _dateCtrl;
  late final TextEditingController _spotsCtrl;
  late String _transport;
  late String _mood;
  String? _selectedAlbumId;
  String? _selectedAlbumName;
  String? _selectedCoverUrl;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _titleCtrl = TextEditingController(text: e?.title ?? '');
    _storyCtrl = TextEditingController(text: e?.story ?? '');
    _dateCtrl = TextEditingController(text: e?.dateLabel ?? '');
    _spotsCtrl = TextEditingController(text: e?.topSpots.join(', ') ?? '');
    _transport = e?.transport ?? 'Avion';
    _mood = e?.mood ?? 'Aventure';
    _selectedAlbumId = e?.albumId;
    _selectedAlbumName = e?.albumName;
    _selectedCoverUrl = e?.coverThumbUrl;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _storyCtrl.dispose();
    _dateCtrl.dispose();
    _spotsCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final title = _titleCtrl.text.trim();
    final story = _storyCtrl.text.trim();
    if (title.isEmpty && story.isEmpty) return;

    final spots = _spotsCtrl.text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final entry = TravelJournalEntry(
      id: widget.existing?.id ?? 'j_${DateTime.now().millisecondsSinceEpoch}',
      countryIso: widget.countryIso,
      countryName: widget.countryName,
      countryFlag: widget.countryFlag,
      albumId: _selectedAlbumId,
      albumName: _selectedAlbumName,
      title: title.isEmpty ? 'Souvenir — ${widget.countryName}' : title,
      story: story,
      dateLabel: _dateCtrl.text.trim(),
      transport: _transport,
      mood: _mood,
      topSpots: spots,
      coverThumbUrl: _selectedCoverUrl,
      createdAtMs: widget.existing?.createdAtMs ?? DateTime.now().millisecondsSinceEpoch,
    );
    Navigator.of(context).pop(entry);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text(
        '${widget.countryFlag} ${widget.existing == null ? 'Nouveau récit' : 'Modifier le récit'}',
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
      ),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _titleCtrl,
                decoration: InputDecoration(
                  labelText: 'Titre de l\'étape / du voyage',
                  hintText: 'Ex: Road trip dans le Yucatán',
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _dateCtrl,
                decoration: InputDecoration(
                  labelText: 'Date ou période',
                  hintText: 'Ex: Août 2024',
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 10),
              if (widget.countryAlbums.isNotEmpty) ...[
                DropdownButtonFormField<String?>(
                  initialValue: widget.countryAlbums.any((a) => a.id == _selectedAlbumId)
                      ? _selectedAlbumId
                      : null,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Album lié (optionnel)',
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Aucun album spécifique'),
                    ),
                    ...widget.countryAlbums.map(
                      (a) => DropdownMenuItem<String?>(
                        value: a.id,
                        child: Text(a.name, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                  ],
                  onChanged: (val) {
                    setState(() {
                      _selectedAlbumId = val;
                      final found = widget.countryAlbums.where((a) => a.id == val).firstOrNull;
                      _selectedAlbumName = found?.name;
                      _selectedCoverUrl = found?.coverThumbUrl;
                      if (_dateCtrl.text.trim().isEmpty && found?.dateRange != null) {
                        _dateCtrl.text = found!.dateRange!;
                      }
                    });
                  },
                ),
                const SizedBox(height: 10),
              ],
              const Text('Transport', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: ['Avion', 'Voiture', 'Train', 'Bateau', 'À pied'].map((t) {
                  final sel = _transport == t;
                  return ChoiceChip(
                    label: Text('${transportEmoji(t)} $t', style: const TextStyle(fontSize: 11.5)),
                    selected: sel,
                    selectedColor: const Color(0xFFF97316).withValues(alpha: 0.2),
                    onSelected: (_) => setState(() => _transport = t),
                    visualDensity: VisualDensity.compact,
                  );
                }).toList(),
              ),
              const SizedBox(height: 10),
              const Text('Ambiance', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: ['Aventure', 'Soleil', 'Détente', 'Culture', 'Gastronomie'].map((m) {
                  final sel = _mood == m;
                  return ChoiceChip(
                    label: Text('${moodEmoji(m)} $m', style: const TextStyle(fontSize: 11.5)),
                    selected: sel,
                    selectedColor: const Color(0xFF0EA5E9).withValues(alpha: 0.2),
                    onSelected: (_) => setState(() => _mood = m),
                    visualDensity: VisualDensity.compact,
                  );
                }).toList(),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _spotsCtrl,
                decoration: InputDecoration(
                  labelText: 'Top Spots (séparés par des virgules)',
                  hintText: 'Ex: Chichén Itzá, Cenote Ik Kil, Tulum',
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _storyCtrl,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: 'Votre récit / anecdote',
                  hintText: 'Racontez vos meilleurs souvenirs de cette étape...',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFF97316),
            foregroundColor: Colors.white,
          ),
          onPressed: _submit,
          child: const Text('Enregistrer'),
        ),
      ],
    );
  }
}

class TravelJournalTimelineSheet extends StatelessWidget {
  final List<TravelJournalEntry> entries;
  final void Function(String albumId) onOpenAlbum;
  final void Function(String countryIso) onFocusCountry;
  final void Function(TravelJournalEntry entry) onEditEntry;
  final void Function(String entryId) onDeleteEntry;
  final VoidCallback onAddNewEntry;

  const TravelJournalTimelineSheet({
    super.key,
    required this.entries,
    required this.onOpenAlbum,
    required this.onFocusCountry,
    required this.onEditEntry,
    required this.onDeleteEntry,
    required this.onAddNewEntry,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFBF2),
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text('📖 Carnet de Voyage', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFF97316),
                foregroundColor: Colors.white,
              ),
              onPressed: onAddNewEntry,
              icon: const Icon(Icons.edit_note_rounded, size: 18),
              label: const Text('Écrire', style: TextStyle(fontSize: 12.5)),
            ),
          ),
        ],
      ),
      body: entries.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.menu_book_rounded, size: 54, color: Color(0xFFF97316)),
                    const SizedBox(height: 12),
                    const Text(
                      'Votre carnet de voyage est encore vide',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Ajoutez vos récits, modes de transport et Top Spots directement depuis un pays ou avec le bouton Écrire.',
                      style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: const Color(0xFFF97316)),
                      onPressed: onAddNewEntry,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Créer mon premier récit'),
                    ),
                  ],
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(14),
              itemCount: entries.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, idx) {
                final e = entries[idx];
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFF1E6D2)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (e.coverThumbUrl != null)
                        ClipRRect(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                          child: SizedBox(
                            height: 150,
                            width: double.infinity,
                            child: Image.network(e.coverThumbUrl!, fit: BoxFit.cover),
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                InkWell(
                                  onTap: () {
                                    Navigator.of(context).pop();
                                    onFocusCountry(e.countryIso);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0EA5E9).withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '${e.countryFlag} ${e.countryName}',
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF0284C7),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '${transportEmoji(e.transport)} ${e.transport} · ${moodEmoji(e.mood)}',
                                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                                ),
                                const Spacer(),
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF64748B)),
                                  onPressed: () => onEditEntry(e),
                                  visualDensity: VisualDensity.compact,
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFFEF4444)),
                                  onPressed: () => onDeleteEntry(e.id),
                                  visualDensity: VisualDensity.compact,
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              e.title,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                            if (e.dateLabel.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                e.dateLabel,
                                style: const TextStyle(fontSize: 11.5, color: Color(0xFFF97316), fontWeight: FontWeight.w600),
                              ),
                            ],
                            if (e.story.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                e.story,
                                style: const TextStyle(fontSize: 13.5, height: 1.45, color: Color(0xFF334155)),
                              ),
                            ],
                            if (e.topSpots.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: e.topSpots
                                    .map(
                                      (spot) => Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFFF7E8),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: const Color(0xFFFDE68A)),
                                        ),
                                        child: Text(
                                          '⭐ $spot',
                                          style: const TextStyle(fontSize: 11, color: Color(0xFF92400E)),
                                        ),
                                      ),
                                    )
                                    .toList(),
                              ),
                            ],
                            if (e.albumId != null) ...[
                              const SizedBox(height: 10),
                              OutlinedButton.icon(
                                onPressed: () {
                                  Navigator.of(context).pop();
                                  onOpenAlbum(e.albumId!);
                                },
                                icon: const Icon(Icons.photo_library_outlined, size: 16),
                                label: Text(
                                  'Voir l\'album : ${e.albumName ?? 'Photos'}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
