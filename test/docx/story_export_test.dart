import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lads_trad/data/database.dart';
import 'package:lads_trad/data/library_repository.dart';
import 'package:lads_trad/data/models.dart';
import 'package:lads_trad/docx/docx_reader.dart';
import 'package:lads_trad/docx/docx_writer.dart';
import 'package:lads_trad/docx/story_export.dart';
import 'package:lads_trad/docx/story_model.dart';
import 'package:lads_trad/docx/story_parser.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

DocParagraph p(String text, {bool h1 = false, bool list = false}) =>
    DocParagraph(text: text, isHeading1: h1, isListItem: list);

final _fr = [
  p('Into The Canvas (Memoria)', h1: true),
  p('ÉPISODE 1', h1: true),
  p('Rafayel : Les couleurs sont prêtes.'),
  p('Moi : (Il a l\'air content.)'),
  p('Il sourit.'),
  p('KINDLED', h1: true),
  p('Choix:'),
  p('Réussite !', list: true),
  p('Rafayel : Pas mal.'),
  p('Échec…', list: true),
  p('Rafayel : Dommage.'),
  p('---'),
  p('Rafayel : À demain.'),
];

final _en = [
  p('Into The Canvas (Memoria)', h1: true),
  p('EPISODE 1', h1: true),
  p('Rafayel : The colors are ready.'),
  p('MC : (He looks happy.)'),
  p('He smiles.'),
  p('KINDLED', h1: true),
  p('Choices :'),
  p('01. Success!'),
  p('Rafayel : Not bad.'),
  p('02. Failure...'),
  p('Rafayel : Too bad.'),
  p('---'),
  p('Rafayel : See you tomorrow.'),
];

/// Structure lisible d'une histoire analysée, pour comparer deux imports.
List<String> outline(ParsedStory s, {bool en = false}) => [
      for (final part in s.parts) ...[
        '# ${en ? part.title.en : part.title.fr}',
        for (final item in part.items)
          switch (item) {
            StoryLine() => _line(item, en),
            Choice() => [
                for (final o in item.options) '* ${en ? o.label.en : o.label.fr} → ${o.lines.map((l) => _line(l, en)).join(' | ')}',
              ].join(' ; '),
          },
      ],
    ];

String _line(StoryLine l, bool en) =>
    '${l.kind.name}:${en ? l.speaker?.en ?? '-' : l.speaker?.fr ?? '-'}:${en ? l.text.en : l.text.fr}';

void main() {
  sqfliteFfiInit();
  late LibraryRepository repo;
  late Directory covers;
  late int storyId;

  setUp(() async {
    covers = await Directory.systemTemp.createTemp('lads_covers');
    final db = await openLibraryDatabase(factory: databaseFactoryFfi, path: inMemoryDatabasePath, singleInstance: false);
    repo = LibraryRepository(db, coversDir: covers);
    final folder = await repo.folderFor((await repo.characters()).first.id, FolderType.memoria, rarity: 5);
    storyId = await repo.saveStory(folderId: folder, title: '', parsed: parseStoryParagraphs(fr: _fr, en: _en));
  });

  tearDown(() => covers.delete(recursive: true));

  Future<ExportFile> export(ExportLanguage language, {bool notes = false}) async =>
      (await exportStory(repo, storyId, language: language, notes: notes)).first;

  test('FR et EN exportés se réimportent à l\'identique', () async {
    final original = parseStoryParagraphs(fr: _fr, en: _en);
    final files = await exportStory(repo, storyId, language: ExportLanguage.both);
    expect(files.map((f) => f.name), ['Into The Canvas - FR.docx', 'Into The Canvas - EN.docx']);

    final again = parseStoryDocx(fr: files[0].bytes, en: files[1].bytes);
    expect(again.title.fr, 'Into The Canvas');
    expect(again.warnings, isEmpty);
    expect(outline(again), outline(original));
    expect(outline(again, en: true), outline(original, en: true));
  });

  test('les corrections faites dans l\'éditeur sont dans le FR exporté', () async {
    final part = (await repo.parts(storyId)).first;
    final first = (await repo.lines(part.id)).first;
    await repo.updateLine(first.id, kind: LineRowKind.dialogue, text: 'Tout est prêt.', speaker: 'Rafayel');
    await repo.appendLine(part.id, kind: LineRowKind.thought, text: 'Enfin seuls', speaker: 'Moi');

    final fr = readDocxParagraphs((await export(ExportLanguage.fr)).bytes).map((x) => x.text).toList();
    expect(fr, contains('Rafayel : Tout est prêt.'));
    expect(fr, contains('Moi : (Enfin seuls)'), reason: 'une pensée garde ses parenthèses');

    // Réplique ajoutée sans anglais : absente de l'EN.
    final en = readDocxParagraphs((await export(ExportLanguage.en)).bytes).map((x) => x.text).toList();
    expect(en, isNot(contains(contains('Enfin seuls'))));
  });

  test('les notes deviennent des commentaires Word, seulement si demandé', () async {
    final part = (await repo.parts(storyId)).first;
    final first = (await repo.lines(part.id)).first;
    await repo.updateLine(first.id, kind: LineRowKind.dialogue, text: first.text, speaker: 'Rafayel', note: 'Vérifier « prêtes »');

    String? comments(ExportFile f) {
      final entry = ZipDecoder().decodeBytes(f.bytes).findFile('word/comments.xml');
      return entry == null ? null : utf8.decode(entry.content);
    }

    expect(comments(await export(ExportLanguage.fr)), isNull);
    final withNotes = await export(ExportLanguage.fr, notes: true);
    expect(comments(withNotes), contains('Vérifier « prêtes »'));
    // Le texte reste lisible et réimportable avec les commentaires.
    expect(readDocxParagraphs(withNotes.bytes).map((x) => x.text), contains('Rafayel : Les couleurs sont prêtes.'));
  });

  test('le bilingue met l\'anglais puis le français, ligne par ligne', () async {
    final file = await export(ExportLanguage.bilingual);
    expect(file.name, 'Into The Canvas - EN-FR.docx');
    final texts = readDocxParagraphs(file.bytes).map((x) => x.text).toList();
    final i = texts.indexOf('Rafayel : The colors are ready.');
    expect(texts[i + 1], 'Rafayel : Les couleurs sont prêtes.');
    expect(texts, contains('EPISODE 1 / ÉPISODE 1'));
  });

  test('les noms de fichiers évitent les caractères interdits', () {
    expect(exportFileNames('Qui ? Moi / toi', ExportLanguage.fr), ['Qui Moi toi - FR.docx']);
    expect(exportFileNames('  ', ExportLanguage.en), ['Histoire - EN.docx']);
  });

  test('buildDocx échappe le texte et garde les retours à la ligne', () {
    final bytes = buildDocx(const [OutParagraph('A & B <c>\nsuite', heading: true)]);
    final paragraphs = readDocxParagraphs(bytes);
    expect(paragraphs.single.text, 'A & B <c>\nsuite');
    expect(paragraphs.single.isHeading1, isTrue);
  });

  test('les noms des personnages sont en gras, pas le texte', () async {
    final file = await export(ExportLanguage.fr);
    final xml = utf8.decode(ZipDecoder().decodeBytes(file.bytes).findFile('word/document.xml')!.content);
    final runs = RegExp(r'<w:r>(.*?)</w:r>').allMatches(xml).map((m) => m.group(1)!).toList();
    final name = runs.indexWhere((r) => r.contains('>Rafayel</w:t>'));
    expect(runs[name], contains('<w:b/>'));
    expect(runs[name + 1], contains(' : Les couleurs sont prêtes.'));
    expect(runs[name + 1], isNot(contains('<w:b/>')));
    expect(runs.where((r) => r.contains('Il sourit.')).single, isNot(contains('<w:b/>')), reason: 'narration');
    // Toujours réimportable.
    expect(readDocxParagraphs(file.bytes).map((x) => x.text), contains('Rafayel : Les couleurs sont prêtes.'));
  });
}
