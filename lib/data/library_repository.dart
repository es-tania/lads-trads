import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../docx/story_model.dart';
import 'models.dart';

/// Accès à la bibliothèque locale.
///
/// Prévient ses auditeurs à chaque modification, pour que les écrans se
/// rechargent. À l'étape 6, la même interface parlera à Supabase.
class LibraryRepository extends ChangeNotifier {
  LibraryRepository(this._db, {required this.coversDir});

  final Database _db;

  /// Dossier où sont copiées les couvertures importées.
  final Directory coversDir;

  // ── Lecture ───────────────────────────────────────────────────────────

  Future<List<Character>> characters() async {
    final rows = await _db.query('characters', orderBy: 'position');
    return [for (final r in rows) Character(id: r['id']! as int, name: r['name']! as String)];
  }

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

    final covers = <int, List<String>>{};
    final coverRows = await _db.rawQuery('''
      SELECT s.folder_id, s.cover_path FROM stories s
      JOIN folders f ON f.id = s.folder_id
      WHERE f.character_id = ? AND s.cover_path IS NOT NULL
      ORDER BY s.created_at DESC
    ''', [characterId]);
    for (final r in coverRows) {
      final list = covers.putIfAbsent(r['folder_id']! as int, () => []);
      if (list.length < 3) list.add(r['cover_path']! as String);
    }

    return [
      for (final r in rows)
        Folder(
          id: r['id']! as int,
          characterId: r['character_id']! as int,
          name: r['name']! as String,
          type: FolderType.fromCode(r['type']! as String),
          rarity: r['rarity'] as int?,
          storyCount: r['story_count']! as int,
          covers: covers[r['id']] ?? const [],
        ),
    ];
  }

  Future<Folder?> folder(int id) async {
    final rows = await _db.query('folders', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    final r = rows.single;
    return Folder(
      id: id,
      characterId: r['character_id']! as int,
      name: r['name']! as String,
      type: FolderType.fromCode(r['type']! as String),
      rarity: r['rarity'] as int?,
    );
  }

  static const _storySelect = '''
    SELECT s.*, f.name AS folder_name, c.name AS character_name,
      (SELECT COUNT(*) FROM parts p WHERE p.story_id = s.id) AS part_count
    FROM stories s
    JOIN folders f ON f.id = s.folder_id
    JOIN characters c ON c.id = f.character_id
  ''';

  Story _story(Map<String, Object?> r) => Story(
        id: r['id']! as int,
        folderId: r['folder_id']! as int,
        title: r['title']! as String,
        titleEn: r['title_en']! as String,
        coverPath: r['cover_path'] as String?,
        createdAt: DateTime.fromMillisecondsSinceEpoch(r['created_at']! as int),
        partCount: r['part_count']! as int,
        characterName: r['character_name']! as String,
        folderName: r['folder_name']! as String,
      );

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

  /// Recherche dans les titres FR et EN, tous personnages confondus.
  Future<List<Story>> searchStories(String query) async {
    final q = query.trim();
    if (q.isEmpty) return const [];
    // « ! » sert de caractère d'échappement pour chercher % et _ tels quels.
    final escaped = q.replaceAll('!', '!!').replaceAll('%', '!%').replaceAll('_', '!_');
    final like = '%$escaped%';
    final rows = await _db.rawQuery(
      "$_storySelect WHERE s.title LIKE ? ESCAPE '!' OR s.title_en LIKE ? ESCAPE '!' ORDER BY s.title",
      [like, like],
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
    return [
      for (final r in rows)
        Part(
          id: r['id']! as int,
          storyId: storyId,
          position: r['position']! as int,
          title: r['title']! as String,
          titleEn: r['title_en']! as String,
          lineCount: r['line_count']! as int,
        ),
    ];
  }

  /// Lignes d'une partie, dans l'ordre du fichier (choix, options et
  /// branches compris).
  Future<List<LineRow>> lines(int partId) async {
    final rows = await _db.query('lines', where: 'part_id = ?', whereArgs: [partId], orderBy: 'position');
    return [
      for (final r in rows)
        LineRow(
          id: r['id']! as int,
          partId: partId,
          position: r['position']! as int,
          kind: LineRowKind.fromName(r['kind']! as String),
          text: r['text']! as String,
          textEn: r['text_en']! as String,
          speaker: r['speaker'] as String?,
          speakerEn: r['speaker_en'] as String?,
          parentId: r['parent_id'] as int?,
          paragraph: r['paragraph'] as int?,
        ),
    ];
  }

  // ── Écriture (mode admin) ─────────────────────────────────────────────

  /// Dossier d'un personnage pour ce type, créé s'il n'existe pas encore.
  Future<int> folderFor(int characterId, FolderType type, {int? rarity}) async {
    final existing = await _db.query(
      'folders',
      columns: ['id'],
      where: 'character_id = ? AND type = ? AND rarity IS ?',
      whereArgs: [characterId, type.code, type == FolderType.memoria ? rarity : null],
      limit: 1,
    );
    if (existing.isNotEmpty) return existing.single['id']! as int;
    return createFolder(characterId, Folder.defaultName(type, rarity: rarity), type, rarity: rarity);
  }

  Future<int> createFolder(int characterId, String name, FolderType type, {int? rarity}) async {
    final id = await _db.insert('folders', {
      'character_id': characterId,
      'name': name,
      'type': type.code,
      'rarity': type == FolderType.memoria ? rarity : null,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
    notifyListeners();
    return id;
  }

  /// Enregistre une histoire analysée, avec sa couverture éventuelle.
  Future<int> saveStory({
    required int folderId,
    required String title,
    required ParsedStory parsed,
    Uint8List? coverBytes,
    String? coverName,
  }) async {
    final storyId = await _db.transaction((txn) async {
      final storyId = await txn.insert('stories', {
        'folder_id': folderId,
        'title': title.trim().isEmpty ? parsed.title.fr : title.trim(),
        'title_en': parsed.title.en,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      });
      for (final (index, part) in parsed.parts.indexed) {
        final partId = await txn.insert('parts', {
          'story_id': storyId,
          'position': index,
          'title': part.title.fr,
          'title_en': part.title.en,
        });
        await _insertItems(txn, partId, part.items);
      }
      return storyId;
    });

    if (coverBytes != null) await setCover(storyId, coverBytes, coverName ?? 'cover.png', notify: false);
    notifyListeners();
    return storyId;
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
          'speaker': line.speaker?.fr,
          'speaker_en': line.speaker?.en,
          'text': line.text.fr,
          'text_en': line.text.en,
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
            'text': item.prompt.fr,
            'text_en': item.prompt.en,
            'paragraph': item.paragraph,
          });
          for (final option in item.options) {
            final optionId = await txn.insert('lines', {
              'part_id': partId,
              'position': position++,
              'kind': LineRowKind.option.name,
              'text': option.label.fr,
              'text_en': option.label.en,
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

  /// Copie l'image dans le stockage de l'app et l'associe à l'histoire.
  Future<void> setCover(int storyId, Uint8List bytes, String fileName, {bool notify = true}) async {
    await coversDir.create(recursive: true);
    final ext = p.extension(fileName).toLowerCase();
    // Nom unique : une nouvelle couverture ne réutilise pas l'image en cache.
    final file = File(p.join(coversDir.path, 'story_${storyId}_${DateTime.now().millisecondsSinceEpoch}${ext.isEmpty ? '.png' : ext}'));
    await file.writeAsBytes(bytes, flush: true);

    final old = await _db.query('stories', columns: ['cover_path'], where: 'id = ?', whereArgs: [storyId]);
    await _db.update('stories', {'cover_path': file.path}, where: 'id = ?', whereArgs: [storyId]);
    final oldPath = old.isEmpty ? null : old.single['cover_path'] as String?;
    if (oldPath != null) await _deleteQuietly(oldPath);
    if (notify) notifyListeners();
  }

  Future<void> deleteStory(int storyId) async {
    final old = await _db.query('stories', columns: ['cover_path'], where: 'id = ?', whereArgs: [storyId]);
    await _db.delete('stories', where: 'id = ?', whereArgs: [storyId]);
    final oldPath = old.isEmpty ? null : old.single['cover_path'] as String?;
    if (oldPath != null) await _deleteQuietly(oldPath);
    notifyListeners();
  }

  Future<void> _deleteQuietly(String path) async {
    try {
      await File(path).delete();
    } on FileSystemException {
      // Déjà absent : rien à faire.
    }
  }
}
