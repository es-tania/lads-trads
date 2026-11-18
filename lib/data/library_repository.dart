import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../docx/story_model.dart';
import 'image_files.dart';
import 'library_exceptions.dart';
import 'models.dart';

export 'library_exceptions.dart';

part 'library/characters.dart';
part 'library/folders.dart';
part 'library/lines.dart';
part 'library/rows.dart';
part 'library/stories.dart';

/// Accès à la bibliothèque locale.
///
/// Chaque partie de la bibliothèque a son fichier dans `library/` :
/// personnages, dossiers, histoires et lignes. Le dépôt prévient ses
/// auditeurs à chaque modification, pour que les écrans se rechargent.
/// À l'étape 6, la même interface parlera à Supabase.
class LibraryRepository extends _LibraryBase with _Characters, _Folders, _Stories, _Lines {
  LibraryRepository(Database db, {required Directory coversDir}) : super(db, ImageFiles(coversDir));

  /// Dossier où sont copiées les couvertures importées et les images des
  /// personnages.
  Directory get coversDir => _images.dir;

  /// La base a été modifiée ailleurs (par la fenêtre flottante) : les
  /// écrans rechargent leurs données.
  void refresh() => notifyListeners();
}

/// Ce que partagent les parties du dépôt : la base et les fichiers images.
abstract class _LibraryBase extends ChangeNotifier {
  _LibraryBase(this._db, this._images);

  final Database _db;
  final ImageFiles _images;

  /// Remplace l'image de la ligne [id] de [table] (colonne [column]) par
  /// [path], avec son cadrage [crop], puis efface l'ancien fichier.
  /// [path] `null` retire l'image.
  Future<void> _replaceImage(
    String table,
    int id, {
    required String column,
    required String? path,
    required _Row crop,
  }) async {
    final old = await _db.query(table, columns: [column], where: 'id = ?', whereArgs: [id]);
    await _db.update(table, {column: path, ...crop}, where: 'id = ?', whereArgs: [id]);
    await _images.delete(old.isEmpty ? null : old.single[column] as String?);
  }
}
