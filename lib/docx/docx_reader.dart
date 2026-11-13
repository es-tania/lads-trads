import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

/// Paragraphe brut d'un .docx.
class DocParagraph {
  const DocParagraph({required this.text, required this.isHeading1, required this.isListItem});

  final String text;

  /// Style Word « Titre 1 » (« Heading 1 » dans un Word en anglais).
  final bool isHeading1;

  /// Paragraphe d'une liste à puces ou numérotée.
  final bool isListItem;

  @override
  String toString() => '${isHeading1 ? '[T1] ' : ''}${isListItem ? '[•] ' : ''}$text';
}

class DocxFormatException implements Exception {
  const DocxFormatException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Lit les paragraphes du corps d'un .docx, dans l'ordre.
///
/// Les paragraphes de tableaux sont ignorés : seuls les paragraphes de premier
/// niveau comptent, c'est ce qui garde FR et EN alignés.
List<DocParagraph> readDocxParagraphs(Uint8List bytes) {
  final Archive archive;
  try {
    archive = ZipDecoder().decodeBytes(bytes);
  } on Object {
    throw const DocxFormatException('Ce fichier n\'est pas un .docx valide.');
  }

  final documentXml = _readEntry(archive, 'word/document.xml');
  if (documentXml == null) {
    throw const DocxFormatException('Le .docx ne contient pas de document Word.');
  }
  final stylesXml = _readEntry(archive, 'word/styles.xml');

  final headingIds = _heading1StyleIds(stylesXml);
  final body = XmlDocument.parse(documentXml).rootElement.getElement('w:body');
  if (body == null) return const [];

  return [
    for (final p in body.childElements.where((e) => e.name.qualified == 'w:p'))
      _readParagraph(p, headingIds),
  ];
}

DocParagraph _readParagraph(XmlElement p, Set<String> headingIds) {
  final pPr = p.getElement('w:pPr');
  final styleId = pPr?.getElement('w:pStyle')?.getAttribute('w:val');
  final hasNumbering = pPr?.getElement('w:numPr') != null;

  final text = StringBuffer();
  for (final node in p.descendantElements) {
    switch (node.name.qualified) {
      case 'w:t':
        text.write(node.innerText);
      case 'w:tab':
        text.write('\t');
      case 'w:br' || 'w:cr':
        text.write('\n');
      case 'w:noBreakHyphen':
        text.write('‑');
    }
  }

  return DocParagraph(
    text: text.toString(),
    isHeading1: styleId != null && headingIds.contains(styleId),
    isListItem: hasNumbering,
  );
}

String? _readEntry(Archive archive, String name) {
  final file = archive.findFile(name);
  if (file == null) return null;
  return utf8.decode(file.content, allowMalformed: true);
}

/// Identifiants des styles « Titre 1 » / « Heading 1 ».
///
/// Word stocke le nom anglais (« heading 1 ») même dans un Word en français ;
/// on accepte aussi « Titre 1 » au cas où un autre logiciel l'aurait écrit.
Set<String> _heading1StyleIds(String? stylesXml) {
  final ids = {'Heading1', 'Titre1'};
  if (stylesXml == null) return ids;
  for (final style in XmlDocument.parse(stylesXml).findAllElements('w:style')) {
    final id = style.getAttribute('w:styleId');
    final name = style.getElement('w:name')?.getAttribute('w:val')?.toLowerCase().trim();
    if (id != null && (name == 'heading 1' || name == 'titre 1')) ids.add(id);
  }
  return ids;
}
