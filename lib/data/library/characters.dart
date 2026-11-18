part of '../library_repository.dart';

/// Personnages : les onglets de la bibliothèque, avec leur image.
mixin _Characters on _LibraryBase {
  Future<List<Character>> characters() async {
    final rows = await _db.query('characters', orderBy: 'position, id');
    return [for (final r in rows) _character(r)];
  }

  /// Ajoute un personnage à la fin des onglets.
  ///
  /// Lève [DuplicateCharacterException] si le nom existe déjà (sans tenir
  /// compte des majuscules) et [ArgumentError] s'il est vide.
  Future<int> addCharacter(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw ArgumentError.value(name, 'name', 'Nom vide');
    final id = await _db.transaction((txn) async {
      // Comparaison en Dart : NOCASE de SQLite ignore les accents.
      final names = await txn.query('characters', columns: ['name']);
      if (names.any((r) => (r['name']! as String).toLowerCase() == trimmed.toLowerCase())) {
        throw DuplicateCharacterException(trimmed);
      }
      final next = await txn.rawQuery('SELECT COALESCE(MAX(position) + 1, 0) AS next FROM characters');
      return txn.insert('characters', {'name': trimmed, 'position': next.single['next']! as int});
    });
    notifyListeners();
    return id;
  }

  /// Copie l'image dans le stockage de l'app et l'associe au personnage.
  ///
  /// Le recadrage repart de [crop], ou du cadrage par défaut.
  Future<void> setCharacterImage(int characterId, Uint8List bytes, String fileName, {ImageCrop? crop}) async {
    final path = await _images.save(bytes, fileName, prefix: 'character_$characterId');
    await _replaceImage('characters', characterId,
        column: 'image_path', path: path, crop: _cropColumns(crop, _characterCrop));
    notifyListeners();
  }

  /// Enregistre le cercle choisi sur l'image du personnage.
  Future<void> setImageCrop(int characterId, ImageCrop crop) async {
    await _db.update('characters', _cropColumns(crop, _characterCrop), where: 'id = ?', whereArgs: [characterId]);
    notifyListeners();
  }
}
