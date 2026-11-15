import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/apple_surfaces.dart';
import '../main.dart' show isFirebaseInitialized;

class AppUpdateInfo {
  final String latestVersion;
  final int latestBuildNumber;
  final String downloadUrl;
  final String releaseNotes;
  final bool isMandatory;

  AppUpdateInfo({
    required this.latestVersion,
    required this.latestBuildNumber,
    required this.downloadUrl,
    required this.releaseNotes,
    this.isMandatory = false,
  });

  factory AppUpdateInfo.fromFirestore(Map<String, dynamic> data) {
    return AppUpdateInfo(
      latestVersion: data['latest_version'] ?? '1.0.0',
      latestBuildNumber: data['latest_build_number'] is int
          ? data['latest_build_number']
          : int.tryParse(data['latest_build_number']?.toString() ?? '1') ?? 1,
      downloadUrl: data['download_url'] ?? '',
      releaseNotes: data['release_notes'] ?? 'Melhorias gerais e correções de estabilidade.',
      isMandatory: data['is_mandatory'] ?? false,
    );
  }
}

class AppUpdateService {
  /// Compara se a versão remota é mais recente que a local
  static bool _isNewer(String remoteVer, int remoteBuild, String currentVer, int currentBuild) {
    if (remoteBuild > currentBuild) return true;
    if (remoteBuild == currentBuild && remoteBuild > 0) return false;

    final rParts = remoteVer.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final cParts = currentVer.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    for (int i = 0; i < 3; i++) {
      final r = i < rParts.length ? rParts[i] : 0;
      final c = i < cParts.length ? cParts[i] : 0;
      if (r > c) return true;
      if (r < c) return false;
    }
    return false;
  }

  /// Verifica se há atualização no Firestore
  static Future<AppUpdateInfo?> checkForUpdate() async {
    if (!isFirebaseInitialized) return null;

    try {
      final doc = await FirebaseFirestore.instance.collection('app_config').doc('version').get();
      if (!doc.exists || doc.data() == null) return null;

      final updateInfo = AppUpdateInfo.fromFirestore(doc.data()!);
      final packageInfo = await PackageInfo.fromPlatform();

      final currentVersion = packageInfo.version;
      final currentBuild = int.tryParse(packageInfo.buildNumber) ?? 0;

      if (_isNewer(updateInfo.latestVersion, updateInfo.latestBuildNumber, currentVersion, currentBuild)) {
        if (updateInfo.downloadUrl.isNotEmpty) {
          return updateInfo;
        }
      }
    } catch (e) {
      debugPrint('Aviso ao verificar atualizações: $e');
    }
    return null;
  }

  /// Exibe o diálogo elegante estilo Apple para baixar e instalar em segundo plano
  static void showUpdateDialog(BuildContext context, AppUpdateInfo info) {
    showDialog(
      context: context,
      barrierDismissible: !info.isMandatory,
      builder: (ctx) => _UpdateDialog(info: info),
    );
  }
}

class _UpdateDialog extends StatefulWidget {
  final AppUpdateInfo info;
  const _UpdateDialog({required this.info});

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  bool _isDownloading = false;
  double _progress = 0.0;
  String _statusMessage = '';
  CancelToken? _cancelToken;

  @override
  void dispose() {
    _cancelToken?.cancel();
    super.dispose();
  }

  Future<void> _startDownload() async {
    final url = widget.info.downloadUrl.trim();

    // Se for link web comum (ex: Google Drive), abre no navegador
    if (url.contains('drive.google.com') || !url.endsWith('.apk')) {
      final uri = Uri.tryParse(url);
      if (uri != null && await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      if (mounted && !widget.info.isMandatory) {
        Navigator.pop(context);
      }
      return;
    }

    // Se for link direto de APK (ex: GitHub Releases ou Firebase Storage)
    setState(() {
      _isDownloading = true;
      _progress = 0.0;
      _statusMessage = 'Iniciando download...';
    });

    try {
      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/cinegestor_update_${widget.info.latestVersion}.apk';
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }

      _cancelToken = CancelToken();
      final dio = Dio();

      await dio.download(
        url,
        filePath,
        cancelToken: _cancelToken,
        onReceiveProgress: (received, total) {
          if (total > 0 && mounted) {
            setState(() {
              _progress = received / total;
              final percent = (_progress * 100).toInt();
              final receivedMb = (received / (1024 * 1024)).toStringAsFixed(1);
              final totalMb = (total / (1024 * 1024)).toStringAsFixed(1);
              _statusMessage = 'Baixando: $percent% ($receivedMb de $totalMb MB)';
            });
          }
        },
      );

      if (!mounted) return;

      setState(() {
        _statusMessage = 'Download concluído! Abrindo instalador...';
      });

      // Dispara o instalador nativo do Android
      final result = await OpenFilex.open(filePath);
      if (result.type != ResultType.done) {
        if (mounted) {
          showTopNotice(context, 'Autorize a instalação de fontes desconhecidas para atualizar.', isWarning: true);
        }
      }

      if (mounted && !widget.info.isMandatory) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _statusMessage = 'Erro no download. Tentando abrir link externo...';
        });
        final uri = Uri.tryParse(url);
        if (uri != null && await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: AppleColors.surfaceElevated,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppleColors.accentBlue.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.system_update_rounded, color: AppleColors.accentBlue, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Nova Versão ${widget.info.latestVersion}',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'O que há de novo:',
              style: TextStyle(color: AppleColors.textTertiary, fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              widget.info.releaseNotes,
              style: const TextStyle(color: AppleColors.textPrimary, fontSize: 13.5),
            ),
            if (_isDownloading) ...[
              const SizedBox(height: 18),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: _progress > 0 ? _progress : null,
                  backgroundColor: AppleColors.surface,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppleColors.systemGreen),
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _statusMessage,
                style: const TextStyle(color: AppleColors.textSecondary, fontSize: 11.5),
              ),
            ],
          ],
        ),
      ),
      actions: [
        if (!widget.info.isMandatory && !_isDownloading)
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Depois', style: TextStyle(color: AppleColors.textSecondary)),
          ),
        if (!_isDownloading)
          ElevatedButton.icon(
            onPressed: _startDownload,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppleColors.accentBlue,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.download_rounded, size: 18),
            label: const Text('Atualizar Agora', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
      ],
    );
  }
}
