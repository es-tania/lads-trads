import 'dart:io';

import 'package:flutter/widgets.dart';
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
    expect(find.text('Importer'), findsNothing);
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
    expect(find.text('Importer'), findsOneWidget);
    expect(find.text('Nouveau dossier'), findsOneWidget);

    await tester.tap(find.text('Importer'));
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
}
