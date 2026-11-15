import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
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
  late int storyId;
  late int partId;

  setUp(() async {
    covers = await Directory.systemTemp.createTemp('lads_covers');
    final db = await openLibraryDatabase(factory: databaseFactoryFfi, path: inMemoryDatabasePath, singleInstance: false);
    repo = LibraryRepository(db, coversDir: covers);
    final rafayel = (await repo.characters()).first.id;
    final folder = await repo.folderFor(rafayel, FolderType.memoria, rarity: 5);
    storyId = await repo.saveStory(
      folderId: folder,
      title: 'Test',
      parsed: parseStoryParagraphs(
        fr: [
          p('KINDLED', h1: true),
          p('Rafayel : Salut.'),
          p('Choix:'),
          p('Réussite !', list: true),
          p('Rafayel : Bravo.'),
          p('Échec…', list: true),
          p('Rafayel : Dommage.'),
          p('---'),
          p('Il sourit.'),
        ],
        en: [
          p('KINDLED', h1: true),
          p('Rafayel : Hi.'),
          p('Choices :'),
          p('01. Success!'),
          p('Rafayel : Well done.'),
          p('02. Failure...'),
          p('Rafayel : Too bad.'),
          p('---'),
          p('He smiles.'),
        ],
      ),
    );
    partId = (await repo.parts(storyId)).single.id;
  });

  tearDown(() => covers.delete(recursive: true));

  /// Lignes de la partie : « type:texte », dans l'ordre.
  Future<List<String>> outline() async => [for (final l in await repo.lines(partId)) '${l.kind.name}:${l.text}'];

  Future<LineRow> line(String text) async => (await repo.lines(partId)).firstWhere((l) => l.text == text);

  test('modifie type, personnage, texte et note d\'une réplique', () async {
    final hello = await line('Salut.');
    await repo.updateLine(hello.id, kind: LineRowKind.thought, text: ' (Bonjour…) ', speaker: 'Moi', note: ' à revoir ');
    var edited = await line('(Bonjour…)');
    expect(edited.kind, LineRowKind.thought);
    expect(edited.speaker, 'Moi');
    expect(edited.speakerEn, isNull, reason: '« Moi » ne parle nulle part ailleurs');
    expect(edited.note, 'à revoir');
    expect(edited.textEn, 'Hi.', reason: 'l\'anglais reste pour se repérer');

    await repo.updateLine(hello.id, kind: LineRowKind.dialogue, text: 'Salut.', speaker: 'Rafayel', note: '');
    edited = await line('Salut.');
    expect(edited.speakerEn, 'Rafayel', reason: 'nom anglais repris d\'une autre ligne');
    expect(edited.note, isNull);

    await repo.updateLine(hello.id, kind: LineRowKind.narration, text: 'Silence.', speaker: 'Rafayel');
    expect((await line('Silence.')).speaker, isNull, reason: 'la narration n\'a pas de personnage');
    expect(await repo.speakers(storyId), ['Rafayel']);
  });

  test('insère avant, après, dans une branche et après un choix', () async {
    final hello = await line('Salut.');
    final bravo = await line('Bravo.');
    final choice = (await repo.lines(partId)).firstWhere((l) => l.kind == LineRowKind.choice);

    await repo.insertLineNextTo(hello.id, after: false, kind: LineRowKind.narration, text: 'Avant.');
    await repo.insertLineNextTo(bravo.id, after: true, kind: LineRowKind.dialogue, text: 'Encore.', speaker: 'Rafayel');
    await repo.insertLineNextTo(choice.id, after: true, kind: LineRowKind.narration, text: 'Après le choix.');
    await repo.appendLine(partId, kind: LineRowKind.narration, text: 'Fin.');

    expect(await outline(), [
      'narration:Avant.',
      'dialogue:Salut.',
      'choice:Choix:',
      'option:Réussite !',
      'dialogue:Bravo.',
      'dialogue:Encore.',
      'option:Échec…',
      'dialogue:Dommage.',
      'narration:Après le choix.',
      'narration:Il sourit.',
      'narration:Fin.',
    ]);
    final encore = await line('Encore.');
    expect(encore.parentId, bravo.parentId, reason: 'même branche');
    expect(encore.speakerEn, 'Rafayel');
    expect((await line('Après le choix.')).parentId, isNull, reason: 'dans le tronc');
    expect((await repo.parts(storyId)).single.lineCount, 8);
  });

  test('ajoute, renomme et supprime des branches', () async {
    final choice = (await repo.lines(partId)).firstWhere((l) => l.kind == LineRowKind.choice);
    final third = await repo.addOption(choice.id, ' Abandon ');
    await repo.appendLine(partId, optionId: third, kind: LineRowKind.dialogue, text: 'Tant pis.', speaker: 'Rafayel');
    final success = await line('Réussite !');
    await repo.updateOptionLabel(success.id, 'Gagné !');

    expect(await outline(), [
      'dialogue:Salut.',
      'choice:Choix:',
      'option:Gagné !',
      'dialogue:Bravo.',
      'option:Échec…',
      'dialogue:Dommage.',
      'option:Abandon',
      'dialogue:Tant pis.',
      'narration:Il sourit.',
    ]);

    // Supprimer une branche efface ses répliques ; la dernière emporte le choix.
    await repo.deleteLine(third);
    expect(await outline(), isNot(contains('dialogue:Tant pis.')));
    await repo.deleteLine(success.id);
    await repo.deleteLine((await line('Échec…')).id);
    expect(await outline(), ['dialogue:Salut.', 'narration:Il sourit.']);
  });

  test('pendant la lecture : texte et personnage changent, la note reste', () async {
    final hello = await line('Salut.');
    await repo.updateLine(hello.id, kind: LineRowKind.dialogue, text: 'Salut.', speaker: 'Rafayel', note: 'à revoir');
    var notified = 0;
    repo.addListener(() => notified++);

    var kind = await repo.updateLineWhileReading(hello.id, text: '  Coucou.  ', speaker: 'Rafayel');
    var edited = await line('Coucou.');
    expect((kind, edited.kind, edited.speaker, edited.textEn, edited.note), (LineRowKind.dialogue, LineRowKind.dialogue, 'Rafayel', 'Hi.', 'à revoir'));

    // Mauvais personnage dans la traduction : un nouveau.
    kind = await repo.updateLineWhileReading(hello.id, text: 'Coucou.', speaker: ' Zayne ');
    edited = await line('Coucou.');
    expect((edited.speaker, edited.speakerEn), ('Zayne', null));

    // Plus personne ne parle : narration ; puis à nouveau une réplique.
    kind = await repo.updateLineWhileReading(hello.id, text: 'Coucou.', speaker: null);
    expect(((await line('Coucou.')).kind, (await line('Coucou.')).speaker), (LineRowKind.narration, null));
    kind = await repo.updateLineWhileReading(hello.id, text: 'Coucou.', speaker: 'Rafayel');
    expect(kind, LineRowKind.dialogue);
    expect((await line('Coucou.')).speakerEn, 'Rafayel');

    await expectLater(repo.updateLineWhileReading(hello.id, text: ' ', speaker: null), throwsArgumentError);
    repo.refresh();
    expect(notified, 5);
  });

  test('une pensée reste une pensée quand son personnage change', () {
    expect(LibraryRepository.kindForSpeaker(LineRowKind.thought, 'Moi'), LineRowKind.thought);
    expect(LibraryRepository.kindForSpeaker(LineRowKind.thought, null), LineRowKind.narration);
    expect(LibraryRepository.kindForSpeaker(LineRowKind.narration, 'Moi'), LineRowKind.dialogue);
  });
}
