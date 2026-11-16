import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
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

  /// Verifica se há atualização no Firestore (apenas mobile, não se aplica à Web)
  static Future<AppUpdateInfo?> checkForUpdate() async {
    if (kIsWeb || !isFirebaseInitialized) return null;

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

  /// Painel exclusivo do Administrador para publicar uma nova versão direto pelo app
  /// (grava em `/app_config/version` no Cloud Firestore sem precisar abrir o Console web)
  static Future<void> showPublishUpdateDialog(BuildContext context) async {
    String currentVer = '1.0.0';
    int currentBuild = 1;
    String currentUrl = '';
    String currentNotes = 'Melhorias gerais e correções de estabilidade.';
    bool currentMandatory = false;

    try {
      final pkg = await PackageInfo.fromPlatform();
      currentVer = pkg.version;
      currentBuild = (int.tryParse(pkg.buildNumber) ?? 1) + 1;
    } catch (_) {}

    if (isFirebaseInitialized) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('app_config')
            .doc('version')
            .get();
        if (doc.exists && doc.data() != null) {
          final existing = AppUpdateInfo.fromFirestore(doc.data()!);
          currentVer = existing.latestVersion;
          currentBuild = existing.latestBuildNumber;
          currentUrl = existing.downloadUrl;
          currentNotes = existing.releaseNotes;
          currentMandatory = existing.isMandatory;
        }
      } catch (_) {}
    }

    if (!context.mounted) return;

    final versionCtrl = TextEditingController(text: currentVer);
    final buildCtrl = TextEditingController(text: '$currentBuild');
    final urlCtrl = TextEditingController(text: currentUrl);
    final notesCtrl = TextEditingController(text: currentNotes);
    bool isMandatory = currentMandatory;
    bool isSaving = false;

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              backgroundColor: AppleColors.surfaceElevated,
              title: Row(
                children: [
                  Icon(
                    Icons.rocket_launch_rounded,
                    color: AppleColors.accentBlue,
                    size: 22,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Publicar Atualização do App',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 400,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Configure os dados da nova versão. Todos os celulares com build menor receberão o aviso de download automático ao abrir o CineGestor.',
                        style: TextStyle(
                          color: AppleColors.textSecondary,
                          fontSize: 12.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: versionCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Versão (ex: 1.1.0)',
                                prefixIcon: Icon(Icons.tag_rounded, size: 18),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: buildCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Build (ex: 2)',
                                prefixIcon:
                                    Icon(Icons.numbers_rounded, size: 18),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: urlCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Link direto do APK (.apk)',
                          hintText:
                              'https://github.com/.../releases/download/v1.1.0/app-release.apk',
                          prefixIcon: Icon(Icons.link_rounded, size: 18),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: notesCtrl,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Novidades da versão',
                          prefixIcon: Icon(Icons.notes_rounded, size: 18),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        value: isMandatory,
                        activeTrackColor: AppleColors.accentBlue,
                        title: const Text(
                          'Atualização Obrigatória',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          'Impede fechar o aviso sem atualizar',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: AppleColors.textSecondary,
                          ),
                        ),
                        onChanged: (val) =>
                            setDialogState(() => isMandatory = val),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(ctx),
                  child: Text(
                    'Cancelar',
                    style: TextStyle(color: AppleColors.textSecondary),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: isSaving
                      ? null
                      : () async {
                          final ver = versionCtrl.text.trim();
                          final bld =
                              int.tryParse(buildCtrl.text.trim()) ?? 1;
                          final url = urlCtrl.text.trim();
                          final notes = notesCtrl.text.trim();

                          if (ver.isEmpty || url.isEmpty) {
                            showTopNotice(
                              context,
                              'Informe a versão e o link direto do APK.',
                              isWarning: true,
                            );
                            return;
                          }

                          setDialogState(() => isSaving = true);
                          try {
                            await FirebaseFirestore.instance
                                .collection('app_config')
                                .doc('version')
                                .set({
                              'latest_version': ver,
                              'latest_build_number': bld,
                              'download_url': url,
                              'release_notes': notes.isEmpty
                                  ? 'Melhorias gerais e correções.'
                                  : notes,
                              'is_mandatory': isMandatory,
                              'updated_at': DateTime.now().toIso8601String(),
                            });
                            if (ctx.mounted) Navigator.pop(ctx);
                            if (context.mounted) {
                              showTopNotice(
                                context,
                                'Versão $ver (Build $bld) publicada com sucesso!',
                              );
                            }
                          } catch (e) {
                            setDialogState(() => isSaving = false);
                            if (context.mounted) {
                              showTopNotice(
                                context,
                                'Erro ao publicar versão: $e',
                                isWarning: true,
                              );
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppleColors.accentBlue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.cloud_upload_rounded, size: 18),
                  label: Text(isSaving ? 'Publicando...' : 'Publicar'),
                ),
              ],
            );
          },
        );
      },
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
            child: Icon(Icons.system_update_rounded, color: AppleColors.accentBlue, size: 22),
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
            Text(
              'O que há de novo:',
              style: TextStyle(color: AppleColors.textTertiary, fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              widget.info.releaseNotes,
              style: TextStyle(color: AppleColors.textPrimary, fontSize: 13.5),
            ),
            if (_isDownloading) ...[
              const SizedBox(height: 18),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: _progress > 0 ? _progress : null,
                  backgroundColor: AppleColors.surface,
                  valueColor: AlwaysStoppedAnimation<Color>(AppleColors.systemGreen),
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _statusMessage,
                style: TextStyle(color: AppleColors.textSecondary, fontSize: 11.5),
              ),
            ],
          ],
        ),
      ),
      actions: [
        if (!widget.info.isMandatory && !_isDownloading)
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Depois', style: TextStyle(color: AppleColors.textSecondary)),
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
