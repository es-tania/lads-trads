import 'dart:io';

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
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
import 'package:lads_trad/widgets/ink_segmented.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Vérifie qu'aucun texte de bouton ne passe à la ligne sur un téléphone
/// étroit, avec les vraies polices de l'app (les tests utilisent sinon une
/// police de remplacement aux lettres carrées).

DocParagraph _p(String text, {bool h1 = false, bool list = false}) =>
    DocParagraph(text: text, isHeading1: h1, isListItem: list);

Future<void> _loadAppFonts() async {
  const families = {
    'InstrumentSans': ['InstrumentSans-400.ttf', 'InstrumentSans-500.ttf', 'InstrumentSans-600.ttf'],
    'Figtree': ['Figtree-400.ttf', 'Figtree-500.ttf', 'Figtree-600.ttf'],
    'JetBrainsMono': ['JetBrainsMono-400.ttf', 'JetBrainsMono-500.ttf'],
  };
  for (final MapEntry(key: family, value: files) in families.entries) {
    final loader = FontLoader(family);
    for (final file in files) {
      loader.addFont(rootBundle.load('assets/fonts/$file'));
    }
    await loader.load();
  }
}

/// Textes de boutons affichés sur plus d'une ligne.
List<String> _wrappedButtonTexts() {
  final buttons = find.byWidgetPredicate((w) => w is ButtonStyleButton || w is InkSegmented);
  final wrapped = <String>[];
  for (final e in find.descendant(of: buttons, matching: find.byType(RichText)).evaluate()) {
    final paragraph = e.renderObject! as RenderParagraph;
    final text = paragraph.text.toPlainText();
    if (text.trim().isEmpty) continue;
    final boxes = paragraph.getBoxesForSelection(TextSelection(baseOffset: 0, extentOffset: text.length));
    final lines = boxes.map((b) => b.top.round()).toSet().length;
    if (lines > 1 || paragraph.didExceedMaxLines) wrapped.add(text);
  }
  return wrapped;
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pumpAndSettle();
  }
}

void main() {
  sqfliteFfiInit();
  setUpAll(_loadAppFonts);

  late LibraryRepository library;
  late int storyId;
  late int choiceStoryId;

  Future<void> start(WidgetTester tester, {required double width, double textScale = 1}) async {
    tester.view.physicalSize = Size(width * 3, 800 * 3);
    tester.view.devicePixelRatio = 3;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    adminMode.value = true;
    addTearDown(() => adminMode.value = false);

    late Directory covers;
    late OverlaySettings settings;
    await tester.runAsync(() async {
      covers = await Directory.systemTemp.createTemp('lads_covers');
      final db = await openLibraryDatabase(
        factory: databaseFactoryFfi,
        path: inMemoryDatabasePath,
        singleInstance: false,
      );
      library = LibraryRepository(db, coversDir: covers);
      SharedPreferences.setMockInitialValues({});
      settings = OverlaySettings(await SharedPreferences.getInstance());
      final rafayel = (await library.characters()).first.id;
      final folder = await library.folderFor(rafayel, FolderType.memoria, rarity: 5);
      storyId = await library.saveStory(
        folderId: folder,
        title: 'Into The Canvas',
        parsed: parseStoryParagraphs(
          fr: [_p('ÉPISODE 1', h1: true), _p('Rafayel : Salut.'), _p('Il sourit.')],
          en: [_p('EPISODE 1', h1: true), _p('Rafayel : Hi.'), _p('He smiles.')],
        ),
      );
      choiceStoryId = await library.saveStory(
        folderId: folder,
        title: 'Blossoms',
        parsed: parseStoryParagraphs(
          fr: [
            _p('KINDLED', h1: true),
            _p('Choix:'),
            _p('Réussite !', list: true),
            _p('Rafayel : Bravo.'),
            _p('Échec…', list: true),
            _p('Rafayel : Dommage.'),
            _p('---'),
          ],
        ),
      );
    });
    addTearDown(() => tester.runAsync(() => covers.delete(recursive: true)));
    await tester.pumpWidget(Services(library: library, settings: settings, child: const LadsTradApp()));
    await _settle(tester);
  }

  NavigatorState navigator(WidgetTester tester) => tester.state<NavigatorState>(find.byType(Navigator).first);

  Future<void> open(WidgetTester tester, String route, [Object? argument]) async {
    navigator(tester).pushNamed(route, arguments: argument);
    await _settle(tester);
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder.first);
    await tester.pumpAndSettle();
    await tester.tap(finder.first);
    await _settle(tester);
  }

  Future<void> back(WidgetTester tester) async {
    navigator(tester).pop();
    await _settle(tester);
  }

  // Petit téléphone, très petit téléphone, et texte agrandi dans les
  // réglages d'Android.
  for (final (width, scale) in const [(360.0, 1.0), (320.0, 1.0), (360.0, 1.15), (360.0, 1.3), (411.0, 1.3)]) {
    testWidgets('aucun texte de bouton ne passe à la ligne ($width points, texte ×$scale)', (tester) async {
      await start(tester, width: width, textScale: scale);
      final found = <String, List<String>>{};
      void check(String where) {
        final wrapped = _wrappedButtonTexts();
        if (wrapped.isNotEmpty) found[where] = wrapped;
      }

      check('Bibliothèque');
      await tap(tester, find.text('Nouveau dossier'));
      check('Panneau « Nouveau dossier »');
      await back(tester);

      await open(tester, Routes.folder, (await tester.runAsync(() async => (await library.story(storyId))!.folderId))!);
      await tap(tester, find.byTooltip('Modifier le dossier'));
      check('Panneau « Modifier le dossier »');
      await back(tester);
      await back(tester);

      await open(tester, Routes.story, storyId);
      check("Écran d'une histoire");
      await back(tester);

      await open(tester, Routes.storyAdmin, storyId);
      check("Fiche d'une histoire");
      await tap(tester, find.widgetWithText(TextButton, 'Supprimer'));
      check('Confirmation « Supprimer l\'histoire »');
      await back(tester);
      await tap(tester, find.text('Exporter en .docx'));
      check('Panneau « Exporter »');
      await back(tester);
      await back(tester);

      await open(tester, Routes.import);
      check('Import');
      await back(tester);
      await open(tester, Routes.replaceContent, storyId);
      check('Remplacer le contenu');
      await back(tester);

      await open(tester, Routes.characters);
      check('Personnages');
      await tap(tester, find.text('Ajouter un personnage'));
      check('Dialogue « Ajouter un personnage »');
      await back(tester);
      await tap(tester, find.text('Rafayel'));
      check("Panneau « Image d'un personnage »");
      await back(tester);
      await back(tester);

      await open(tester, Routes.editor, storyId);
      check('Éditeur');
      await tap(tester, find.text('Salut.'));
      check("Panneau « Modifier la réplique »");
      await tap(tester, find.textContaining('Renommer «'));
      check('Dialogue « Renommer le personnage »');
      await back(tester);
      await tap(tester, find.byTooltip('Supprimer la réplique'));
      check('Confirmation « Supprimer la réplique »');
      await back(tester);
      await back(tester);
      await tap(tester, find.text('Ajouter une réplique'));
      check('Panneau « Nouvelle réplique »');
      await back(tester);
      await back(tester);

      await open(tester, Routes.editor, choiceStoryId);
      check('Éditeur avec un choix');
      await tap(tester, find.textContaining('Réussite'));
      check('Panneau « Branche »');
      await tap(tester, find.text('Supprimer la branche'));
      check('Confirmation « Supprimer la branche »');
      await back(tester);
      await back(tester);
      await tap(tester, find.text('Ajouter une branche'));
      check('Panneau « Nouvelle branche »');
      await back(tester);
      await back(tester);

      expect(found, isEmpty, reason: found.entries.map((e) => '${e.key} : ${e.value.join(', ')}').join('\n'));
    });
  }
}
