import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import 'app.dart';
import 'data/database.dart';
import 'data/library_repository.dart';
import 'data/overlay_settings.dart';
import 'data/services.dart';
import 'theme/ink.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(InkTheme.systemUi);
  _registerFontLicenses();

  final docs = await getApplicationDocumentsDirectory();
  final db = await openLibraryDatabase(factory: databaseFactory, path: p.join(docs.path, 'lads_trad.db'));
  final library = LibraryRepository(db, coversDir: Directory(p.join(docs.path, 'covers')));
  final settings = OverlaySettings(await SharedPreferences.getInstance());

  runApp(Services(library: library, settings: settings, child: const LadsTradApp()));
}

/// Les trois polices sont sous licence SIL OFL : on les déclare dans
/// l'écran des licences de l'app.
void _registerFontLicenses() {
  const fonts = {
    'Instrument Sans': 'OFL-instrumentsans.txt',
    'Figtree': 'OFL-figtree.txt',
    'JetBrains Mono': 'OFL-jetbrainsmono.txt',
  };
  LicenseRegistry.addLicense(() async* {
    for (final MapEntry(key: name, value: file) in fonts.entries) {
      final text = await rootBundle.loadString('assets/fonts/$file');
      yield LicenseEntryWithLineBreaks([name], text);
    }
  });
}
