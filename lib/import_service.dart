import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart';
import 'learning_models.dart';

String extractDocument(String name, Uint8List bytes) {
  if (bytes.length > 5 * 1024 * 1024) {
    throw const FormatException('Choose a file smaller than 5 MB.');
  }
  final extension = name.toLowerCase().split('.').last;
  final String text;
  if (['txt', 'md', 'text'].contains(extension)) {
    if (bytes.length >= 2 && bytes[0] == 0xff && bytes[1] == 0xfe) {
      if (bytes.length.isOdd) {
        throw const FormatException(
          'This text file has invalid UTF-16 encoding. Save it as UTF-8.',
        );
      }
      text = String.fromCharCodes([
        for (var i = 2; i + 1 < bytes.length; i += 2)
          bytes[i] | bytes[i + 1] << 8,
      ]);
    } else {
      try {
        text = utf8.decode(bytes).replaceFirst('\uFEFF', '');
      } on FormatException {
        throw const FormatException(
          'Save this text file as UTF-8, or paste its contents instead.',
        );
      }
    }
  } else if (extension == 'docx') {
    final archive = ZipDecoder().decodeBytes(bytes);
    final file = archive.findFile('word/document.xml');
    if (file == null || file.size > 2 * 1024 * 1024) {
      throw const FormatException(
        'This Word document is invalid or too large.',
      );
    }
    final xml = XmlDocument.parse(utf8.decode(file.content));
    text = xml.descendants
        .whereType<XmlElement>()
        .where((e) => e.name.local == 'p')
        .map(
          (p) => p.descendants
              .whereType<XmlElement>()
              .where((e) => e.name.local == 't')
              .map((e) => e.innerText)
              .join(),
        )
        .join('\n\n');
  } else {
    throw const FormatException(
      'Choose TXT, Markdown, or Word (.docx), or paste your notes. PDF and image imports are not supported in this version.',
    );
  }
  if (text.trim().isEmpty) {
    throw const FormatException('No readable text was found in this document.');
  }
  if (text.length > maxSourceCharacters) {
    throw const FormatException(
      'This document exceeds 60,000 characters. Import one chapter at a time.',
    );
  }
  return text.trim();
}
