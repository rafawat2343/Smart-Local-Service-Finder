import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'create_account_screen.dart' show NidData;

class NidOcrService {
  /// Extracts Name, NID Number, and Date of Birth from the FRONT of the NID.
  static Future<NidData> extractFromImage(String imagePath) async {
    if (imagePath.isEmpty) throw const NidOcrException('Image path is empty.');

    try {
      final text = await _runLatinOcr(imagePath);

      if (text.trim().isEmpty) {
        throw const NidOcrException(
          'No text could be read from the image. Please retake the photo '
          'with better lighting and the card flat.',
        );
      }

      final fields = _parseEnglishFields(text);

      return NidData(
        fullName: fields.name,
        nidNumber: fields.nidNumber,
        dateOfBirth: fields.dateOfBirth,
      );
    } on NidOcrException {
      rethrow;
    } catch (e) {
      throw NidOcrException('OCR failed: $e');
    }
  }

  // ── OCR runner ───────────────────────────────────────────────────────────────

  static Future<String> _runLatinOcr(String imagePath) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final input = InputImage.fromFilePath(imagePath);
      final result = await recognizer.processImage(input);
      return result.text;
    } finally {
      await recognizer.close();
    }
  }

  // ── English field parsing ────────────────────────────────────────────────────

  static _EnglishFields _parseEnglishFields(String text) {
    final lines = _normalizeLines(text);
    return _EnglishFields(
      name: _findName(lines),
      dateOfBirth: _findDob(lines, text),
      nidNumber: _findNidNumber(lines, text),
    );
  }

  static String _findName(List<String> lines) {
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final m = RegExp(
        r'(?:^|\s|/)Name\s*[:.]?\s*(.*)$',
        caseSensitive: false,
      ).firstMatch(line);
      if (m != null) {
        var value = (m.group(1) ?? '').trim();
        if (value.isEmpty && i + 1 < lines.length) {
          value = lines[i + 1].trim();
        }
        value = _cleanValue(value);
        if (_looksLikeName(value)) return value;
      }
    }
    return '';
  }

  static String _findDob(List<String> lines, String fullText) {
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (RegExp(r'Date\s*of\s*Birth|D\.?O\.?B', caseSensitive: false)
          .hasMatch(line)) {
        for (final candidate in [
          line,
          if (i + 1 < lines.length) lines[i + 1],
        ]) {
          final m = _dobPattern.firstMatch(candidate);
          if (m != null) return _normalizeDob(m.group(0)!);
        }
      }
    }
    final m = _dobPattern.firstMatch(fullText);
    return m != null ? _normalizeDob(m.group(0)!) : '';
  }

  static final RegExp _dobPattern = RegExp(
    r'\b(\d{1,2})[\s.\-]+'
    r'(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Sept|Oct|Nov|Dec)[a-z]*'
    r'[\s.\-]+(\d{4})\b',
    caseSensitive: false,
  );

  static String _normalizeDob(String raw) {
    final m = _dobPattern.firstMatch(raw);
    if (m == null) return raw.trim();
    final day = int.tryParse(m.group(1)!) ?? 0;
    var mon = m.group(2)!.toLowerCase();
    if (mon == 'sept') mon = 'sep';
    final year = m.group(3)!;
    mon = mon[0].toUpperCase() + mon.substring(1);
    return '${day.toString().padLeft(2, '0')} $mon $year';
  }

  static String _findNidNumber(List<String> lines, String fullText) {
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final hasLabel = RegExp(
        r'(?:N\.?I\.?D|National\s*ID|ID\s*N[O0])',
        caseSensitive: false,
      ).hasMatch(line);
      if (!hasLabel) continue;
      for (final candidate in [
        line,
        if (i + 1 < lines.length) lines[i + 1],
      ]) {
        final found = _extractNidDigits(candidate);
        if (found != null) return found;
      }
    }
    final loose = RegExp(r'(?<!\d)(\d{10}|\d{13}|\d{17})(?!\d)')
        .firstMatch(fullText.replaceAll(' ', ''));
    return loose?.group(1) ?? '';
  }

  static String? _extractNidDigits(String line) {
    final compact = line.replaceAll(RegExp(r'(?<=\d)\s+(?=\d)'), '');
    final m = RegExp(r'(\d{10,17})').firstMatch(compact);
    if (m == null) return null;
    final digits = m.group(1)!;
    if (digits.length == 10 || digits.length == 13 || digits.length == 17) {
      return digits;
    }
    return null;
  }

  // ── Shared helpers ───────────────────────────────────────────────────────────

  static List<String> _normalizeLines(String text) {
    return text
        .split(RegExp(r'\r?\n'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
  }

  static String _cleanValue(String s) {
    return s
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'^[\s:.\-]+'), '')
        .replaceAll(RegExp(r'[\s:.\-]+$'), '')
        .trim();
  }

  static bool _looksLikeName(String s) {
    if (s.length < 2) return false;
    if (RegExp(r'\d').hasMatch(s)) return false;
    if (!RegExp(r'[A-Za-z]').hasMatch(s)) return false;
    const reservedLabels = {
      'name', 'date of birth', 'dob', 'id no', 'nid no', 'national id',
    };
    if (reservedLabels.contains(s.toLowerCase())) return false;
    return true;
  }
}

class _EnglishFields {
  final String name;
  final String dateOfBirth;
  final String nidNumber;
  const _EnglishFields({
    required this.name,
    required this.dateOfBirth,
    required this.nidNumber,
  });
}

class NidOcrException implements Exception {
  final String message;
  const NidOcrException(this.message);
  @override
  String toString() => message;
}
