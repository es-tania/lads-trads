import 'dart:typed_data';

import '../data/library_repository.dart';
import '../data/models.dart';
import 'docx_writer.dart';

/// Langue d'un export.
enum ExportLanguage {
  fr('Français', 'Ta traduction, avec les corrections'),
  en('Anglais', 'Le texte original importé'),
  both('Les deux', 'Deux fichiers séparés'),
  bilingual('Bilingue', 'Anglais puis français, ligne par ligne, pour relire');

  const ExportLanguage(this.label, this.hint);

  final String label;
  final String hint;
}

/// Un fichier prêt à enregistrer ou partager.
class ExportFile {
  const ExportFile(this.name, this.bytes);

  final String name;
  final Uint8List bytes;
}

/// Noms des fichiers produits pour [title] dans cette langue.
List<String> exportFileNames(String title, ExportLanguage language) {
  final base = _safeName(title);
  return switch (language) {
    ExportLanguage.fr => ['$base - FR.docx'],
    ExportLanguage.en => ['$base - EN.docx'],
    ExportLanguage.both => ['$base - FR.docx', '$base - EN.docx'],
    ExportLanguage.bilingual => ['$base - EN-FR.docx'],
  };
}

/// Caractères interdits dans un nom de fichier retirés.
String _safeName(String title) {
  final cleaned = title.replaceAll(RegExp(r'[\\/:*?"<>|]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  return cleaned.isEmpty ? 'Histoire' : cleaned;
}

/// Lit l'histoire en base et produit le ou les .docx demandés.
Future<List<ExportFile>> exportStory(
  LibraryRepository library,
  int storyId, {
  required ExportLanguage language,
  bool notes = false,
}) async {
  final story = await library.story(storyId);
  if (story == null) throw StateError('Histoire introuvable.');
  final parts = [for (final part in await library.parts(storyId)) (part, await library.lines(part.id))];
  final names = exportFileNames(story.title, language);

  List<OutParagraph> one(_Lang lang) => _storyParagraphs(story, parts, lang: lang, notes: notes);
  return switch (language) {
    ExportLanguage.fr => [ExportFile(names[0], buildDocx(one(_Lang.fr)))],
    ExportLanguage.en => [ExportFile(names[0], buildDocx(one(_Lang.en)))],
    ExportLanguage.both => [
        ExportFile(names[0], buildDocx(one(_Lang.fr))),
        ExportFile(names[1], buildDocx(_storyParagraphs(story, parts, lang: _Lang.en, notes: false))),
      ],
    ExportLanguage.bilingual => [ExportFile(names[0], buildDocx(one(_Lang.bilingual)))],
  };
}

enum _Lang { fr, en, bilingual }

/// Paragraphes d'une histoire, dans la mise en forme des fichiers d'origine :
/// titre et parties en « Titre 1 », « Nom : texte », « Choix: » suivi des
/// options en puces et de leurs répliques, « --- » pour fermer le choix.
List<OutParagraph> _storyParagraphs(
  Story story,
  List<(Part, List<LineRow>)> parts, {
  required _Lang lang,
  bool notes = false,
}) {
  final out = <OutParagraph>[];
  final en = lang == _Lang.en;

  String title(String fr, String english) => switch (lang) {
        _Lang.fr => fr,
        _Lang.en => english.isEmpty ? fr : english,
        _Lang.bilingual => english.isEmpty || english == fr ? fr : '$english / $fr',
      };

  // Le titre de l'histoire n'est reconnu que s'il est suivi d'un titre de partie.
  final firstPartTitled = parts.isNotEmpty && parts.first.$1.title.trim().isNotEmpty;
  if (firstPartTitled && story.title.trim().isNotEmpty) {
    out.add(OutParagraph(title(story.title, story.titleEn), heading: true));
  }

  for (final (part, rows) in parts) {
    if (part.title.trim().isNotEmpty) out.add(OutParagraph(title(part.title, part.titleEn), heading: true));

    final children = <int, List<LineRow>>{};
    for (final r in rows) {
      if (r.parentId != null) children.putIfAbsent(r.parentId!, () => []).add(r);
    }

    void line(LineRow r) {
      final note = notes && r.note != null ? r.note : null;
      switch (lang) {
        case _Lang.fr:
          out.add(_lineParagraph(r, en: false, comment: note));
        case _Lang.en:
          // Une réplique ajoutée dans l'éditeur n'a pas d'anglais.
          if (r.textEn.trim().isNotEmpty) out.add(_lineParagraph(r, en: true));
        case _Lang.bilingual:
          if (r.textEn.trim().isNotEmpty) out.add(_lineParagraph(r, en: true, muted: true));
          out.add(_lineParagraph(r, en: false, comment: note));
      }
    }

    for (final row in rows.where((r) => r.parentId == null)) {
      if (row.kind == LineRowKind.option) continue;
      if (row.kind != LineRowKind.choice) {
        line(row);
        continue;
      }
      out.add(OutParagraph(_choicePrompt(row, en: en)));
      for (final (i, option) in (children[row.id] ?? const <LineRow>[]).indexed) {
        final label = switch (lang) {
          _Lang.fr => option.text,
          _Lang.en => option.textEn.isEmpty ? option.text : option.textEn,
          _Lang.bilingual => option.textEn.isEmpty || option.textEn == option.text
              ? option.text
              : '${option.textEn} / ${option.text}',
        };
        // L'anglais d'origine numérote ses options (« 01. Success! »).
        out.add(OutParagraph(en ? '${(i + 1).toString().padLeft(2, '0')}. $label' : label, listItem: !en));
        for (final l in children[option.id] ?? const <LineRow>[]) {
          line(l);
        }
      }
      out.add(const OutParagraph('---'));
    }
  }
  return out;
}

String _choicePrompt(LineRow row, {required bool en}) {
  final text = en ? row.textEn : row.text;
  if (text.trim().isNotEmpty) return text;
  return en ? 'Choices :' : 'Choix:';
}

/// « Nom : texte », le nom en gras ; une pensée garde ses parenthèses, pour
/// être reconnue à la réimportation.
OutParagraph _lineParagraph(LineRow r, {required bool en, bool muted = false, String? comment}) {
  final text = en ? r.textEn : r.text;
  if (r.kind == LineRowKind.narration || r.speaker == null) return OutParagraph(text, muted: muted, comment: comment);
  final speaker = en && (r.speakerEn?.trim().isNotEmpty ?? false) ? r.speakerEn! : r.speaker!;
  final body = r.kind == LineRowKind.thought && !text.trimLeft().startsWith('(') ? '($text)' : text;
  return OutParagraph('$speaker : $body', boldLength: speaker.length, muted: muted, comment: comment);
}
