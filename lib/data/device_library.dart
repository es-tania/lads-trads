import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'database.dart';
import 'library_repository.dart';

/// Bibliothèque stockée sur le téléphone.
///
/// Ouverte par l'app et, pour enregistrer une modification faite pendant la
/// lecture, par la fenêtre flottante (son propre moteur Flutter, dans le
/// même processus).
Future<LibraryRepository> openDeviceLibrary() async {
  final docs = await getApplicationDocumentsDirectory();
  final db = await openLibraryDatabase(factory: databaseFactory, path: p.join(docs.path, 'lads_trad.db'));
  return LibraryRepository(db, coversDir: Directory(p.join(docs.path, 'covers')));
}
