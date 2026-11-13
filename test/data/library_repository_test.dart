import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:lads_trad/data/database.dart';
import 'package:lads_trad/data/library_repository.dart';
import 'package:lads_trad/data/models.dart';
import 'package:lads_trad/docx/docx_reader.dart';
import 'package:lads_trad/docx/story_parser.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

DocParagraph p(String text, {bool h1 = false, bool list = false}) =>
    DocParagraph(text: text, isHeading1: h1, isListItem: list);

void main() {
  sqfliteFfiInit();
  late LibraryRepository repo;
  late Directory covers;

  setUp(() async {
    covers = await Directory.systemTemp.createTemp('lads_covers');
    final db = await openLibraryDatabase(factory: databaseFactoryFfi, path: inMemoryDatabasePath, singleInstance: false);
    repo = LibraryRepository(db, coversDir: covers);
  });

  tearDown(() => covers.delete(recursive: true));

  test('les cinq personnages sont créés au premier lancement', () async {
    expect((await repo.characters()).map((c) => c.name), defaultCharacters);
  });

  test('un dossier par type et rareté, réutilisé ensuite', () async {
    final rafayel = (await repo.characters()).first.id;
    final five = await repo.folderFor(rafayel, FolderType.memoria, rarity: 5);
    final four = await repo.folderFor(rafayel, FolderType.memoria, rarity: 4);
    final myths = await repo.folderFor(rafayel, FolderType.myths);
    expect(await repo.folderFor(rafayel, FolderType.memoria, rarity: 5), five);
    expect({five, four, myths}, hasLength(3));
    expect((await repo.folders(rafayel)).map((f) => f.name), ['Memoria 5★', 'Memoria 4★', 'Myths']);
  });

  test('enregistre parties, répliques, choix et branches dans l\'ordre', () async {
    final parsed = parseStoryParagraphs(
      fr: [
        p('ÉPISODE 1', h1: true),
        p('Rafayel : Salut.'),
        p('KINDLED', h1: true),
        p('Choix:'),
        p('Réussite !', list: true),
        p('Rafayel : Bravo.'),
        p('Échec…', list: true),
        p('Rafayel : Dommage.'),
        p('---'),
        p('Il sourit.'),
      ],
      en: [
        p('EPISODE 1', h1: true),
        p('Rafayel : Hi.'),
        p('KINDLED', h1: true),
        p('Choices :'),
        p('01. Success!'),
        p('Rafayel : Well done.'),
        p('02. Failure...'),
        p('Rafayel : Too bad.'),
        p('---'),
        p('He smiles.'),
      ],
    );
    final rafayel = (await repo.characters()).first.id;
    final folder = await repo.folderFor(rafayel, FolderType.memoria, rarity: 5);
    var notified = 0;
    repo.addListener(() => notified++);

    final storyId = await repo.saveStory(
      folderId: folder,
      title: 'Test',
      parsed: parsed,
      coverBytes: Uint8List.fromList([1, 2, 3]),
      coverName: 'image.PNG',
    );

    expect(notified, 1);
    final story = (await repo.story(storyId))!;
    expect(story.title, 'Test');
    expect(story.partCount, 2);
    expect(story.characterName, 'Rafayel');
    expect(story.folderName, 'Memoria 5★');
    expect(story.coverPath, endsWith('.png'));
    expect(File(story.coverPath!).readAsBytesSync(), [1, 2, 3]);

    final parts = await repo.parts(storyId);
    expect(parts.map((x) => x.displayTitle), ['Épisode 1', 'Kindled']);
    expect(parts.map((x) => x.lineCount), [1, 3]);

    final lines = await repo.lines(parts[1].id);
    expect(lines.map((l) => l.kind), [
      LineRowKind.choice,
      LineRowKind.option,
      LineRowKind.dialogue,
      LineRowKind.option,
      LineRowKind.dialogue,
      LineRowKind.narration,
    ]);
    final choice = lines[0];
    final success = lines[1];
    expect(success.parentId, choice.id);
    expect(success.textEn, 'Success!');
    expect(lines[2].parentId, success.id);
    expect(lines[4].parentId, lines[3].id);
    expect(lines[5].parentId, isNull);
    expect(lines[5].textEn, 'He smiles.');

    final folders = await repo.folders(rafayel);
    expect(folders.single.storyCount, 1);
    expect(folders.single.covers, [story.coverPath]);
    expect((await repo.recentStories(rafayel)).single.id, storyId);
    expect((await repo.searchStories('tes')).single.id, storyId);
    expect(await repo.searchStories('100%'), isEmpty);
  });

  test('supprimer une histoire efface ses parties et sa couverture', () async {
    final parsed = parseStoryParagraphs(fr: [p('FIN', h1: true), p('Il part.')], en: [p('END', h1: true), p('He leaves.')]);
    final rafayel = (await repo.characters()).first.id;
    final folder = await repo.folderFor(rafayel, FolderType.other);
    final id = await repo.saveStory(folderId: folder, title: '', parsed: parsed, coverBytes: Uint8List(1), coverName: 'c.jpg');
    final cover = (await repo.story(id))!.coverPath!;
    final partId = (await repo.parts(id)).single.id;

    await repo.deleteStory(id);

    expect(await repo.story(id), isNull);
    expect(await repo.lines(partId), isEmpty);
    expect(File(cover).existsSync(), isFalse);
  });

  test('ajoute un personnage à la fin, refuse les doublons et les noms vides', () async {
    var notified = 0;
    repo.addListener(() => notified++);
    final id = await repo.addCharacter('  Valko ');
    final all = await repo.characters();
    expect(all.map((c) => c.name), [...defaultCharacters, 'Valko']);
    expect(all.last.id, id);
    expect(all.last.imagePath, isNull);
    expect(all.last.crop, isNull);
    expect(all.last.initial, 'V');
    expect(notified, 1);

    await expectLater(repo.addCharacter('valko'), throwsA(isA<DuplicateCharacterException>()));
    await expectLater(repo.addCharacter('   '), throwsArgumentError);
    expect(await repo.characters(), hasLength(6));
  });

  test("copie l'image d'un personnage et enregistre son recadrage", () async {
    final xavier = (await repo.characters())[1];
    await repo.setCharacterImage(xavier.id, Uint8List.fromList([4, 5]), 'Xavier.JPG');
    var stored = (await repo.characters())[1];
    final first = stored.imagePath!;
    expect(first, endsWith('.jpg'));
    expect(path.isWithin(covers.path, first), isTrue);
    expect(File(first).readAsBytesSync(), [4, 5]);
    expect(stored.crop, isNull, reason: "cadrage par défaut tant qu'il n'est pas choisi");

    await repo.setCharacterCrop(xavier.id, const CharacterCrop(x: 0.3, y: 0.25, d: 0.6));
    stored = (await repo.characters())[1];
    expect(stored.crop, const CharacterCrop(x: 0.3, y: 0.25, d: 0.6));

    // Une nouvelle image remplace l'ancienne, fichier compris, avec son cadrage.
    await repo.setCharacterImage(xavier.id, Uint8List.fromList([6]), 'x.png', crop: const CharacterCrop(x: 0.5, y: 0.4, d: 0.8));
    stored = (await repo.characters())[1];
    expect(stored.imagePath, isNot(first));
    expect(File(first).existsSync(), isFalse);
    expect(stored.crop, const CharacterCrop(x: 0.5, y: 0.4, d: 0.8));
    expect((await repo.characters()).first.imagePath, isNull, reason: 'les autres personnages ne changent pas');
  });

  test("le cercle de recadrage reste dans l'image", () {
    const size = Size(300, 400);
    final c = const CharacterCrop(x: 0, y: 1, d: 0.8).clampTo(size);
    // Rayon : 0,8 × 300 / 2 = 120 px.
    expect(c.x, closeTo(120 / 300, 1e-9));
    expect(c.y, closeTo(280 / 400, 1e-9));
    expect(CharacterCrop.fallback.squareIn(size), const Rect.fromLTWH(30, 80, 240, 240));
  });
}
