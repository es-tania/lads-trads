import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

import '../text/markup.dart';

/// Paragraphe à écrire dans un .docx.
class OutParagraph {
  const OutParagraph(
    this.text, {
    this.heading = false,
    this.listItem = false,
    this.comment,
    this.muted = false,
    this.spans,
  });

  final String text;

  /// Morceaux en gras ou en italique ; `null` : [text] tel quel.
  final List<MarkupSpan>? spans;

  /// Style « Titre 1 » (titre de l'histoire, titres de parties).
  final bool heading;

  /// Puce : une option de choix.
  final bool listItem;

  /// Commentaire Word dans la marge (note de traduction).
  final String? comment;

  /// Texte gris, pour l'anglais d'un export bilingue.
  final bool muted;
}

const _w = 'http://schemas.openxmlformats.org/wordprocessingml/2006/main';

/// Construit un .docx avec les mêmes repères que les fichiers d'origine :
/// « Titre 1 » (style nommé « heading 1 », que [readDocxParagraphs] reconnaît),
/// liste à puces pour les options, et commentaires Word pour les notes.
Uint8List buildDocx(List<OutParagraph> paragraphs) {
  final comments = <(int, String)>[];

  final body = XmlBuilder();
  body.processing('xml', 'version="1.0" encoding="UTF-8" standalone="yes"');
  body.element('w:document', namespaceUris: {'w': _w}, nest: () {
    body.element('w:body', nest: () {
      for (final p in paragraphs) {
        final commentId = p.comment == null ? null : comments.length;
        if (commentId != null) comments.add((commentId, p.comment!));
        body.element('w:p', nest: () {
          if (p.heading || p.listItem) {
            body.element('w:pPr', nest: () {
              if (p.heading) body.element('w:pStyle', attributes: {'w:val': 'Heading1'});
              if (p.listItem) {
                body.element('w:pStyle', attributes: {'w:val': 'ListParagraph'});
                body.element('w:numPr', nest: () {
                  body.element('w:ilvl', attributes: {'w:val': '0'});
                  body.element('w:numId', attributes: {'w:val': '1'});
                });
              }
            });
          }
          if (commentId != null) body.element('w:commentRangeStart', attributes: {'w:id': '$commentId'});
          for (final s in _merged(p.spans ?? [MarkupSpan(p.text)])) {
            _runs(body, s.text, muted: p.muted, bold: s.bold, italic: s.italic);
          }
          if (commentId != null) {
            body.element('w:commentRangeEnd', attributes: {'w:id': '$commentId'});
            body.element('w:r', nest: () {
              body.element('w:rPr', nest: () => body.element('w:rStyle', attributes: {'w:val': 'CommentReference'}));
              body.element('w:commentReference', attributes: {'w:id': '$commentId'});
            });
          }
        });
      }
      body.element('w:sectPr', nest: () {
        body.element('w:pgSz', attributes: {'w:w': '11906', 'w:h': '16838'});
        body.element('w:pgMar', attributes: {
          'w:top': '1417',
          'w:right': '1417',
          'w:bottom': '1417',
          'w:left': '1417',
          'w:header': '708',
          'w:footer': '708',
          'w:gutter': '0',
        });
      });
    });
  });

  final hasComments = comments.isNotEmpty;
  final archive = Archive()
    ..addFile(_text('[Content_Types].xml', _contentTypes(hasComments)))
    ..addFile(_text('_rels/.rels', _rootRels))
    ..addFile(_text('word/document.xml', body.buildDocument().toXmlString()))
    ..addFile(_text('word/styles.xml', _styles))
    ..addFile(_text('word/numbering.xml', _numbering))
    ..addFile(_text('word/_rels/document.xml.rels', _documentRels(hasComments)));
  if (hasComments) archive.addFile(_text('word/comments.xml', _comments(comments)));

  return Uint8List.fromList(ZipEncoder().encode(archive));
}

/// Morceaux voisins de même style réunis : un seul run Word pour chacun.
List<MarkupSpan> _merged(List<MarkupSpan> spans) {
  final out = <MarkupSpan>[];
  for (final s in spans) {
    if (s.text.isEmpty) continue;
    final last = out.isEmpty ? null : out.last;
    if (last != null && last.bold == s.bold && last.italic == s.italic) {
      out[out.length - 1] = MarkupSpan(last.text + s.text, bold: s.bold, italic: s.italic);
    } else {
      out.add(s);
    }
  }
  return out.isEmpty ? const [MarkupSpan('')] : out;
}

/// Texte d'un paragraphe ; les retours à la ligne deviennent des `<w:br/>`.
void _runs(XmlBuilder b, String text, {required bool muted, bool bold = false, bool italic = false}) {
  b.element('w:r', nest: () {
    if (muted || bold || italic) {
      b.element('w:rPr', nest: () {
        if (bold) b.element('w:b');
        if (italic) b.element('w:i');
        if (muted) b.element('w:color', attributes: {'w:val': '7A8296'});
      });
    }
    for (final (i, line) in text.split('\n').indexed) {
      if (i > 0) b.element('w:br');
      b.element('w:t', attributes: {'xml:space': 'preserve'}, nest: line);
    }
  });
}

ArchiveFile _text(String name, String content) {
  final bytes = utf8.encode(content);
  return ArchiveFile(name, bytes.length, bytes);
}

String _contentTypes(bool comments) => '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
<Default Extension="xml" ContentType="application/xml"/>
<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
<Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>
<Override PartName="/word/numbering.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.numbering+xml"/>
${comments ? '<Override PartName="/word/comments.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.comments+xml"/>\n' : ''}</Types>''';

const _rootRels = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
</Relationships>''';

String _documentRels(bool comments) => '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/numbering" Target="numbering.xml"/>
${comments ? '<Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/comments" Target="comments.xml"/>\n' : ''}</Relationships>''';

const _styles = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
<w:docDefaults>
<w:rPrDefault><w:rPr><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri" w:eastAsia="Calibri" w:cs="Calibri"/><w:sz w:val="22"/><w:lang w:val="fr-FR"/></w:rPr></w:rPrDefault>
<w:pPrDefault><w:pPr><w:spacing w:after="160" w:line="259" w:lineRule="auto"/></w:pPr></w:pPrDefault>
</w:docDefaults>
<w:style w:type="paragraph" w:default="1" w:styleId="Normal"><w:name w:val="Normal"/><w:qFormat/></w:style>
<w:style w:type="paragraph" w:styleId="Heading1"><w:name w:val="heading 1"/><w:basedOn w:val="Normal"/><w:next w:val="Normal"/><w:qFormat/>
<w:pPr><w:keepNext/><w:spacing w:before="240" w:after="120"/><w:outlineLvl w:val="0"/></w:pPr>
<w:rPr><w:b/><w:sz w:val="32"/></w:rPr></w:style>
<w:style w:type="paragraph" w:styleId="ListParagraph"><w:name w:val="List Paragraph"/><w:basedOn w:val="Normal"/><w:pPr><w:ind w:left="720"/></w:pPr></w:style>
<w:style w:type="character" w:styleId="CommentReference"><w:name w:val="annotation reference"/><w:rPr><w:sz w:val="16"/></w:rPr></w:style>
</w:styles>''';

const _numbering = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:numbering xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
<w:abstractNum w:abstractNumId="0"><w:multiLevelType w:val="singleLevel"/>
<w:lvl w:ilvl="0"><w:start w:val="1"/><w:numFmt w:val="bullet"/><w:lvlText w:val="•"/><w:lvlJc w:val="left"/>
<w:pPr><w:ind w:left="720" w:hanging="360"/></w:pPr></w:lvl></w:abstractNum>
<w:num w:numId="1"><w:abstractNumId w:val="0"/></w:num>
</w:numbering>''';

String _comments(List<(int, String)> comments) {
  final b = XmlBuilder();
  b.processing('xml', 'version="1.0" encoding="UTF-8" standalone="yes"');
  b.element('w:comments', namespaceUris: {'w': _w}, nest: () {
    for (final (id, text) in comments) {
      b.element('w:comment', attributes: {'w:id': '$id', 'w:author': 'LADS Trad', 'w:initials': 'LT'}, nest: () {
        b.element('w:p', nest: () => _runs(b, text, muted: false));
      });
    }
  });
  return b.buildDocument().toXmlString();
}
