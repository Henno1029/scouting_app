import 'dart:typed_data';
import 'dart:ui' as ui;

class ImageUtils {
  static const int maxDimension = 600;

  static const int _skipBelowBytes = 120 * 1024;

  static Future<Uint8List> downscale(
    Uint8List bytes, {
    int maxDimension_ = maxDimension,
  }) async {
    if (bytes.length <= _skipBelowBytes) return bytes;
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      var image = frame.image;
      final width = image.width;
      final height = image.height;
      var scaled = false;
      var targetWidth = width;
      var targetHeight = height;
      if (width > maxDimension_ || height > maxDimension_) {
        final scale =
            maxDimension_ / (width > height ? width : height);
        targetWidth = (width * scale).round();
        targetHeight = (height * scale).round();
        final recorder = ui.PictureRecorder();
        final canvas = ui.Canvas(recorder);
        canvas.drawImageRect(
          image,
          ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
          ui.Rect.fromLTWH(
              0, 0, targetWidth.toDouble(), targetHeight.toDouble()),
          ui.Paint()..filterQuality = ui.FilterQuality.medium,
        );
        final picture = recorder.endRecording();
        image = await picture.toImage(targetWidth, targetHeight);
        picture.dispose();
        scaled = true;
      }
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      codec.dispose();
      if (data == null) return bytes;
      final result = data.buffer.asUint8List();
      if (scaled && result.length > bytes.length) return bytes;
      return result;
    } catch (_) {
      return bytes;
    }
  }
}