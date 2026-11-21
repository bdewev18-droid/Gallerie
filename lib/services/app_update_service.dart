import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../main.dart' show appBuildNumber, appVersionLabel;
import 'app_update_page.dart';

class RemoteAppVersion {
  const RemoteAppVersion({
    required this.version,
    required this.buildNumber,
    required this.apkUrl,
    this.releaseNotes,
  });

  final String version;
  final int buildNumber;
  final String apkUrl;
  final String? releaseNotes;

  factory RemoteAppVersion.fromJson(Map<String, dynamic> json) {
    return RemoteAppVersion(
      version: (json['version'] as String?)?.trim() ?? '',
      buildNumber: json['buildNumber'] is int
          ? json['buildNumber'] as int
          : int.tryParse(json['buildNumber']?.toString() ?? '') ?? 0,
      apkUrl: (json['apkUrl'] as String?)?.trim() ?? '',
      releaseNotes: (json['releaseNotes'] as String?)?.trim(),
    );
  }
}

class AppUpdateService {
  AppUpdateService._();

  static const String versionCheckUrl =
      'https://bdewev18-droid.github.io/Gallerie/version.json';

  static bool _dialogShownThisSession = false;

  /// Vérifie si une mise à jour est disponible sur GitHub Pages.
  /// Ne s'exécute que sur mobile (Android) et jamais sur le Web.
  static Future<RemoteAppVersion?> checkUpdate() async {
    if (kIsWeb) return null;
    if (defaultTargetPlatform != TargetPlatform.android) return null;

    try {
      final uri = Uri.parse('$versionCheckUrl?t=${DateTime.now().millisecondsSinceEpoch}');
      final response = await http.get(uri).timeout(const Duration(seconds: 4));
      if (response.statusCode != 200) return null;

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final remote = RemoteAppVersion.fromJson(json);

      if (remote.buildNumber > appBuildNumber && remote.apkUrl.isNotEmpty) {
        return remote;
      }
    } catch (_) {
      // Échec silencieux si hors-ligne
    }
    return null;
  }

  /// Vérifie au lancement et force la mise à jour si nécessaire
  static Future<void> checkAndPrompt(BuildContext context) async {
    if (_dialogShownThisSession) return;
    final update = await checkUpdate();
    if (update == null || !context.mounted) return;
    _dialogShownThisSession = true;
    await promptUpdate(context, update, isForced: true);
  }

  /// Affiche la boîte de dialogue de mise à jour obligatoire
  static Future<void> promptUpdate(
    BuildContext context,
    RemoteAppVersion update, {
    bool isForced = true,
  }) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: !isForced,
      builder: (dialogCtx) => PopScope(
        canPop: !isForced,
        child: AlertDialog(
          backgroundColor: const Color(0xFF0F172A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFF0284C7), width: 1.5),
          ),
          title: const Row(
            children: [
              Icon(Icons.system_update, color: Color(0xFF38BDF8), size: 26),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Mise à jour requise',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Une nouvelle version de Medias Familly est disponible : v${update.version} (Build ${update.buildNumber}).',
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
              const SizedBox(height: 6),
              Text(
                'Version actuelle : v$appVersionLabel (Build $appBuildNumber).',
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
              if (update.releaseNotes != null && update.releaseNotes!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Text(
                    update.releaseNotes!,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              const Text(
                'Pour continuer à utiliser l\'application et profiter des dernières améliorations, veuillez installer la mise à jour.',
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
              ),
            ],
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () {
                  Navigator.of(dialogCtx).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => AppUpdatePage(
                        update: update,
                        isForced: isForced,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.download_rounded, size: 20),
                label: const Text(
                  'Télécharger et installer',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
