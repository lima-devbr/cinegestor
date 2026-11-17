import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'apple_surfaces.dart';

class PhotoEvidenceService {
  static final ImagePicker _picker = ImagePicker();

  /// Seleciona/captura uma foto comprimida (max 720px, 55% JPEG) e devolve em Base64
  static Future<String?> pickPhotoBase64(BuildContext context) async {
    ImageSource? source;

    if (kIsWeb) {
      source = ImageSource.gallery;
    } else {
      source = await showModalBottomSheet<ImageSource>(
        context: context,
        backgroundColor: AppleColors.surfaceElevated,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 38,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: AppleColors.textTertiary.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                Text(
                  'Anexar Foto de Evidência',
                  style: TextStyle(
                    color: AppleColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  leading: Icon(
                    Icons.camera_alt_rounded,
                    color: AppleColors.accentBlue,
                  ),
                  title: const Text('Tirar Foto Agora (Câmera)'),
                  onTap: () => Navigator.pop(ctx, ImageSource.camera),
                ),
                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  leading: Icon(
                    Icons.photo_library_rounded,
                    color: AppleColors.systemGreen,
                  ),
                  title: const Text('Escolher da Galeria'),
                  onTap: () => Navigator.pop(ctx, ImageSource.gallery),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (source == null) return null;

    try {
      final XFile? picked = await _picker.pickImage(
        source: source,
        maxWidth: 720,
        maxHeight: 720,
        imageQuality: 55,
      );
      if (picked == null) return null;
      final bytes = await picked.readAsBytes();
      if (bytes.isEmpty) return null;
      return base64Encode(bytes);
    } catch (e) {
      if (context.mounted) {
        showTopNotice(
          context,
          'Não foi possível capturar a foto: $e',
          isError: true,
        );
      }
      return null;
    }
  }
}

/// Widget de botão/preview para anexar foto durante abertura ou conclusão
class PhotoEvidencePickerTile extends StatelessWidget {
  final String? photoBase64;
  final String label;
  final ValueChanged<String?> onChanged;

  const PhotoEvidencePickerTile({
    super.key,
    required this.photoBase64,
    required this.onChanged,
    this.label = 'Anexar foto (opcional)',
  });

  @override
  Widget build(BuildContext context) {
    final hasPhoto = photoBase64 != null && photoBase64!.isNotEmpty;
    Uint8List? bytes;
    if (hasPhoto) {
      try {
        bytes = base64Decode(photoBase64!);
      } catch (_) {}
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppleColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppleColors.glassBorder),
      ),
      child: Row(
        children: [
          if (bytes != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.memory(
                bytes,
                width: 48,
                height: 48,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Foto anexada',
                    style: TextStyle(
                      color: AppleColors.systemGreen,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'Toque em remover ou trocar',
                    style: TextStyle(
                      color: AppleColors.textSecondary,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(
                Icons.delete_outline_rounded,
                color: AppleColors.systemRed,
                size: 20,
              ),
              tooltip: 'Remover foto',
              onPressed: () => onChanged(null),
            ),
          ] else ...[
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppleColors.accentBlue.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.add_a_photo_rounded,
                color: AppleColors.accentBlue,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: AppleColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            ),
            TextButton(
              onPressed: () async {
                final b64 = await PhotoEvidenceService.pickPhotoBase64(context);
                if (b64 != null) {
                  onChanged(b64);
                }
              },
              child: const Text('Selecionar'),
            ),
          ],
        ],
      ),
    );
  }
}

/// Miniatura clicável com visualização em tela cheia e zoom
class PhotoEvidenceThumb extends StatelessWidget {
  final String photoBase64;
  final String tagLabel;

  const PhotoEvidenceThumb({
    super.key,
    required this.photoBase64,
    required this.tagLabel,
  });

  @override
  Widget build(BuildContext context) {
    Uint8List? bytes;
    try {
      bytes = base64Decode(photoBase64);
    } catch (_) {}
    if (bytes == null) return const SizedBox.shrink();

    return ApplePressable(
      pressedScale: 0.96,
      onPressed: () {
        showDialog(
          context: context,
          builder: (ctx) => Dialog(
            backgroundColor: Colors.black,
            insetPadding: const EdgeInsets.all(12),
            child: Stack(
              children: [
                InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 4.0,
                  child: Center(
                    child: Image.memory(bytes!, fit: BoxFit.contain),
                  ),
                ),
                Positioned(
                  top: 8,
                  left: 12,
                  child: AppleStatusPill(
                    label: tagLabel,
                    color: AppleColors.accentBlue,
                  ),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ),
              ],
            ),
          ),
        );
      },
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppleColors.glassBorder),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(9),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.memory(bytes, fit: BoxFit.cover),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  color: Colors.black.withValues(alpha: 0.65),
                  alignment: Alignment.center,
                  child: Text(
                    tagLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                    ),
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
