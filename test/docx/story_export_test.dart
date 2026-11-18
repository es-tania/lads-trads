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

/// Structure lisible d'une histoire analysée, pour comparer deux imports.
List<String> outline(ParsedStory s) => [
      for (final part in s.parts) ...[
        '# ${part.title}',
        for (final item in part.items)
          switch (item) {
            StoryLine() => _line(item),
            Choice() => [
                for (final o in item.options) '* ${o.label} → ${o.lines.map(_line).join(' | ')}',
              ].join(' ; '),
          },
      ],
    ];

String _line(StoryLine l) => '${l.kind.name}:${l.speaker ?? '-'}:${l.text}';

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
    storyId = await repo.saveStory(folderId: folder, title: '', parsed: parseStoryParagraphs(_fr));
  });

  tearDown(() => covers.delete(recursive: true));

  Future<ExportFile> export() => exportStory(repo, storyId);

  test("l'histoire exportée se réimporte à l'identique", () async {
    final file = await export();
    expect(file.name, 'Into The Canvas - FR.docx');

    final again = parseStoryDocx(file.bytes);
    expect(again.title, 'Into The Canvas');
    expect(again.warnings, isEmpty);
    expect(outline(again), outline(parseStoryParagraphs(_fr)));
  });

  test("les corrections faites dans l'éditeur sont dans le fichier exporté", () async {
    final part = (await repo.parts(storyId)).first;
    final first = (await repo.lines(part.id)).first;
    await repo.updateLine(first.id, kind: LineRowKind.dialogue, text: 'Tout est prêt.', speaker: 'Rafayel');
    await repo.appendLine(part.id, kind: LineRowKind.thought, text: 'Enfin seuls', speaker: 'Moi');

    final texts = readDocxParagraphs((await export()).bytes).map((x) => x.text).toList();
    expect(texts, contains('Rafayel : Tout est prêt.'));
    expect(texts, contains('Moi : (Enfin seuls)'), reason: 'une pensée garde ses parenthèses');
  });

  test('les noms de fichiers évitent les caractères interdits', () {
    expect(exportFileName('Qui ? Moi / toi'), 'Qui Moi toi - FR.docx');
    expect(exportFileName('  '), 'Histoire - FR.docx');
  });

  test('buildDocx échappe le texte et garde les retours à la ligne', () {
    final bytes = buildDocx(const [OutParagraph('A & B <c>\nsuite', heading: true)]);
    final paragraphs = readDocxParagraphs(bytes);
    expect(paragraphs.single.text, 'A & B <c>\nsuite');
    expect(paragraphs.single.isHeading1, isTrue);
  });

  test('les noms des personnages sont en gras, pas le texte', () async {
    final file = await export();
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

  test("le gras et l'italique d'une réplique deviennent du gras et de l'italique Word", () async {
    final part = (await repo.parts(storyId)).first;
    final first = (await repo.lines(part.id)).first;
    await repo.updateLine(first.id, kind: LineRowKind.dialogue, text: 'Les <i>couleurs</i> sont <b>prêtes</b>.', speaker: 'Rafayel');
    final file = await export();
    final xml = utf8.decode(ZipDecoder().decodeBytes(file.bytes).findFile('word/document.xml')!.content);
    final runs = RegExp(r'<w:r>(.*?)</w:r>').allMatches(xml).map((m) => m.group(1)!).toList();
    String run(String text) => runs.firstWhere((r) => r.contains('>$text</w:t>'));
    expect(run('couleurs'), contains('<w:i/>'));
    expect(run('prêtes'), contains('<w:b/>'));
    expect(run(' sont '), isNot(contains('<w:b/>')));
    expect(xml, isNot(contains('&lt;b&gt;')), reason: 'pas de balises dans le Word');
    expect(readDocxParagraphs(file.bytes).map((x) => x.text), contains('Rafayel : Les couleurs sont prêtes.'));
  });
}
