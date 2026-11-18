import 'dart:typed_data';

import '../data/library_repository.dart';
import '../data/models.dart';
import '../text/markup.dart';
import 'docx_writer.dart';

/// Un fichier prêt à enregistrer ou partager.
class ExportFile {
  const ExportFile(this.name, this.bytes);

  final String name;
  final Uint8List bytes;
}

/// Nom du fichier produit pour [title].
String exportFileName(String title) => '${_safeName(title)} - FR.docx';

/// Caractères interdits dans un nom de fichier retirés.
String _safeName(String title) {
  final cleaned = title.replaceAll(RegExp(r'[\\/:*?"<>|]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  return cleaned.isEmpty ? 'Histoire' : cleaned;
}

/// Lit l'histoire en base et produit son .docx.
Future<ExportFile> exportStory(LibraryRepository library, int storyId) async {
  final story = await library.story(storyId);
  if (story == null) throw StateError('Histoire introuvable.');
  final parts = [for (final part in await library.parts(storyId)) (part, await library.lines(part.id))];
  return ExportFile(exportFileName(story.title), buildDocx(_storyParagraphs(story, parts)));
}

/// Paragraphes d'une histoire, dans la mise en forme des fichiers d'origine :
/// titre et parties en « Titre 1 », « Nom : texte », « Choix: » suivi des
/// options en puces et de leurs répliques, « --- » pour fermer le choix.
List<OutParagraph> _storyParagraphs(Story story, List<(Part, List<LineRow>)> parts) {
  final out = <OutParagraph>[];

  // Le titre de l'histoire n'est reconnu que s'il est suivi d'un titre de partie.
  final firstPartTitled = parts.isNotEmpty && parts.first.$1.title.trim().isNotEmpty;
  if (firstPartTitled && story.title.trim().isNotEmpty) out.add(OutParagraph(story.title, heading: true));

  for (final (part, rows) in parts) {
    if (part.title.trim().isNotEmpty) out.add(OutParagraph(part.title, heading: true));

    final children = <int, List<LineRow>>{};
    for (final r in rows) {
      if (r.parentId != null) children.putIfAbsent(r.parentId!, () => []).add(r);
    }

    for (final row in rows.where((r) => r.parentId == null)) {
      if (row.kind == LineRowKind.option) continue;
      if (row.kind != LineRowKind.choice) {
        out.add(_lineParagraph(row));
        continue;
      }
      out.add(OutParagraph(row.text.trim().isEmpty ? 'Choix:' : row.text));
      for (final option in children[row.id] ?? const <LineRow>[]) {
        out.add(OutParagraph(option.text, listItem: true));
        for (final l in children[option.id] ?? const <LineRow>[]) {
          out.add(_lineParagraph(l));
        }
      }
      out.add(const OutParagraph('---'));
    }
  }
  return out;
}

/// « Nom : texte », le nom en gras et le gras / l'italique du texte gardés ;
/// une pensée garde ses parenthèses, pour être reconnue à la réimportation.
OutParagraph _lineParagraph(LineRow r) {
  final spans = markupSpans(r.text);
  if (r.kind == LineRowKind.narration || r.speaker == null) {
    return OutParagraph(plainText(r.text), spans: spans);
  }
  final speaker = r.speaker!;
  final wrap = r.kind == LineRowKind.thought && !plainText(r.text).trimLeft().startsWith('(');
  final body = [if (wrap) const MarkupSpan('('), ...spans, if (wrap) const MarkupSpan(')')];
  return OutParagraph(
    '$speaker : ${body.map((s) => s.text).join()}',
    spans: [MarkupSpan(speaker, bold: true), const MarkupSpan(' : '), ...body],
  );
}
