import 'dart:async';
import 'dart:js_interop';
import 'package:web/web.dart' as web;

/// Seleciona e comprime uma imagem direto via HTML5 Input + Canvas (sem MethodChannel)
Future<String?> pickWebImageBase64() async {
  final completer = Completer<String?>();
  final input =
      web.document.createElement('input') as web.HTMLInputElement;
  input.type = 'file';
  input.accept = 'image/*';

  input.addEventListener(
    'change',
    (web.Event event) {
      final files = input.files;
      if (files == null || files.length == 0) {
        if (!completer.isCompleted) completer.complete(null);
        return;
      }

      final file = files.item(0);
      if (file == null) {
        if (!completer.isCompleted) completer.complete(null);
        return;
      }

      final reader = web.FileReader();
      reader.addEventListener(
        'load',
        (web.Event loadEvent) {
          final result = reader.result;
          if (result == null) {
            if (!completer.isCompleted) completer.complete(null);
            return;
          }
          final dataUrl = (result as JSString).toDart;

          final img =
              web.document.createElement('img') as web.HTMLImageElement;
          img.addEventListener(
            'load',
            (web.Event imgEvent) {
              const maxDim = 720.0;
              double w = img.naturalWidth.toDouble();
              double h = img.naturalHeight.toDouble();
              if (w > maxDim || h > maxDim) {
                if (w >= h) {
                  h = (h * maxDim / w).roundToDouble();
                  w = maxDim;
                } else {
                  w = (w * maxDim / h).roundToDouble();
                  h = maxDim;
                }
              }

              final canvas = web.document.createElement('canvas')
                  as web.HTMLCanvasElement;
              canvas.width = w.toInt();
              canvas.height = h.toInt();
              final ctx = canvas.getContext('2d')
                  as web.CanvasRenderingContext2D?;
              if (ctx == null) {
                if (!completer.isCompleted) completer.complete(null);
                return;
              }
              ctx.drawImage(img, 0, 0, w, h);
              final compressedDataUrl = canvas.toDataURL('image/jpeg', 0.6.toJS);
              final commaIdx = compressedDataUrl.indexOf(',');
              final base64Str = commaIdx != -1
                  ? compressedDataUrl.substring(commaIdx + 1)
                  : compressedDataUrl;
              if (!completer.isCompleted) completer.complete(base64Str);
            }.toJS,
          );
          img.addEventListener(
            'error',
            (web.Event errEvent) {
              if (!completer.isCompleted) completer.complete(null);
            }.toJS,
          );
          img.src = dataUrl;
        }.toJS,
      );
      reader.readAsDataURL(file);
    }.toJS,
  );

  input.click();
  return completer.future;
}
