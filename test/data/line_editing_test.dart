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

  test('modifie type, personnage et texte d\'une réplique', () async {
    final hello = await line('Salut.');
    await repo.updateLine(hello.id, kind: LineRowKind.thought, text: ' (Bonjour…) ', speaker: 'Moi');
    var edited = await line('(Bonjour…)');
    expect(edited.kind, LineRowKind.thought);
    expect(edited.speaker, 'Moi');
    expect(edited.speakerEn, isNull, reason: '« Moi » ne parle nulle part ailleurs');
    expect(edited.textEn, 'Hi.', reason: 'l\'anglais reste pour se repérer');

    await repo.updateLine(hello.id, kind: LineRowKind.dialogue, text: 'Salut.', speaker: 'Rafayel');
    edited = await line('Salut.');
    expect(edited.speakerEn, 'Rafayel', reason: 'nom anglais repris d\'une autre ligne');

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

  test('pendant la lecture : texte et personnage changent', () async {
    final hello = await line('Salut.');
    var notified = 0;
    repo.addListener(() => notified++);

    var kind = await repo.updateLineWhileReading(hello.id, text: '  Coucou.  ', speaker: 'Rafayel');
    var edited = await line('Coucou.');
    expect((kind, edited.kind, edited.speaker, edited.textEn), (LineRowKind.dialogue, LineRowKind.dialogue, 'Rafayel', 'Hi.'));

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
    expect(LineRowKind.thought.withSpeaker('Moi'), LineRowKind.thought);
    expect(LineRowKind.thought.withSpeaker(null), LineRowKind.narration);
    expect(LineRowKind.narration.withSpeaker('Moi'), LineRowKind.dialogue);
  });

  test("renommer un personnage change toutes ses répliques, dans l'histoire ou partout", () async {
    // Une deuxième histoire où Rafayel parle aussi.
    final folder = (await repo.stories((await repo.story(storyId))!.folderId)).first.folderId;
    final other = await repo.saveStory(
      folderId: folder,
      title: 'Autre',
      parsed: parseStoryParagraphs(fr: [p('FIN', h1: true), p('Rafayel : Au revoir.')]),
    );
    expect(await repo.speakerCounts('Rafayel', storyId), (inStory: 3, everywhere: 4));

    expect(await repo.renameSpeaker('Rafayel', ' Rafaël ', storyId: storyId), 3);
    expect(await repo.speakers(storyId), ['Rafaël']);
    expect((await repo.lines((await repo.parts(other)).single.id)).single.speaker, 'Rafayel', reason: 'autre histoire');
    expect((await line('Salut.')).speakerEn, 'Rafayel', reason: 'le nom anglais ne change pas');

    expect(await repo.renameSpeaker('Rafayel', 'Rafaël'), 1, reason: 'toutes les histoires');
    expect(await repo.speakers(other), ['Rafaël']);
    await expectLater(repo.renameSpeaker('Rafaël', '  '), throwsArgumentError);
    expect(await repo.renameSpeaker('Rafaël', 'Rafaël'), 0);
  });
}
