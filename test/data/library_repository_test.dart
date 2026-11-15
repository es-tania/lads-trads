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
    expect(folders.single.covers, [story.cover]);
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

    await repo.setImageCrop(xavier.id, const ImageCrop(x: 0.3, y: 0.25, d: 0.6));
    stored = (await repo.characters())[1];
    expect(stored.crop, const ImageCrop(x: 0.3, y: 0.25, d: 0.6));

    // Une nouvelle image remplace l'ancienne, fichier compris, avec son cadrage.
    await repo.setCharacterImage(xavier.id, Uint8List.fromList([6]), 'x.png', crop: const ImageCrop(x: 0.5, y: 0.4, d: 0.8));
    stored = (await repo.characters())[1];
    expect(stored.imagePath, isNot(first));
    expect(File(first).existsSync(), isFalse);
    expect(stored.crop, const ImageCrop(x: 0.5, y: 0.4, d: 0.8));
    expect((await repo.characters()).first.imagePath, isNull, reason: 'les autres personnages ne changent pas');
  });

  test("le cercle de recadrage reste dans l'image", () {
    const size = Size(300, 400);
    final c = const ImageCrop(x: 0, y: 1, d: 0.8).clampTo(size);
    // Rayon : 0,8 × 300 / 2 = 120 px.
    expect(c.x, closeTo(120 / 300, 1e-9));
    expect(c.y, closeTo(280 / 400, 1e-9));
    expect(ImageCrop.character.frameIn(size), const Rect.fromLTWH(30, 80, 240, 240));
  });

  Future<int> storyIn(int folderId, {Uint8List? cover}) => repo.saveStory(
        folderId: folderId,
        title: 'Into The Canvas',
        parsed: parseStoryParagraphs(fr: [p('FIN', h1: true), p('Il part.')], en: [p('END', h1: true), p('He leaves.')]),
        coverBytes: cover,
        coverName: cover == null ? null : 'c.png',
      );

  test("modifie le titre et le dossier d'une histoire, retire sa couverture", () async {
    final [rafayel, xavier, ...] = await repo.characters();
    final from = await repo.folderFor(rafayel.id, FolderType.memoria, rarity: 5);
    final to = await repo.folderFor(xavier.id, FolderType.myths);
    final id = await storyIn(from, cover: Uint8List.fromList([1]));
    final cover = (await repo.story(id))!.coverPath!;

    await repo.updateStory(id, title: '  Dans la toile ', folderId: to);
    await repo.removeCover(id);

    final story = (await repo.story(id))!;
    expect(story.title, 'Dans la toile');
    expect(story.characterName, 'Xavier');
    expect(story.folderName, 'Myths');
    expect(story.coverPath, isNull);
    expect(File(cover).existsSync(), isFalse);
    await expectLater(repo.updateStory(id, title: ' ', folderId: to), throwsArgumentError);
  });

  test('remplace le contenu en gardant titre, dossier et couverture', () async {
    final rafayel = (await repo.characters()).first.id;
    final folder = await repo.folderFor(rafayel, FolderType.memoria, rarity: 5);
    final id = await storyIn(folder, cover: Uint8List.fromList([1]));
    final before = (await repo.story(id))!;

    await repo.replaceStoryContent(
      id,
      parseStoryParagraphs(
        fr: [p('UN', h1: true), p('A.'), p('DEUX', h1: true), p('B.'), p('C.')],
        en: [p('ONE', h1: true), p('A.'), p('TWO', h1: true), p('B.'), p('C.')],
      ),
    );

    final after = (await repo.story(id))!;
    expect(after.title, before.title);
    expect(after.folderId, folder);
    expect(after.coverPath, before.coverPath);
    // Les anciennes répliques ne restent pas : chaque partie a exactement les nouvelles.
    expect((await repo.parts(id)).map((x) => (x.displayTitle, x.lineCount)), [('Un', 1), ('Deux', 2)]);
  });

  test("modifie un dossier, refuse un nom en double, ne supprime qu'un dossier vide", () async {
    final [rafayel, xavier, ...] = await repo.characters();
    final five = await repo.folderFor(rafayel.id, FolderType.memoria, rarity: 5);
    final other = await repo.createFolder(rafayel.id, ' À relire ', FolderType.other);
    expect((await repo.folder(other))!.name, 'À relire');
    expect(await repo.folderNameTaken(rafayel.id, 'à RELIRE'), isTrue);
    expect(await repo.folderNameTaken(rafayel.id, 'à relire', exceptId: other), isFalse);
    expect(await repo.folderNameTaken(xavier.id, 'À relire'), isFalse);

    await expectLater(
      repo.updateFolder(other, characterId: rafayel.id, name: 'memoria 5★', type: FolderType.other),
      throwsA(isA<DuplicateFolderException>()),
    );
    await repo.updateFolder(other, characterId: xavier.id, name: 'Favoris', type: FolderType.memoria, rarity: 4);
    final moved = (await repo.folder(other))!;
    expect((moved.characterId, moved.name, moved.type, moved.rarity), (xavier.id, 'Favoris', FolderType.memoria, 4));

    await storyIn(five);
    await expectLater(repo.deleteFolder(five), throwsStateError);
    expect(await repo.folder(five), isNotNull);
    await repo.deleteFolder(other);
    expect(await repo.folder(other), isNull);
  });

  test("le cadrage d'une couverture est gardé, et remis à zéro avec une nouvelle image", () async {
    final rafayel = (await repo.characters()).first.id;
    final folder = await repo.folderFor(rafayel, FolderType.memoria, rarity: 5);
    const crop = ImageCrop(x: 0.4, y: 0.3, d: 0.6);
    final id = await storyIn(folder, cover: Uint8List.fromList([1]));
    expect((await repo.story(id))!.coverCrop, isNull, reason: 'le plus grand cadre centré par défaut');

    await repo.setCoverCrop(id, crop);
    var story = (await repo.story(id))!;
    expect(story.coverCrop, crop);
    expect((await repo.folders(rafayel)).single.covers.single, CoverImage(story.coverPath!, crop));

    await repo.setCover(id, Uint8List.fromList([2]), 'b.png');
    expect((await repo.story(id))!.coverCrop, isNull);
    await repo.setCover(id, Uint8List.fromList([3]), 'c.png', crop: crop);
    expect((await repo.story(id))!.coverCrop, crop);
    await repo.removeCover(id);
    story = (await repo.story(id))!;
    expect((story.coverPath, story.coverCrop), (null, null));
  });

  test("un cadre 3:4 reste dans l'image et sa taille suit le plus grand cadre possible", () {
    // Image paysage 400 × 300 : le plus grand 3:4 fait 225 × 300.
    const size = Size(400, 300);
    expect(ImageCrop.maxFrame(size, 3 / 4), const Size(225, 300));
    expect(ImageCrop.full.frameIn(size, aspect: 3 / 4), const Rect.fromLTWH(87.5, 0, 225, 300));
    // À moitié de la taille, poussé à gauche : il bute sur le bord.
    final r = const ImageCrop(x: 0, y: 0.5, d: 0.5).frameIn(size, aspect: 3 / 4);
    expect(r, const Rect.fromLTWH(0, 75, 112.5, 150));
  });

  test("hasEnglish dit si l'histoire a été importée avec l'anglais", () async {
    final folder = await repo.folderFor((await repo.characters()).first.id, FolderType.other);
    final withEn = await storyIn(folder);
    final frOnly = await repo.saveStory(
      folderId: folder,
      title: 'Sans anglais',
      parsed: parseStoryParagraphs(fr: [p('FIN', h1: true), p('Il part.')]),
    );
    expect(await repo.hasEnglish(withEn), isTrue);
    expect(await repo.hasEnglish(frOnly), isFalse);
  });
}
