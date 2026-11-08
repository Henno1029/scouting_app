import 'package:flutter/services.dart';
import 'package:pdf/widgets.dart' as pw;

/// The font every PDF uses. The PDF library's built-in font can only draw
/// basic Western characters and silently drops others, so a name like
/// "Łukasz" would print as "ukasz". Roboto covers Latin, Greek and Cyrillic.
/// It comes with Flutter under the Apache 2.0 license, which is in
/// assets/fonts.
class PdfFonts {
  static pw.ThemeData? _theme;

  static Future<pw.ThemeData> theme() async {
    final cached = _theme;
    if (cached != null) return cached;
    final regular = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Roboto-Regular.ttf'),
    );
    final bold = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Roboto-Bold.ttf'),
    );
    return _theme = pw.ThemeData.withFont(base: regular, bold: bold);
  }
}
