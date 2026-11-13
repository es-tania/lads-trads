import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lads_trad/data/database.dart';
import 'package:lads_trad/data/library_repository.dart';
import 'package:lads_trad/data/models.dart';
import 'package:lads_trad/docx/docx_reader.dart';
import 'package:lads_trad/docx/story_parser.dart';
import 'package:lads_trad/overlay/overlay_app.dart';
import 'package:lads_trad/overlay/overlay_host.dart';
import 'package:lads_trad/overlay/overlay_launcher.dart';
import 'package:lads_trad/overlay/overlay_messages.dart';
import 'package:lads_trad/overlay/playback.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Faux système : note ce que la fenêtre demande.
class FakeHost implements OverlayHost {
  final controller = StreamController<Object?>.broadcast();
  final sent = <Object?>[];
  final resizes = <(int, int, bool)>[];
  final moves = <(double, double)>[];
  Rect? dragHandle;
  var dragHandleCalls = 0;

  @override
  Future<void> setDragHandle(Rect area) async {
    dragHandle = area;
    dragHandleCalls++;
  }

  @override
  Stream<Object?> get messages => controller.stream;

  @override
  Future<void> send(Object? message) async => sent.add(message);

  @override
  Future<void> resize(int width, int height, {required bool drag}) async => resizes.add((width, height, drag));

  /// Position réelle de la fenêtre, mise à jour par [move].
  Offset at = const Offset(8, 120);

  @override
  Future<void> move(double x, double y) async {
    moves.add((x, y));
    at = Offset(x, y);
  }

  @override
  Future<({double x, double y})?> position() async => (x: at.dx, y: at.dy);

  @override
  Future<({double width, double height})?> screenSize() async => (width: 390.0, height: 844.0);
}

PlayItem line(String text, [String? speaker]) =>
    PlayItem.line(PlayLine(kind: speaker == null ? 'narration' : 'dialogue', text: text, speaker: speaker));

final parts = [
  PlayPart(title: 'KINDLED', items: [
    line('Les couleurs sont prêtes.', 'Rafayel'),
    PlayItem.choice([
      const PlayOption(label: 'Réussite !', lines: [PlayLine(kind: 'dialogue', text: 'Pas mal.', speaker: 'Rafayel')]),
      const PlayOption(label: 'Échec…', lines: [PlayLine(kind: 'dialogue', text: 'Dommage.', speaker: 'Rafayel')]),
    ]),
    line('Il sourit.'),
  ]),
];

Map<String, Object?> load({int id = 1}) => OverlayMessages.loadMessage(
      id: id,
      storyTitle: 'Into The Canvas',
      parts: parts,
      startPart: 0,
      opacity: 0.85,
      fontSize: 15,
    );

void main() {
  late FakeHost host;

  Future<void> start(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1122, 600);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    host = FakeHost();
    await tester.pumpWidget(OverlayApp(host: host));
    await tester.pumpAndSettle();
  }

  testWidgets('prévient l\'app qu\'elle est prête, puis affiche l\'histoire reçue', (tester) async {
    await start(tester);
    expect(host.sent, [OverlayMessages.readyMessage()]);
    expect(find.text('Chargement de la traduction…'), findsOneWidget);

    host.controller.add(load());
    await tester.pumpAndSettle();
    expect(find.text('Les couleurs sont prêtes.'), findsOneWidget);
    expect(find.text('Rafayel'), findsOneWidget);
    expect(find.text('Kindled · L.001/003'), findsOneWidget);
    // La fenêtre prend la largeur de l'écran moins les marges, et la hauteur du contenu.
    expect(host.resizes.last.$1, 374);
    expect(host.resizes.last.$3, isFalse);
  });

  testWidgets('› ‹ et choix', (tester) async {
    await start(tester);
    host.controller.add(load());
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('Réplique suivante'));
    await tester.pumpAndSettle();
    expect(find.text('Quel choix as-tu fait ?'), findsOneWidget);

    await tester.tap(find.text('Échec…'));
    await tester.pumpAndSettle();
    expect(find.text('Dommage.'), findsOneWidget);
    expect(find.text('branche B'), findsOneWidget);

    await tester.tap(find.text('Changer de branche'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Réussite !'));
    await tester.pumpAndSettle();
    expect(find.text('Pas mal.'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Réplique suivante'));
    await tester.pumpAndSettle();
    expect(find.text('Il sourit.'), findsOneWidget);
  });

  testWidgets('« — » réduit en bulle déplaçable ; la bulle rouvre la fenêtre', (tester) async {
    await start(tester);
    host.controller.add(load());
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('Réduire'));
    await tester.pumpAndSettle();
    expect(host.resizes.last, (64, 56, true), reason: 'bulle : déplacement natif, cible × pour fermer');
    expect(host.moves.last, (390 - 64.0, 120.0), reason: 'collée au bord droit, à la hauteur de la fenêtre');
    expect(find.text('FR'), findsOneWidget);

    await tester.tap(find.text('FR'));
    await tester.pumpAndSettle();
    expect(host.resizes.last.$1, 374);
    expect(host.resizes.last.$3, isFalse, reason: 'la fenêtre ne se ferme pas en la glissant');
    expect(host.moves.last, (8.0, 120.0));
    expect(find.text('Les couleurs sont prêtes.'), findsOneWidget);
  });

  testWidgets('la zone de la poignée est confiée au système, et seulement elle', (tester) async {
    await start(tester);
    host.controller.add(load());
    await tester.pumpAndSettle();

    final area = host.dragHandle!;
    final grip = tester.getRect(find.bySemanticsLabel('Déplacer la fenêtre'));
    expect(area.contains(grip.center), isTrue, reason: 'la poignée dessinée est dans la zone');
    final previous = tester.getRect(find.bySemanticsLabel('Réplique précédente'));
    final minimize = tester.getRect(find.bySemanticsLabel('Réduire'));
    expect(area.overlaps(previous), isFalse, reason: '‹ reste un bouton');
    expect(area.overlaps(minimize), isFalse, reason: '« — » reste un bouton');

    // Le service système est recréé à chaque ouverture : chaque nouvelle
    // histoire envoyée redéclare la poignée.
    final before = host.dragHandleCalls;
    host.controller.add(load(id: 2));
    await tester.pumpAndSettle();
    expect(host.dragHandleCalls, greaterThan(before));
  });

  testWidgets('un message déjà reçu n\'est pas rejoué', (tester) async {
    await start(tester);
    host.controller.add(load());
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Réplique suivante'));
    await tester.pumpAndSettle();

    host.controller.add(load());
    await tester.pumpAndSettle();
    expect(find.text('Quel choix as-tu fait ?'), findsOneWidget, reason: 'même id : on reste où on était');

    host.controller.add(load(id: 2));
    await tester.pumpAndSettle();
    expect(find.text('Les couleurs sont prêtes.'), findsOneWidget);
  });

  test('les lignes en base deviennent des parties à dérouler', () async {
    sqfliteFfiInit();
    final covers = await Directory.systemTemp.createTemp('lads_covers');
    addTearDown(() => covers.delete(recursive: true));
    final db = await openLibraryDatabase(factory: databaseFactoryFfi, path: inMemoryDatabasePath, singleInstance: false);
    final library = LibraryRepository(db, coversDir: covers);
    DocParagraph p(String t, {bool h1 = false, bool list = false}) => DocParagraph(text: t, isHeading1: h1, isListItem: list);
    final parsed = parseStoryParagraphs(
      fr: [p('KINDLED', h1: true), p('Choix:'), p('A', list: true), p('Rafayel : Oui.'), p('B', list: true), p('Rafayel : Non.'), p('---'), p('Il part.')],
      en: [p('KINDLED', h1: true), p('Choices :'), p('01. A'), p('Rafayel : Yes.'), p('02. B'), p('Rafayel : No.'), p('---'), p('He leaves.')],
    );
    final folder = await library.folderFor((await library.characters()).first.id, FolderType.memoria, rarity: 5);
    final id = await library.saveStory(folderId: folder, title: 'T', parsed: parsed);

    final play = await loadPlayParts(library, id);
    expect(play.single.title, 'Kindled');
    expect(play.single.items, hasLength(2));
    final choice = play.single.items.first;
    expect(choice.options!.map((o) => o.label), ['A', 'B']);
    expect(choice.options!.map((o) => o.lines.single.text), ['Oui.', 'Non.']);
    expect(play.single.items.last.line!.text, 'Il part.');
  });
}
