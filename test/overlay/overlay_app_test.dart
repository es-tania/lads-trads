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

  /// Clavier demandé (vrai) puis rendu au jeu (faux).
  final keyboardRequests = <bool>[];
  final saved = <(int, String, String?)>[];
  Object? saveError;

  /// Comme le vrai service quand rien ne répond : le Future ne finit jamais.
  var saveHangs = false;

  @override
  Future<void> setKeyboard(bool enabled) async => keyboardRequests.add(enabled);

  @override
  Future<String> saveLine(int lineId, {required String text, required String? speaker}) async {
    if (saveHangs) return Completer<String>().future;
    if (saveError != null) throw saveError!;
    saved.add((lineId, text, speaker));
    return speaker == null ? 'narration' : 'dialogue';
  }

  final renames = <(int, String, String)>[];

  @override
  Future<void> renameSpeaker(int storyId, {required String from, required String to}) async =>
      renames.add((storyId, from, to));

  @override
  Stream<Object?> get messages => controller.stream;

  @override
  Future<void> send(Object? message) async => sent.add(message);

  /// Nombre de redimensionnements qui échouent d'abord (service pas prêt).
  var failingResizes = 0;

  @override
  Future<void> resize(int width, int height, {required bool drag}) async {
    if (failingResizes > 0) {
      failingResizes--;
      throw StateError('service pas encore prêt');
    }
    resizes.add((width, height, drag));
  }

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

  /// Clavier simulé : recouvre [keyboardOverlap] points de la fenêtre tant
  /// qu'elle n'est pas montée au-dessus de [keyboardTop].
  bool keyboardVisible = false;
  double? keyboardTop;

  @override
  Future<({bool? visible, double overlap})> keyboard() async {
    final top = keyboardTop;
    if (!keyboardVisible || top == null) return (visible: keyboardVisible, overlap: 0.0);
    final bottom = at.dy + (resizes.isEmpty ? 0 : resizes.last.$2);
    return (visible: true, overlap: (bottom - top).clamp(0.0, double.infinity));
  }
}

PlayItem line(String text, [String? speaker, int? id]) =>
    PlayItem.line(PlayLine(kind: speaker == null ? 'narration' : 'dialogue', text: text, speaker: speaker, id: id));

final parts = [
  PlayPart(title: 'KINDLED', items: [
    line('Les couleurs sont prêtes.', 'Rafayel', 10),
    PlayItem.choice([
      const PlayOption(label: 'Réussite !', lines: [PlayLine(kind: 'dialogue', text: 'Pas mal.', speaker: 'Rafayel')]),
      const PlayOption(label: 'Échec…', lines: [PlayLine(kind: 'dialogue', text: 'Dommage.', speaker: 'Rafayel')]),
    ]),
    line('Il sourit.'),
  ]),
];

Map<String, Object?> load({int id = 1, bool admin = false, List<String> speakers = const ['Rafayel', 'Moi'], int? storyId = 7}) =>
    OverlayMessages.loadMessage(
      id: id,
      storyTitle: 'Into The Canvas',
      parts: parts,
      startPart: 0,
      opacity: 0.85,
      fontSize: 15,
      admin: admin,
      speakers: speakers,
      storyId: storyId,
    );

void main() {
  late FakeHost host;

  Future<void> start(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1122, 1500);
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
    final parsed = parseStoryParagraphs([p('KINDLED', h1: true), p('Choix:'), p('A', list: true), p('Rafayel : Oui.'), p('B', list: true), p('Rafayel : Non.'), p('---'), p('Il part.')]);
    final folder = await library.folderFor((await library.characters()).first.id, FolderType.memoria, rarity: 5);
    final id = await library.saveStory(folderId: folder, title: 'T', parsed: parsed);

    final play = await loadPlayParts(library, id);
    expect(play.single.title, 'Kindled');
    expect(play.single.items, hasLength(2));
    final choice = play.single.items.first;
    expect(choice.options!.map((o) => o.label), ['A', 'B']);
    expect(choice.options!.map((o) => o.lines.single.text), ['Oui.', 'Non.']);
    expect(play.single.items.last.line!.text, 'Il part.');
    final rows = await library.lines((await library.parts(id)).single.id);
    expect(play.single.items.last.line!.id, rows.last.id, reason: 'pour la modifier pendant la lecture');
    expect(choice.options!.first.lines.single.id, rows.firstWhere((r) => r.text == 'Oui.').id);
  });

  testWidgets('hors mode admin, pas de crayon', (tester) async {
    await start(tester);
    host.controller.add(load());
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Modifier la réplique'), findsNothing);
  });

  testWidgets('en mode admin, on corrige la réplique sans quitter la lecture', (tester) async {
    await start(tester);
    host.controller.add(load(admin: true));
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('Modifier la réplique'));
    await tester.pumpAndSettle();
    expect(host.keyboardRequests, [true], reason: 'la fenêtre reçoit le clavier');
    expect(find.text('Modifier · Rafayel'), findsOneWidget);
    expect(tester.widget<EditableText>(find.byType(EditableText)).controller.text, 'Les couleurs sont prêtes.');
    expect(find.bySemanticsLabel('Réplique suivante'), findsOneWidget);
    expect(
      tester.getSemantics(find.bySemanticsLabel('Réplique suivante')).flagsCollection.isEnabled,
      isNot(true),
      reason: 'pas de navigation pendant la modification',
    );

    await tester.enterText(find.byType(EditableText), '  Les couleurs sont prêtes, vas-y.  ');
    await tester.pump();
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    expect(host.saved, [(10, 'Les couleurs sont prêtes, vas-y.', 'Rafayel')]);
    expect(host.keyboardRequests, [true, false], reason: 'le clavier est rendu au jeu');
    expect(find.text('Les couleurs sont prêtes, vas-y.'), findsOneWidget);
    expect(find.text('Kindled · L.001/003'), findsOneWidget, reason: 'même position de lecture');
  });

  testWidgets('pendant une modification, la fenêtre monte au-dessus du clavier puis revient', (tester) async {
    await start(tester);
    host.controller.add(load(admin: true));
    await tester.pumpAndSettle();
    await host.move(8, 600);
    host.moves.clear();

    await tester.tap(find.bySemanticsLabel('Modifier la réplique'));
    await tester.pumpAndSettle();
    final height = host.resizes.last.$2;
    host
      ..keyboardVisible = true
      ..keyboardTop = 500;
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(host.at, Offset(8, 500 - height - 8.0), reason: 'juste au-dessus du clavier');

    // Le clavier se ferme (bouton retour) : la fenêtre revient à sa place.
    host.keyboardVisible = false;
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(host.at, const Offset(8, 600));

    // Il se rouvre, puis on enregistre : la fenêtre revient aussi.
    host.keyboardVisible = true;
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(host.at.dy, lessThan(600));
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();
    expect(host.at, const Offset(8, 600));

    // Hors modification, le clavier n'est plus suivi.
    host.moves.clear();
    await tester.pump(const Duration(seconds: 1));
    expect(host.moves, isEmpty);
  });

  testWidgets('une fenêtre déjà au-dessus du clavier ne bouge pas', (tester) async {
    await start(tester);
    host.controller.add(load(admin: true));
    await tester.pumpAndSettle();
    await host.move(8, 40);
    host.moves.clear();

    await tester.tap(find.bySemanticsLabel('Modifier la réplique'));
    await tester.pumpAndSettle();
    host
      ..keyboardVisible = true
      ..keyboardTop = 500;
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();
    expect(host.moves, isEmpty);
  });

  testWidgets('Annuler ne change rien ; une erreur reste affichée', (tester) async {
    await start(tester);
    host.controller.add(load(admin: true));
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('Modifier la réplique'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText), 'Autre chose.');
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();
    expect(host.saved, isEmpty);
    expect(host.keyboardRequests, [true, false]);
    expect(find.text('Les couleurs sont prêtes.'), findsOneWidget);

    host.saveError = StateError('base indisponible');
    await tester.tap(find.bySemanticsLabel('Modifier la réplique'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText), 'Autre chose.');
    await tester.pump();
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Enregistrement impossible'), findsOneWidget);
    expect(find.byType(EditableText), findsOneWidget, reason: 'le texte saisi n\'est pas perdu');
  });

  testWidgets('un enregistrement qui ne répond pas ne bloque pas la fenêtre', (tester) async {
    await start(tester);
    host.controller.add(load(admin: true));
    await tester.pumpAndSettle();
    host.saveHangs = true;

    await tester.tap(find.bySemanticsLabel('Modifier la réplique'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText), 'Autre chose.');
    await tester.pump();
    await tester.tap(find.text('Enregistrer'));
    await tester.pump();
    expect(find.text('Enregistrement…'), findsOneWidget);

    await tester.pump(const Duration(seconds: 9));
    expect(find.text("L'enregistrement ne répond pas. Réessaie."), findsOneWidget);
    expect(find.text('Enregistrer'), findsOneWidget, reason: 'on peut réessayer');
  });

  testWidgets('en mode admin, on corrige aussi qui parle', (tester) async {
    await start(tester);
    host.controller.add(load(admin: true));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Modifier la réplique'));
    await tester.pumpAndSettle();

    // La liste est repliée : seul le personnage actuel est visible.
    expect(find.text('Moi'), findsNothing);
    expect(find.text('+ Autre'), findsNothing);
    await tester.tap(find.bySemanticsLabel('Changer de personnage'));
    await tester.pumpAndSettle();

    // Un personnage existant : la liste se replie après le choix.
    await tester.tap(find.text('Moi'));
    await tester.pumpAndSettle();
    expect(find.text('Modifier · Moi'), findsOneWidget);
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();
    expect(host.saved.last, (10, 'Les couleurs sont prêtes.', 'Moi'));
    expect(find.text('Moi'), findsOneWidget, reason: 'la fenêtre affiche le nouveau personnage');

    // Un nouveau personnage, créé depuis la fenêtre.
    await tester.tap(find.bySemanticsLabel('Modifier la réplique'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Changer de personnage'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('+ Autre'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText).first, 'Zayne');
    await tester.pump();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('Modifier · Zayne'), findsOneWidget);
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();
    expect(host.saved.last, (10, 'Les couleurs sont prêtes.', 'Zayne'));
    expect(find.text('Zayne'), findsOneWidget);

    // Narration : plus de personnage.
    await tester.tap(find.bySemanticsLabel('Modifier la réplique'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Changer de personnage'));
    await tester.pumpAndSettle();
    expect(find.text('Zayne'), findsNWidgets(1), reason: 'le nouveau personnage reste proposé');
    // Replier sans changer, puis déplier à nouveau.
    await tester.tap(find.bySemanticsLabel('Replier la liste'));
    await tester.pumpAndSettle();
    expect(find.text('Narration'), findsNothing);
    await tester.tap(find.bySemanticsLabel('Changer de personnage'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Narration'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();
    expect(host.saved.last, (10, 'Les couleurs sont prêtes.', null));
    expect(find.text('Zayne'), findsNothing);
  });

  testWidgets("au premier lancement, la fenêtre redemande sa taille si le service n'est pas prêt", (tester) async {
    tester.view.physicalSize = const Size(1122, 1500);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    host = FakeHost()..failingResizes = 2;
    await tester.pumpWidget(OverlayApp(host: host));
    host.controller.add(load());
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();
    expect(host.failingResizes, 0, reason: "les deux échecs ont été suivis d'un nouvel essai");
    expect(host.resizes, isNotEmpty);
    expect(host.resizes.last.$1, 374, reason: "largeur de l'écran moins les marges");
  });

  test('la fenêtre est créée en pixels, pas en points', () {
    final g = overlayStartGeometry(screenWidth: 384, pixelRatio: 2.8125);
    expect(g, (width: 1035, height: 338, x: 23, y: 338));
  });

  testWidgets("dans la fenêtre, on met un passage en italique", (tester) async {
    await start(tester);
    host.controller.add(load(admin: true));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Modifier la réplique'));
    await tester.pumpAndSettle();
    final field = tester.widget<EditableText>(find.byType(EditableText).first);
    field.controller.selection = const TextSelection(baseOffset: 4, extentOffset: 12);
    await tester.pump();
    await tester.tap(find.byTooltip('Italique'));
    await tester.pump();
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();
    expect(host.saved.last.$2, 'Les <i>couleurs</i> sont prêtes.');
    expect(find.text('Les couleurs sont prêtes.', findRichText: true), findsOneWidget);
  });

  testWidgets('un nom de personnage très long est coupé, sans déborder', (tester) async {
    await start(tester);
    const long = 'Petit garçon (audio uniquement, au loin dans la rue)';
    host.controller.add(load(admin: true, speakers: ['Rafayel', long]));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Modifier la réplique'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Changer de personnage'));
    await tester.pumpAndSettle();

    final name = tester.widget<Text>(find.text(long));
    expect(name.overflow, TextOverflow.ellipsis);
    expect(tester.getSize(find.text(long)).width, lessThanOrEqualTo(170));
    await tester.tap(find.text(long));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'pas de « right overflowed »');
  });

  testWidgets("dans la fenêtre, on corrige le nom d'un personnage dans toute l'histoire", (tester) async {
    await start(tester);
    host.controller.add(load(admin: true));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Modifier la réplique'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Changer de personnage'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('✎ Renommer'));
    await tester.pumpAndSettle();
    expect(tester.widget<EditableText>(find.byType(EditableText).first).controller.text, 'Rafayel');

    await tester.enterText(find.byType(EditableText).first, 'Rafaël');
    await tester.pump();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(host.renames, [(7, 'Rafayel', 'Rafaël')]);
    expect(find.text('Modifier · Rafaël'), findsOneWidget);

    // Même sans enregistrer la réplique, le nom est corrigé partout dans la lecture.
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();
    expect(find.text('Rafaël'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Réplique suivante'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Réussite !'));
    await tester.pumpAndSettle();
    expect(find.text('Rafaël'), findsOneWidget, reason: 'aussi dans les branches');
  });
}
