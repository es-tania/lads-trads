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

  /// Dossier où sont copiées les couvertures importées et les images des
  /// personnages.
  final Directory coversDir;

  // ── Lecture ───────────────────────────────────────────────────────────

  Future<List<Character>> characters() async {
    final rows = await _db.query('characters', orderBy: 'position, id');
    return [for (final r in rows) _character(r)];
  }

  Character _character(Map<String, Object?> r) {
    final (x, y, d) = (r['crop_x'] as num?, r['crop_y'] as num?, r['crop_d'] as num?);
    return Character(
      id: r['id']! as int,
      name: r['name']! as String,
      imagePath: r['image_path'] as String?,
      crop: x == null || y == null || d == null
          ? null
          : ImageCrop(x: x.toDouble(), y: y.toDouble(), d: d.toDouble()),
    );
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

    final covers = <int, List<CoverImage>>{};
    final coverRows = await _db.rawQuery('''
      SELECT s.folder_id, s.cover_path, s.cover_crop_x, s.cover_crop_y, s.cover_crop_d FROM stories s
      JOIN folders f ON f.id = s.folder_id
      WHERE f.character_id = ? AND s.cover_path IS NOT NULL
      ORDER BY s.created_at DESC
    ''', [characterId]);
    for (final r in coverRows) {
      final list = covers.putIfAbsent(r['folder_id']! as int, () => []);
      if (list.length < 3) list.add(CoverImage(r['cover_path']! as String, _coverCrop(r)));
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
        coverCrop: _coverCrop(r),
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
          note: r['note'] as String?,
        ),
    ];
  }

  /// L'histoire a-t-elle du texte anglais (importée avec un EN.docx) ?
  Future<bool> hasEnglish(int storyId) async {
    final rows = await _db.rawQuery('''
      SELECT 1 FROM lines l JOIN parts p ON p.id = l.part_id
      WHERE p.story_id = ? AND TRIM(l.text_en) != '' LIMIT 1
    ''', [storyId]);
    return rows.isNotEmpty;
  }

  /// Noms des personnages qui parlent dans l'histoire, du plus fréquent au
  /// moins fréquent.
  Future<List<String>> speakers(int storyId) async {
    final rows = await _db.rawQuery('''
      SELECT l.speaker, COUNT(*) AS n FROM lines l JOIN parts p ON p.id = l.part_id
      WHERE p.story_id = ? AND l.speaker IS NOT NULL AND TRIM(l.speaker) != ''
      GROUP BY l.speaker ORDER BY n DESC, MIN(p.position), MIN(l.position)
    ''', [storyId]);
    return [for (final r in rows) r['speaker']! as String];
  }

  // ── Écriture (mode admin) ─────────────────────────────────────────────

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
    await coversDir.create(recursive: true);
    final ext = p.extension(fileName).toLowerCase();
    final file = File(p.join(
      coversDir.path,
      'character_${characterId}_${DateTime.now().millisecondsSinceEpoch}${ext.isEmpty ? '.png' : ext}',
    ));
    await file.writeAsBytes(bytes, flush: true);

    final old = await _db.query('characters', columns: ['image_path'], where: 'id = ?', whereArgs: [characterId]);
    await _db.update(
      'characters',
      {'image_path': file.path, ..._cropColumns(crop)},
      where: 'id = ?',
      whereArgs: [characterId],
    );
    final oldPath = old.isEmpty ? null : old.single['image_path'] as String?;
    if (oldPath != null) await _deleteQuietly(oldPath);
    notifyListeners();
  }

  /// Enregistre le cercle choisi sur l'image du personnage.
  Future<void> setImageCrop(int characterId, ImageCrop crop) async {
    await _db.update('characters', _cropColumns(crop), where: 'id = ?', whereArgs: [characterId]);
    notifyListeners();
  }

  Map<String, Object?> _cropColumns(ImageCrop? crop) => {
        'crop_x': crop?.x.clamp(0.0, 1.0),
        'crop_y': crop?.y.clamp(0.0, 1.0),
        'crop_d': crop?.d.clamp(0.0, 1.0),
      };

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
      'name': name.trim(),
      'type': type.code,
      'rarity': type == FolderType.memoria ? rarity : null,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
    notifyListeners();
    return id;
  }

  // ── Éditeur de répliques ─────────────────────────────────────────────

  /// Modifie une réplique, une pensée ou une narration.
  ///
  /// La narration n'a pas de personnage. Quand le personnage change, son nom
  /// anglais est repris d'une autre ligne de l'histoire où il parle.
  Future<void> updateLine(
    int lineId, {
    required LineRowKind kind,
    required String text,
    String? speaker,
    String? note,
  }) async {
    _checkSpoken(kind);
    final row = (await _db.query('lines', where: 'id = ?', whereArgs: [lineId])).single;
    final who = kind == LineRowKind.narration ? null : _clean(speaker);
    final speakerEn = who == row['speaker'] ? row['speaker_en'] : await _speakerEn(row['part_id']! as int, who);
    await _db.update(
      'lines',
      {'kind': kind.name, 'text': text.trim(), 'speaker': who, 'speaker_en': speakerEn, 'note': _clean(note)},
      where: 'id = ?',
      whereArgs: [lineId],
    );
    notifyListeners();
  }

  /// Change le texte et le personnage d'une ligne pendant la lecture (depuis
  /// la fenêtre flottante). La note est gardée.
  ///
  /// [speaker] `null` : la ligne devient une narration. Une narration qui
  /// reçoit un personnage devient une réplique ; une pensée reste une pensée.
  /// Renvoie le type obtenu.
  Future<LineRowKind> updateLineWhileReading(int lineId, {required String text, required String? speaker}) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) throw ArgumentError.value(text, 'text', 'Texte vide');
    final row = (await _db.query('lines', where: 'id = ?', whereArgs: [lineId])).single;
    final kind = LineRowKind.fromName(row['kind']! as String);
    _checkSpoken(kind);
    final who = _clean(speaker);
    final newKind = kindForSpeaker(kind, who);
    final speakerEn = who == row['speaker'] ? row['speaker_en'] : await _speakerEn(row['part_id']! as int, who);
    await _db.update(
      'lines',
      {'kind': newKind.name, 'text': trimmed, 'speaker': who, 'speaker_en': speakerEn},
      where: 'id = ?',
      whereArgs: [lineId],
    );
    notifyListeners();
    return newKind;
  }

  /// Type d'une ligne quand son personnage change (voir [updateLineWhileReading]).
  static LineRowKind kindForSpeaker(LineRowKind kind, String? speaker) => switch ((kind, speaker)) {
        (_, null) => LineRowKind.narration,
        (LineRowKind.narration, _) => LineRowKind.dialogue,
        _ => kind,
      };

  /// La base a été modifiée ailleurs (par la fenêtre flottante) : les
  /// écrans rechargent leurs données.
  void refresh() => notifyListeners();

  /// Renomme un personnage dans toutes ses répliques : celles de l'histoire
  /// [storyId], ou de toutes les histoires si `null`. Si [to] existe déjà, les
  /// deux personnages n'en font plus qu'un. Le nom anglais ne change pas.
  /// Renvoie le nombre de répliques modifiées.
  Future<int> renameSpeaker(String from, String to, {int? storyId}) async {
    final target = _clean(to);
    if (target == null) throw ArgumentError.value(to, 'to', 'Nom vide');
    if (target == from) return 0;
    final count = storyId == null
        ? await _db.rawUpdate('UPDATE lines SET speaker = ? WHERE speaker = ?', [target, from])
        : await _db.rawUpdate(
            'UPDATE lines SET speaker = ? WHERE speaker = ? AND part_id IN (SELECT id FROM parts WHERE story_id = ?)',
            [target, from, storyId],
          );
    notifyListeners();
    return count;
  }

  /// Nombre de répliques de ce personnage dans l'histoire [storyId], et
  /// dans toute la bibliothèque.
  Future<({int inStory, int everywhere})> speakerCounts(String name, int storyId) async {
    final inStory = Sqflite.firstIntValue(await _db.rawQuery(
      'SELECT COUNT(*) FROM lines WHERE speaker = ? AND part_id IN (SELECT id FROM parts WHERE story_id = ?)',
      [name, storyId],
    ));
    final everywhere = Sqflite.firstIntValue(await _db.rawQuery('SELECT COUNT(*) FROM lines WHERE speaker = ?', [name]));
    return (inStory: inStory ?? 0, everywhere: everywhere ?? 0);
  }

  /// Insère une ligne juste avant ou juste après [lineId], au même niveau
  /// (tronc ou branche). Après un choix, elle vient après toutes ses
  /// branches. Renvoie son identifiant.
  Future<int> insertLineNextTo(
    int lineId, {
    required bool after,
    required LineRowKind kind,
    required String text,
    String? speaker,
    String? note,
  }) async {
    final row = (await _db.query('lines', where: 'id = ?', whereArgs: [lineId])).single;
    final own = row['position']! as int;
    final position = after ? await _lastPositionUnder(lineId, own) + 1 : own;
    return _insertAt(
      row['part_id']! as int,
      position,
      parentId: row['parent_id'] as int?,
      kind: kind,
      text: text,
      speaker: speaker,
      note: note,
    );
  }

  /// Ajoute une ligne à la fin du tronc d'une partie, ou à la fin de la
  /// branche [optionId].
  Future<int> appendLine(
    int partId, {
    int? optionId,
    required LineRowKind kind,
    required String text,
    String? speaker,
    String? note,
  }) async {
    final int position;
    if (optionId == null) {
      final max = Sqflite.firstIntValue(await _db.rawQuery('SELECT MAX(position) FROM lines WHERE part_id = ?', [partId]));
      position = (max ?? -1) + 1;
    } else {
      final option = (await _db.query('lines', where: 'id = ?', whereArgs: [optionId])).single;
      position = await _lastPositionUnder(optionId, option['position']! as int) + 1;
    }
    return _insertAt(partId, position, parentId: optionId, kind: kind, text: text, speaker: speaker, note: note);
  }

  /// Ajoute une branche à la fin d'un choix.
  Future<int> addOption(int choiceId, String label) async {
    final choice = (await _db.query('lines', where: 'id = ?', whereArgs: [choiceId])).single;
    final partId = choice['part_id']! as int;
    final position = await _lastPositionUnder(choiceId, choice['position']! as int) + 1;
    final id = await _db.transaction((txn) async {
      await _shift(txn, partId, position);
      return txn.insert('lines', {
        'part_id': partId,
        'position': position,
        'kind': LineRowKind.option.name,
        'text': label.trim(),
        'text_en': '',
        'parent_id': choiceId,
      });
    });
    notifyListeners();
    return id;
  }

  /// Renomme une branche (libellé de l'option).
  Future<void> updateOptionLabel(int optionId, String label) async {
    await _db.update(
      'lines',
      {'text': label.trim()},
      where: 'id = ? AND kind = ?',
      whereArgs: [optionId, LineRowKind.option.name],
    );
    notifyListeners();
  }

  /// Supprime une ligne et tout ce qu'elle contient (branches d'un choix,
  /// répliques d'une branche). Un choix qui n'a plus de branche disparaît.
  Future<void> deleteLine(int lineId) async {
    final rows = await _db.query('lines', where: 'id = ?', whereArgs: [lineId]);
    if (rows.isEmpty) return;
    final row = rows.single;
    await _db.transaction((txn) async {
      await txn.delete('lines', where: 'id = ?', whereArgs: [lineId]);
      final parentId = row['parent_id'] as int?;
      if (row['kind'] == LineRowKind.option.name && parentId != null) {
        final left = Sqflite.firstIntValue(await txn.rawQuery('SELECT COUNT(*) FROM lines WHERE parent_id = ?', [parentId]));
        if (left == 0) await txn.delete('lines', where: 'id = ?', whereArgs: [parentId]);
      }
    });
    notifyListeners();
  }

  Future<int> _insertAt(
    int partId,
    int position, {
    required int? parentId,
    required LineRowKind kind,
    required String text,
    String? speaker,
    String? note,
  }) async {
    _checkSpoken(kind);
    final who = kind == LineRowKind.narration ? null : _clean(speaker);
    final speakerEn = await _speakerEn(partId, who);
    final id = await _db.transaction((txn) async {
      await _shift(txn, partId, position);
      return txn.insert('lines', {
        'part_id': partId,
        'position': position,
        'kind': kind.name,
        'speaker': who,
        'speaker_en': speakerEn,
        'text': text.trim(),
        'text_en': '',
        'parent_id': parentId,
        'note': _clean(note),
      });
    });
    notifyListeners();
    return id;
  }

  static void _checkSpoken(LineRowKind kind) {
    if (kind == LineRowKind.choice || kind == LineRowKind.option) {
      throw ArgumentError.value(kind, 'kind', 'Seulement réplique, pensée ou narration');
    }
  }

  /// Décale d'un cran les lignes à partir de [position] pour faire de la place.
  Future<void> _shift(Transaction txn, int partId, int position) =>
      txn.rawUpdate('UPDATE lines SET position = position + 1 WHERE part_id = ? AND position >= ?', [partId, position]);

  /// Dernière position occupée par [lineId] ou ses descendants (branches
  /// d'un choix et leurs répliques).
  Future<int> _lastPositionUnder(int lineId, int own) async {
    final max = Sqflite.firstIntValue(await _db.rawQuery('''
      SELECT MAX(position) FROM lines
      WHERE parent_id = ? OR parent_id IN (SELECT id FROM lines WHERE parent_id = ?)
    ''', [lineId, lineId]));
    return max == null || max < own ? own : max;
  }

  /// Nom anglais d'un personnage, repris d'une ligne de la même histoire.
  Future<String?> _speakerEn(int partId, String? speaker) async {
    if (speaker == null) return null;
    final rows = await _db.rawQuery('''
      SELECT l.speaker_en FROM lines l JOIN parts p ON p.id = l.part_id
      WHERE p.story_id = (SELECT story_id FROM parts WHERE id = ?)
        AND l.speaker = ? AND l.speaker_en IS NOT NULL AND l.speaker_en != ''
      LIMIT 1
    ''', [partId, speaker]);
    return rows.isEmpty ? null : rows.single['speaker_en'] as String?;
  }

  static String? _clean(String? s) {
    final t = s?.trim();
    return t == null || t.isEmpty ? null : t;
  }

  /// Modifie un dossier. Lève [DuplicateFolderException] si le personnage a
  /// déjà un autre dossier de ce nom.
  Future<void> updateFolder(int folderId, {required int characterId, required String name, required FolderType type, int? rarity}) async {
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

  /// Change le titre et le dossier d'une histoire.
  Future<void> updateStory(int storyId, {required String title, required int folderId}) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty) throw ArgumentError.value(title, 'title', 'Titre vide');
    await _db.update('stories', {'title': trimmed, 'folder_id': folderId}, where: 'id = ?', whereArgs: [storyId]);
    notifyListeners();
  }

  /// Retire la couverture d'une histoire et efface le fichier.
  Future<void> removeCover(int storyId, {bool notify = true}) async {
    final old = await _db.query('stories', columns: ['cover_path'], where: 'id = ?', whereArgs: [storyId]);
    await _db.update('stories', {'cover_path': null, ..._coverCropColumns(null)}, where: 'id = ?', whereArgs: [storyId]);
    final oldPath = old.isEmpty ? null : old.single['cover_path'] as String?;
    if (oldPath != null) await _deleteQuietly(oldPath);
    if (notify) notifyListeners();
  }

  /// Remplace les parties et répliques d'une histoire par celles d'un
  /// nouveau .docx. Le titre FR, le dossier et la couverture sont gardés.
  Future<void> replaceStoryContent(int storyId, ParsedStory parsed) async {
    await _db.transaction((txn) async {
      await txn.delete('parts', where: 'story_id = ?', whereArgs: [storyId]);
      await txn.update('stories', {'title_en': parsed.title.en}, where: 'id = ?', whereArgs: [storyId]);
      for (final (index, part) in parsed.parts.indexed) {
        final partId = await txn.insert('parts', {
          'story_id': storyId,
          'position': index,
          'title': part.title.fr,
          'title_en': part.title.en,
        });
        await _insertItems(txn, partId, part.items);
      }
    });
    notifyListeners();
  }

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

    if (coverBytes != null) {
      await setCover(storyId, coverBytes, coverName ?? 'cover.png', crop: coverCrop, notify: false);
    }
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
  /// Le cadrage repart de [crop], ou du plus grand cadre centré.
  Future<void> setCover(int storyId, Uint8List bytes, String fileName, {ImageCrop? crop, bool notify = true}) async {
    await coversDir.create(recursive: true);
    final ext = p.extension(fileName).toLowerCase();
    // Nom unique : une nouvelle couverture ne réutilise pas l'image en cache.
    final file = File(p.join(coversDir.path, 'story_${storyId}_${DateTime.now().millisecondsSinceEpoch}${ext.isEmpty ? '.png' : ext}'));
    await file.writeAsBytes(bytes, flush: true);

    final old = await _db.query('stories', columns: ['cover_path'], where: 'id = ?', whereArgs: [storyId]);
    await _db.update('stories', {'cover_path': file.path, ..._coverCropColumns(crop)}, where: 'id = ?', whereArgs: [storyId]);
    final oldPath = old.isEmpty ? null : old.single['cover_path'] as String?;
    if (oldPath != null) await _deleteQuietly(oldPath);
    if (notify) notifyListeners();
  }

  /// Enregistre le cadre choisi sur la couverture.
  Future<void> setCoverCrop(int storyId, ImageCrop crop) async {
    await _db.update('stories', _coverCropColumns(crop), where: 'id = ?', whereArgs: [storyId]);
    notifyListeners();
  }

  static Map<String, Object?> _coverCropColumns(ImageCrop? crop) => {
        'cover_crop_x': crop?.x.clamp(0.0, 1.0),
        'cover_crop_y': crop?.y.clamp(0.0, 1.0),
        'cover_crop_d': crop?.d.clamp(0.0, 1.0),
      };

  static ImageCrop? _coverCrop(Map<String, Object?> r) {
    final (x, y, d) = (r['cover_crop_x'] as num?, r['cover_crop_y'] as num?, r['cover_crop_d'] as num?);
    return x == null || y == null || d == null ? null : ImageCrop(x: x.toDouble(), y: y.toDouble(), d: d.toDouble());
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

/// Un personnage de ce nom existe déjà.
class DuplicateCharacterException implements Exception {
  const DuplicateCharacterException(this.name);

  final String name;

  @override
  String toString() => '« $name » existe déjà.';
}

/// Le personnage a déjà un dossier de ce nom.
class DuplicateFolderException implements Exception {
  const DuplicateFolderException(this.name);

  final String name;

  @override
  String toString() => 'Un dossier « $name » existe déjà pour ce personnage.';
}
