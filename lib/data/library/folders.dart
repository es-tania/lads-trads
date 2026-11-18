part of '../library_repository.dart';

/// Dossiers d'un personnage (Memoria 5★, Myths…).
mixin _Folders on _LibraryBase {
  /// Dossiers d'un personnage, avec leur nombre d'histoires et trois couvertures.
  Future<List<Folder>> folders(int characterId) async {
    final rows = await _db.rawQuery('''
      SELECT f.*, COUNT(s.id) AS story_count
      FROM folders f LEFT JOIN stories s ON s.folder_id = f.id
      WHERE f.character_id = ?
      GROUP BY f.id
      ORDER BY
        CASE f.type WHEN 'memoria' THEN 0 WHEN 'myths' THEN 1 WHEN 'secret_time' THEN 2
                    WHEN 'tender_moment' THEN 3 ELSE 4 END,
        f.rarity DESC, f.created_at
    ''', [characterId]);

    final covers = <int, List<CoverImage>>{};
    final coverRows = await _db.rawQuery('''
      SELECT s.folder_id, s.cover_path, s.cover_crop_x, s.cover_crop_y, s.cover_crop_d FROM stories s
      JOIN folders f ON f.id = s.folder_id
      WHERE f.character_id = ? AND s.cover_path IS NOT NULL
      ORDER BY s.created_at DESC
    ''', [characterId]);
    for (final r in coverRows) {
      final list = covers.putIfAbsent(r['folder_id']! as int, () => []);
      if (list.length < 3) list.add(CoverImage(r['cover_path']! as String, _cropFrom(r, _coverCrop)));
    }

    return [
      for (final r in rows)
        _folder(r, storyCount: r['story_count']! as int, covers: covers[r['id']] ?? const []),
    ];
  }

  Future<Folder?> folder(int id) async {
    final rows = await _db.query('folders', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : _folder(rows.single);
  }

  /// Dossier d'un personnage pour ce type, créé s'il n'existe pas encore.
  Future<int> folderFor(int characterId, FolderType type, {int? rarity}) async {
    // sqflite refuse `null` en argument : « rarity IS NULL » est écrit en clair.
    final wantedRarity = type == FolderType.memoria ? rarity : null;
    final existing = await _db.query(
      'folders',
      columns: ['id'],
      where: 'character_id = ? AND type = ? AND rarity ${wantedRarity == null ? 'IS NULL' : '= ?'}',
      whereArgs: [characterId, type.code, ?wantedRarity],
      limit: 1,
    );
    if (existing.isNotEmpty) return existing.single['id']! as int;
    return createFolder(characterId, Folder.defaultName(type, rarity: rarity), type, rarity: rarity);
  }

  Future<int> createFolder(int characterId, String name, FolderType type, {int? rarity}) async {
    final id = await _db.insert('folders', {
      'character_id': characterId,
      'name': name.trim(),
      'type': type.code,
      'rarity': type == FolderType.memoria ? rarity : null,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
    notifyListeners();
    return id;
  }

  /// Modifie un dossier. Lève [DuplicateFolderException] si le personnage a
  /// déjà un autre dossier de ce nom.
  Future<void> updateFolder(
    int folderId, {
    required int characterId,
    required String name,
    required FolderType type,
    int? rarity,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw ArgumentError.value(name, 'name', 'Nom vide');
    if (await folderNameTaken(characterId, trimmed, exceptId: folderId)) throw DuplicateFolderException(trimmed);
    await _db.update(
      'folders',
      {
        'character_id': characterId,
        'name': trimmed,
        'type': type.code,
        'rarity': type == FolderType.memoria ? rarity : null,
      },
      where: 'id = ?',
      whereArgs: [folderId],
    );
    notifyListeners();
  }

  /// Le personnage a-t-il déjà un dossier de ce nom (majuscules ignorées) ?
  Future<bool> folderNameTaken(int characterId, String name, {int? exceptId}) async {
    // Comparaison en Dart : NOCASE de SQLite ignore les accents (« À » ≠ « à »).
    final wanted = name.trim().toLowerCase();
    final rows = await _db.query('folders', columns: ['id', 'name'], where: 'character_id = ?', whereArgs: [characterId]);
    return rows.any((r) => r['id'] != exceptId && (r['name']! as String).trim().toLowerCase() == wanted);
  }

  /// Supprime un dossier vide. Lève [StateError] s'il contient des histoires :
  /// on ne les efface jamais par ce biais.
  Future<void> deleteFolder(int folderId) async {
    final count = Sqflite.firstIntValue(
      await _db.rawQuery('SELECT COUNT(*) FROM stories WHERE folder_id = ?', [folderId]),
    );
    if ((count ?? 0) > 0) throw StateError('Le dossier contient encore $count histoire(s).');
    await _db.delete('folders', where: 'id = ?', whereArgs: [folderId]);
    notifyListeners();
  }
}
