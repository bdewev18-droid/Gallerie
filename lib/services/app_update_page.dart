import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../main.dart' show appVersionLabel;
import 'app_update_service.dart';

enum UpdateDownloadStatus { idle, downloading, completed, failed }

class AppUpdatePage extends StatefulWidget {
  const AppUpdatePage({
    super.key,
    required this.update,
    this.isForced = true,
  });

  final RemoteAppVersion update;
  final bool isForced;

  @override
  State<AppUpdatePage> createState() => _AppUpdatePageState();
}

class _AppUpdatePageState extends State<AppUpdatePage> {
  UpdateDownloadStatus _status = UpdateDownloadStatus.idle;
  double _progress = 0.0;
  int _downloadedBytes = 0;
  int _totalBytes = 0;
  String? _errorMessage;
  String? _savedApkPath;
  bool _cancelled = false;
  http.Client? _httpClient;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startDownload();
    });
  }

  @override
  void dispose() {
    _cancelled = true;
    _httpClient?.close();
    super.dispose();
  }

  Future<void> _startDownload() async {
    if (!mounted) return;
    setState(() {
      _status = UpdateDownloadStatus.downloading;
      _progress = 0.0;
      _downloadedBytes = 0;
      _totalBytes = 0;
      _errorMessage = null;
      _cancelled = false;
    });

    _httpClient = http.Client();
    IOSink? fileSink;
    File? tempFile;

    try {
      String? storageDir;
      try {
        const channel = MethodChannel('medias_familly/updater');
        storageDir = await channel.invokeMethod<String>('getAppStorageDir');
      } catch (err) {
        debugPrint('getAppStorageDir error: $err');
      }

      if (storageDir == null || storageDir.isEmpty) {
        throw Exception('Espace de stockage non disponible sur cet appareil.');
      }

      tempFile = File('$storageDir/medias-familly-update.apk');
      if (await tempFile.exists()) {
        try {
          await tempFile.delete();
        } catch (_) {}
      }

      final request = http.Request('GET', Uri.parse(widget.update.apkUrl));
      final response = await _httpClient!.send(request);

      if (response.statusCode >= 400) {
        throw Exception('Le serveur a renvoyé une erreur HTTP ${response.statusCode}');
      }

      final total = response.contentLength ?? 0;
      if (mounted) {
        setState(() {
          _totalBytes = total;
        });
      }

      fileSink = tempFile.openWrite();
      var received = 0;

      await for (final chunk in response.stream) {
        if (_cancelled) {
          await fileSink.close();
          try {
            await tempFile.delete();
          } catch (_) {}
          return;
        }

        fileSink.add(chunk);
        received += chunk.length;

        if (mounted) {
          setState(() {
            _downloadedBytes = received;
            if (total > 0) {
              _progress = (received / total).clamp(0.0, 1.0);
            }
          });
        }
      }

      await fileSink.flush();
      await fileSink.close();
      fileSink = null;

      if (!mounted || _cancelled) return;

      setState(() {
        _status = UpdateDownloadStatus.completed;
        _savedApkPath = tempFile!.path;
        _progress = 1.0;
      });

      // Lancement automatique du programme d'installation Android
      await _triggerInstall(tempFile.path);
    } catch (error) {
      if (_cancelled) return;
      if (fileSink != null) {
        try {
          await fileSink.close();
        } catch (_) {}
      }
      if (mounted) {
        setState(() {
          _status = UpdateDownloadStatus.failed;
          _errorMessage = error.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  Future<void> _triggerInstall(String filePath) async {
    try {
      const channel = MethodChannel('medias_familly/updater');
      final result = await channel.invokeMethod<bool>('installApk', {
        'filePath': filePath,
      });
      debugPrint('Install APK invoked: $result');
    } catch (err) {
      debugPrint('Direct install error: $err');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF991B1B),
            content: Text(
              'Erreur du programme d\'installation : $err. Vous pouvez ouvrir le lien directement.',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        );
      }
    }
  }

  Future<void> _openExternalBrowser() async {
    final uri = Uri.parse(widget.update.apkUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 Mo';
    final mb = bytes / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} Mo';
  }

  @override
  Widget build(BuildContext context) {
    final percent = (_progress * 100).toInt();

    return PopScope(
      canPop: !widget.isForced,
      child: Scaffold(
        backgroundColor: const Color(0xFF090D16),
        appBar: AppBar(
          backgroundColor: const Color(0xFF0F172A),
          elevation: 0,
          title: const Text(
            'Mise à jour Medias Familly',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          automaticallyImplyLeading: !widget.isForced,
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            children: [
              // Version Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFF0284C7).withValues(alpha: 0.5),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0284C7).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Nouvelle version v${widget.update.version}',
                            style: const TextStyle(
                              color: Color(0xFF38BDF8),
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'Actuelle : v$appVersionLabel',
                          style: const TextStyle(color: Colors.white54, fontSize: 11),
                        ),
                      ],
                    ),
                    if (widget.update.releaseNotes != null && widget.update.releaseNotes!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      const Text(
                        'Nouveautés :',
                        style: TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.update.releaseNotes!,
                        style: const TextStyle(color: Colors.white60, fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Progress & State Card
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  children: [
                    // State 1: Downloading
                    if (_status == UpdateDownloadStatus.downloading) ...[
                      const SizedBox(
                        width: 50,
                        height: 50,
                        child: CircularProgressIndicator(
                          strokeWidth: 4,
                          color: Color(0xFF38BDF8),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Téléchargement de l\'APK ($percent%)',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${_formatBytes(_downloadedBytes)} / ${_totalBytes > 0 ? _formatBytes(_totalBytes) : "..."}',
                        style: const TextStyle(color: Colors.white60, fontSize: 12),
                      ),
                      const SizedBox(height: 16),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: _totalBytes > 0 ? _progress : null,
                          backgroundColor: Colors.white12,
                          color: const Color(0xFF38BDF8),
                          minHeight: 8,
                        ),
                      ),
                    ],

                    // State 2: Completed
                    if (_status == UpdateDownloadStatus.completed) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFF10B981), width: 2),
                        ),
                        child: const Icon(
                          Icons.check_circle_outline,
                          color: Color(0xFF10B981),
                          size: 38,
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Téléchargement terminé !',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Le programme d\'installation Android devrait s\'ouvrir automatiquement.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () {
                            if (_savedApkPath != null) {
                              _triggerInstall(_savedApkPath!);
                            }
                          },
                          icon: const Icon(Icons.install_mobile, size: 20),
                          label: const Text(
                            'Installer maintenant',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],

                    // State 3: Failed
                    if (_status == UpdateDownloadStatus.failed) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFEF4444), width: 2),
                        ),
                        child: const Icon(
                          Icons.error_outline_rounded,
                          color: Color(0xFFEF4444),
                          size: 38,
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Échec du téléchargement',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _errorMessage ?? 'Une erreur est survenue lors du téléchargement.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFFFCA5A5),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: const BorderSide(color: Colors.white30),
                              ),
                              onPressed: _startDownload,
                              icon: const Icon(Icons.refresh, size: 18),
                              label: const Text('Réessayer'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0284C7),
                                foregroundColor: Colors.white,
                              ),
                              onPressed: _openExternalBrowser,
                              icon: const Icon(Icons.open_in_browser, size: 18),
                              label: const Text('Navigateur'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Fallback direct link
              Center(
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF94A3B8),
                  ),
                  onPressed: _openExternalBrowser,
                  icon: const Icon(Icons.open_in_new, size: 14),
                  label: const Text(
                    'Lien direct de téléchargement (GitHub Releases)',
                    style: TextStyle(fontSize: 12),
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
