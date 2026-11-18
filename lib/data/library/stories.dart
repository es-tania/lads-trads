part of '../library_repository.dart';

/// Histoires : lecture, import d'un .docx analysé, fiche et couverture.
mixin _Stories on _LibraryBase {
  Future<List<Story>> stories(int folderId) async {
    final rows = await _db.rawQuery('$_storySelect WHERE s.folder_id = ? ORDER BY s.created_at', [folderId]);
    return rows.map(_story).toList();
  }

  /// Dernières histoires importées pour un personnage.
  Future<List<Story>> recentStories(int characterId, {int limit = 3}) async {
    final rows = await _db.rawQuery(
      '$_storySelect WHERE f.character_id = ? ORDER BY s.created_at DESC LIMIT ?',
      [characterId, limit],
    );
    return rows.map(_story).toList();
  }

  Future<Story?> story(int id) async {
    final rows = await _db.rawQuery('$_storySelect WHERE s.id = ?', [id]);
    return rows.isEmpty ? null : _story(rows.single);
  }

  /// Recherche dans les titres, tous personnages confondus.
  Future<List<Story>> searchStories(String query) async {
    final q = query.trim();
    if (q.isEmpty) return const [];
    // « ! » sert de caractère d'échappement pour chercher % et _ tels quels.
    final escaped = q.replaceAll('!', '!!').replaceAll('%', '!%').replaceAll('_', '!_');
    final like = '%$escaped%';
    final rows = await _db.rawQuery(
      "$_storySelect WHERE s.title LIKE ? ESCAPE '!' ORDER BY s.title",
      [like],
    );
    return rows.map(_story).toList();
  }

  Future<List<Part>> parts(int storyId) async {
    final rows = await _db.rawQuery('''
      SELECT p.*,
        (SELECT COUNT(*) FROM lines l WHERE l.part_id = p.id
           AND l.kind IN ('dialogue', 'thought', 'narration')) AS line_count
      FROM parts p WHERE p.story_id = ? ORDER BY p.position
    ''', [storyId]);
    return [for (final r in rows) _part(r, storyId)];
  }

  // ── Import ────────────────────────────────────────────────────────────

  /// Enregistre une histoire analysée, avec sa couverture éventuelle.
  Future<int> saveStory({
    required int folderId,
    required String title,
    required ParsedStory parsed,
    Uint8List? coverBytes,
    String? coverName,
    ImageCrop? coverCrop,
  }) async {
    final storyId = await _db.transaction((txn) async {
      final storyId = await txn.insert('stories', {
        'folder_id': folderId,
        'title': title.trim().isEmpty ? parsed.title : title.trim(),
        'created_at': DateTime.now().millisecondsSinceEpoch,
      });
      await _insertParts(txn, storyId, parsed);
      return storyId;
    });

    if (coverBytes != null) {
      await setCover(storyId, coverBytes, coverName ?? 'cover.png', crop: coverCrop, notify: false);
    }
    notifyListeners();
    return storyId;
  }

  /// Remplace les parties et répliques d'une histoire par celles d'un
  /// nouveau .docx. Le titre, le dossier et la couverture sont gardés.
  Future<void> replaceStoryContent(int storyId, ParsedStory parsed) async {
    await _db.transaction((txn) async {
      await txn.delete('parts', where: 'story_id = ?', whereArgs: [storyId]);
      await _insertParts(txn, storyId, parsed);
    });
    notifyListeners();
  }

  Future<void> _insertParts(Transaction txn, int storyId, ParsedStory parsed) async {
    for (final (index, part) in parsed.parts.indexed) {
      final partId = await txn.insert('parts', {
        'story_id': storyId,
        'position': index,
        'title': part.title,
      });
      await _insertItems(txn, partId, part.items);
    }
  }

  Future<void> _insertItems(Transaction txn, int partId, List<PartItem> items) async {
    var position = 0;
    Future<int> insertLine(StoryLine line, {int? parentId}) => txn.insert('lines', {
          'part_id': partId,
          'position': position++,
          'kind': switch (line.kind) {
            LineKind.dialogue => LineRowKind.dialogue.name,
            LineKind.thought => LineRowKind.thought.name,
            LineKind.narration => LineRowKind.narration.name,
          },
          'speaker': line.speaker,
          'text': line.text,
          'parent_id': parentId,
          'paragraph': line.paragraph,
        });

    for (final item in items) {
      switch (item) {
        case StoryLine():
          await insertLine(item);
        case Choice():
          final choiceId = await txn.insert('lines', {
            'part_id': partId,
            'position': position++,
            'kind': LineRowKind.choice.name,
            'text': item.prompt,
            'paragraph': item.paragraph,
          });
          for (final option in item.options) {
            final optionId = await txn.insert('lines', {
              'part_id': partId,
              'position': position++,
              'kind': LineRowKind.option.name,
              'text': option.label,
              'parent_id': choiceId,
              'paragraph': option.paragraph,
            });
            for (final line in option.lines) {
              await insertLine(line, parentId: optionId);
            }
          }
      }
    }
  }

  // ── Fiche de l'histoire ───────────────────────────────────────────────

  /// Change le titre et le dossier d'une histoire.
  Future<void> updateStory(int storyId, {required String title, required int folderId}) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty) throw ArgumentError.value(title, 'title', 'Titre vide');
    await _db.update('stories', {'title': trimmed, 'folder_id': folderId}, where: 'id = ?', whereArgs: [storyId]);
    notifyListeners();
  }

  /// Copie l'image dans le stockage de l'app et l'associe à l'histoire.
  /// Le cadrage repart de [crop], ou du plus grand cadre centré.
  Future<void> setCover(int storyId, Uint8List bytes, String fileName, {ImageCrop? crop, bool notify = true}) async {
    final path = await _images.save(bytes, fileName, prefix: 'story_$storyId');
    await _replaceImage('stories', storyId, column: 'cover_path', path: path, crop: _cropColumns(crop, _coverCrop));
    if (notify) notifyListeners();
  }

  /// Enregistre le cadre choisi sur la couverture.
  Future<void> setCoverCrop(int storyId, ImageCrop crop) async {
    await _db.update('stories', _cropColumns(crop, _coverCrop), where: 'id = ?', whereArgs: [storyId]);
    notifyListeners();
  }

  /// Retire la couverture d'une histoire et efface le fichier.
  Future<void> removeCover(int storyId, {bool notify = true}) async {
    await _replaceImage('stories', storyId, column: 'cover_path', path: null, crop: _cropColumns(null, _coverCrop));
    if (notify) notifyListeners();
  }

  Future<void> deleteStory(int storyId) async {
    final old = await _db.query('stories', columns: ['cover_path'], where: 'id = ?', whereArgs: [storyId]);
    await _db.delete('stories', where: 'id = ?', whereArgs: [storyId]);
    await _images.delete(old.isEmpty ? null : old.single['cover_path'] as String?);
    notifyListeners();
  }
}
