import 'dart:io';
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lads_trad/app.dart';
import 'package:lads_trad/data/database.dart';
import 'package:lads_trad/data/library_repository.dart';
import 'package:lads_trad/data/models.dart';
import 'package:lads_trad/data/overlay_settings.dart';
import 'package:lads_trad/data/services.dart';
import 'package:lads_trad/docx/docx_reader.dart';
import 'package:lads_trad/docx/story_parser.dart';
import 'package:lads_trad/state/admin_mode.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Écran de téléphone : 390 × 844 points, comme la maquette.
void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

DocParagraph _p(String text, {bool h1 = false}) => DocParagraph(text: text, isHeading1: h1, isListItem: false);

/// La base tourne dans un vrai fil d'exécution : on la laisse travailler
/// hors de l'horloge simulée des tests, puis on redessine.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pumpAndSettle();
  }
}

/// Comme [_settle], jusqu'à ce que [finder] trouve quelque chose (images).
Future<void> _settleUntil(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 20 && finder.evaluate().isEmpty; i++) {
    await _settle(tester);
  }
}

void main() {
  sqfliteFfiInit();
  late LibraryRepository library;
  late OverlaySettings settings;
  late Directory covers;

  Future<void> start(WidgetTester tester) async {
    _phone(tester);
    await tester.runAsync(() async {
      covers = await Directory.systemTemp.createTemp('lads_covers');
      final db = await openLibraryDatabase(factory: databaseFactoryFfi, path: inMemoryDatabasePath, singleInstance: false);
      library = LibraryRepository(db, coversDir: covers);
      SharedPreferences.setMockInitialValues({});
      settings = OverlaySettings(await SharedPreferences.getInstance());

      final rafayel = (await library.characters()).first.id;
      final folder = await library.folderFor(rafayel, FolderType.memoria, rarity: 5);
      await library.saveStory(
        folderId: folder,
        title: 'Into The Canvas',
        parsed: parseStoryParagraphs(
          fr: [_p('ÉPISODE 1', h1: true), _p('Rafayel : Salut.'), _p('KINDLED', h1: true), _p('Il sourit.')],
          en: [_p('EPISODE 1', h1: true), _p('Rafayel : Hi.'), _p('KINDLED', h1: true), _p('He smiles.')],
        ),
      );
    });
    addTearDown(() => tester.runAsync(() => covers.delete(recursive: true)));
    await tester.pumpWidget(Services(library: library, settings: settings, child: const LadsTradApp()));
    await _settle(tester);
  }

  setUp(() => adminMode.value = false);

  testWidgets('La bibliothèque mène à un dossier puis à une histoire', (tester) async {
    await start(tester);
    expect(find.text('Bibliothèque'), findsOneWidget);
    expect(find.byTooltip('Importer'), findsNothing);
    expect(find.text('Ajoutées récemment'), findsOneWidget);

    await tester.tap(find.text('Memoria 5★'));
    await _settle(tester);
    expect(find.text('1 histoire'), findsOneWidget);

    await tester.tap(find.text('Into The Canvas'));
    await _settle(tester);
    expect(find.text('Épisode 1'), findsOneWidget);
    expect(find.text('Kindled'), findsOneWidget);
    expect(find.text('Rafayel · Memoria 5★'), findsOneWidget);
    expect(find.text('Modifier'), findsNothing);
  });

  testWidgets('Un autre personnage sans histoire affiche un message', (tester) async {
    await start(tester);
    await tester.tap(find.text('Xavier'));
    await _settle(tester);
    expect(find.textContaining('Aucune histoire traduite pour Xavier'), findsOneWidget);
  });

  testWidgets('Un appui long sur « Bibliothèque » affiche les boutons admin', (tester) async {
    await start(tester);
    await tester.longPress(find.text('Bibliothèque'));
    await _settle(tester);
    expect(find.byTooltip('Importer'), findsOneWidget);
    expect(find.text('Nouveau dossier'), findsOneWidget);

    await tester.tap(find.byTooltip('Importer'));
    await _settle(tester);
    expect(find.text('Importer une histoire'), findsOneWidget);
    expect(find.text('Rafayel'), findsOneWidget, reason: 'personnage choisi dans la bibliothèque');
  });

  testWidgets('La recherche trouve une histoire par son titre', (tester) async {
    await start(tester);
    await tester.tap(find.byTooltip('Rechercher'));
    await _settle(tester);
    await tester.enterText(find.byType(EditableText), 'canvas');
    await _settle(tester);
    expect(find.text('Into The Canvas'), findsOneWidget);
  });

  testWidgets('Les réglages de la fenêtre sont enregistrés', (tester) async {
    await start(tester);
    await tester.tap(find.text('Into The Canvas'));
    await _settle(tester);
    await tester.tap(find.bySemanticsLabel('Grand'));
    await _settle(tester);
    expect(settings.textSize, OverlayTextSize.large);
  });

  Future<void> openCharacters(WidgetTester tester) async {
    await tester.longPress(find.text('Bibliothèque'));
    await _settle(tester);
    await tester.tap(find.text('Modifier les personnages'));
    await _settle(tester);
  }

  testWidgets('Le lien « Modifier les personnages » est réservé au mode admin', (tester) async {
    await start(tester);
    expect(find.text('Modifier les personnages'), findsNothing);
    await openCharacters(tester);
    expect(find.text('Touche un personnage pour changer son image'), findsOneWidget);
    expect(find.text('Ajouter une image'), findsNWidgets(5));
  });

  testWidgets('On ajoute un personnage, qui apparaît dans la bibliothèque', (tester) async {
    await start(tester);
    await openCharacters(tester);
    await tester.tap(find.text('Ajouter un personnage'));
    await _settle(tester);
    await tester.enterText(find.byType(EditableText), 'Valko');
    await tester.pump();
    await tester.tap(find.text('Ajouter'));
    await _settle(tester);
    expect(find.text('Valko'), findsOneWidget);
    expect(find.text('Ajouter une image'), findsNWidgets(6));

    // Un doublon est refusé dans la fenêtre.
    await tester.tap(find.text('Ajouter un personnage'));
    await _settle(tester);
    await tester.enterText(find.byType(EditableText), 'valko');
    await tester.pump();
    await tester.tap(find.text('Ajouter'));
    await _settle(tester);
    expect(find.text('« valko » existe déjà.'), findsOneWidget);
    await tester.tap(find.text('Annuler'));
    await _settle(tester);

    await tester.tap(find.byTooltip('Retour'));
    await _settle(tester);
    expect(find.text('Valko'), findsOneWidget);
    expect(find.text('V'), findsOneWidget, reason: 'initiale sans image');
  });

  testWidgets("Sans image, le panneau propose seulement d'en choisir une", (tester) async {
    await start(tester);
    await openCharacters(tester);
    await tester.tap(find.text('Rafayel'));
    await _settle(tester);
    expect(find.text('Image de Rafayel'), findsOneWidget);
    expect(find.text("Aucune image pour l'instant"), findsOneWidget);
    expect(find.text('Choisir une image'), findsOneWidget);
    final save = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Enregistrer'));
    expect(save.onPressed, isNull);

    await tester.tap(find.text('Annuler'));
    await _settle(tester);
    expect(find.text('Image de Rafayel'), findsNothing);
  });

  testWidgets('Glisser le cercle puis enregistrer change le recadrage', (tester) async {
    await start(tester);
    await tester.runAsync(() async {
      final recorder = ui.PictureRecorder();
      Canvas(recorder).drawRect(const Rect.fromLTWH(0, 0, 300, 400), Paint()..color = const Color(0xFF336699));
      final image = await recorder.endRecording().toImage(300, 400);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      final zayne = (await library.characters())[2];
      await library.setCharacterImage(zayne.id, png!.buffer.asUint8List(), 'zayne.png');
    });
    await openCharacters(tester);
    expect(find.text('Changer'), findsOneWidget);

    await tester.tap(find.text('Zayne'));
    // Lecture et décodage de l'image : un peu plus long que la base.
    await _settleUntil(tester, find.text('Glisse le cercle sur le visage'));
    expect(find.text('Glisse le cercle sur le visage'), findsOneWidget);

    // Image 300 × 400 : cercle par défaut au centre, on le remonte.
    await tester.drag(find.bySemanticsLabel('Déplacer le cadrage'), const Offset(0, -200));
    await _settle(tester);
    await tester.tap(find.text('Enregistrer'));
    await _settle(tester);

    expect(find.text('Image de Zayne'), findsNothing);
    final crop = (await tester.runAsync(() => library.characters()))![2].crop!;
    expect(crop.x, closeTo(0.5, 1e-9));
    expect(crop.d, 0.8);
    // Rayon : 0,8 × 300 / 2 = 120 px sur 400 de haut : le cercle bute en haut.
    expect(crop.y, closeTo(120 / 400, 1e-9));
  });

  Future<void> enterAdmin(WidgetTester tester) async {
    await tester.longPress(find.text('Bibliothèque'));
    await _settle(tester);
  }

  testWidgets('On crée un dossier, on le renomme puis on le supprime', (tester) async {
    await start(tester);
    await enterAdmin(tester);
    await tester.tap(find.text('Nouveau dossier'));
    await _settle(tester);
    expect(find.text('Créer le dossier'), findsOneWidget);
    expect(find.text('Rareté'), findsOneWidget);

    // « Memoria 5★ » existe déjà pour Rafayel.
    await tester.tap(find.text('Créer le dossier'));
    await _settle(tester);
    expect(find.textContaining('existe déjà'), findsOneWidget);

    await tester.tap(find.text('Myths'));
    await tester.pump();
    expect(find.text('Rareté'), findsNothing);
    await tester.tap(find.text('Créer le dossier'));
    await _settle(tester);
    expect(find.text('Ce dossier est vide.'), findsOneWidget);
    expect(find.text('Myths'), findsOneWidget);

    await tester.tap(find.byTooltip('Modifier le dossier'));
    await _settle(tester);
    expect(find.text('Modifier le dossier'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'Myths'), 'Mythes');
    await tester.pump();
    await tester.tap(find.text('Enregistrer'));
    await _settle(tester);
    expect(find.text('Mythes'), findsOneWidget);

    await tester.tap(find.byTooltip('Modifier le dossier'));
    await _settle(tester);
    await tester.tap(find.text('Supprimer le dossier'));
    await _settle(tester);
    await tester.tap(find.text('Supprimer'));
    await _settle(tester);
    expect(find.text('Bibliothèque'), findsOneWidget);
    expect(find.text('Mythes'), findsNothing);
  });

  testWidgets('Un dossier qui contient des histoires ne se supprime pas', (tester) async {
    await start(tester);
    await enterAdmin(tester);
    await tester.tap(find.text('Memoria 5★'));
    await _settle(tester);
    await tester.tap(find.byTooltip('Modifier le dossier'));
    await _settle(tester);
    await tester.tap(find.text('Supprimer le dossier'));
    await _settle(tester);
    expect(find.textContaining('contient 1 histoire'), findsOneWidget);
  });

  testWidgets("La fiche change le titre et déplace l'histoire chez un autre personnage", (tester) async {
    await start(tester);
    await enterAdmin(tester);
    await tester.tap(find.text('Into The Canvas'));
    await _settle(tester);
    await tester.tap(find.text('Modifier'));
    await _settle(tester);
    expect(find.text("Fiche de l'histoire"), findsOneWidget);
    expect(find.text('2 parties · 2'), findsOneWidget);
    expect(find.text('Type Memoria, repris du dossier'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Enregistrer')).onPressed, isNull);

    await tester.enterText(find.widgetWithText(TextField, 'Into The Canvas'), 'Dans la toile');
    await tester.pump();
    await tester.tap(find.text('Rafayel'));
    await _settle(tester);
    await tester.tap(find.text('Xavier').last);
    await _settle(tester);
    expect(find.text('Memoria 5★ (nouveau)'), findsOneWidget, reason: 'même type, à créer chez Xavier');

    await tester.tap(find.text('Enregistrer'));
    await _settle(tester);
    expect(find.text('Dans la toile'), findsOneWidget);
    expect(find.text('Xavier · Memoria 5★'), findsOneWidget);
  });

  testWidgets('« Remplacer par un .docx » garde le classement', (tester) async {
    await start(tester);
    await enterAdmin(tester);
    await tester.tap(find.text('Into The Canvas'));
    await _settle(tester);
    await tester.tap(find.text('Modifier'));
    await _settle(tester);
    await tester.tap(find.text('Remplacer par un .docx'));
    await _settle(tester);
    expect(find.text('Remplacer le contenu'), findsOneWidget);
    expect(find.text('Couverture'), findsNothing);
    expect(find.text('Classement'), findsNothing);
    expect(find.textContaining('Le titre, le dossier et la couverture sont gardés'), findsOneWidget);
  });
}
