part of '../library_repository.dart';

/// Lignes d'une partie et leur édition : répliques, choix et branches,
/// personnages qui parlent.
mixin _Lines on _LibraryBase {
  /// Lignes d'une partie, dans l'ordre du fichier (choix, options et
  /// branches compris).
  Future<List<LineRow>> lines(int partId) async {
    final rows = await _db.query('lines', where: 'part_id = ?', whereArgs: [partId], orderBy: 'position');
    return rows.map(_line).toList();
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

  // ── Modifier ──────────────────────────────────────────────────────────

  /// Modifie une réplique, une pensée ou une narration.
  ///
  /// La narration n'a pas de personnage. Quand le personnage change, son nom
  /// anglais est repris d'une autre ligne de l'histoire où il parle.
  Future<void> updateLine(
    int lineId, {
    required LineRowKind kind,
    required String text,
    String? speaker,
  }) async {
    _checkSpoken(kind);
    final row = await _lineById(lineId);
    final who = kind == LineRowKind.narration ? null : _clean(speaker);
    final speakerEn = await _speakerEnFor(row, who);
    await _db.update(
      'lines',
      {'kind': kind.name, 'text': text.trim(), 'speaker': who, 'speaker_en': speakerEn},
      where: 'id = ?',
      whereArgs: [lineId],
    );
    notifyListeners();
  }

  /// Change le texte et le personnage d'une ligne pendant la lecture (depuis
  /// la fenêtre flottante).
  ///
  /// [speaker] `null` : la ligne devient une narration (voir
  /// [LineRowKind.withSpeaker]). Renvoie le type obtenu.
  Future<LineRowKind> updateLineWhileReading(int lineId, {required String text, required String? speaker}) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) throw ArgumentError.value(text, 'text', 'Texte vide');
    final row = await _lineById(lineId);
    final kind = LineRowKind.fromName(row['kind']! as String);
    _checkSpoken(kind);
    final who = _clean(speaker);
    final newKind = kind.withSpeaker(who);
    final speakerEn = await _speakerEnFor(row, who);
    await _db.update(
      'lines',
      {'kind': newKind.name, 'text': trimmed, 'speaker': who, 'speaker_en': speakerEn},
      where: 'id = ?',
      whereArgs: [lineId],
    );
    notifyListeners();
    return newKind;
  }

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

  // ── Ajouter ───────────────────────────────────────────────────────────

  /// Insère une ligne juste avant ou juste après [lineId], au même niveau
  /// (tronc ou branche). Après un choix, elle vient après toutes ses
  /// branches. Renvoie son identifiant.
  Future<int> insertLineNextTo(
    int lineId, {
    required bool after,
    required LineRowKind kind,
    required String text,
    String? speaker,
  }) async {
    final row = await _lineById(lineId);
    final own = row['position']! as int;
    final position = after ? await _lastPositionUnder(lineId, own) + 1 : own;
    return _insertAt(
      row['part_id']! as int,
      position,
      parentId: row['parent_id'] as int?,
      kind: kind,
      text: text,
      speaker: speaker,
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
  }) async {
    final int position;
    if (optionId == null) {
      final max = Sqflite.firstIntValue(await _db.rawQuery('SELECT MAX(position) FROM lines WHERE part_id = ?', [partId]));
      position = (max ?? -1) + 1;
    } else {
      final option = await _lineById(optionId);
      position = await _lastPositionUnder(optionId, option['position']! as int) + 1;
    }
    return _insertAt(partId, position, parentId: optionId, kind: kind, text: text, speaker: speaker);
  }

  /// Ajoute une branche à la fin d'un choix.
  Future<int> addOption(int choiceId, String label) async {
    final choice = await _lineById(choiceId);
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

  Future<int> _insertAt(
    int partId,
    int position, {
    required int? parentId,
    required LineRowKind kind,
    required String text,
    String? speaker,
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
      });
    });
    notifyListeners();
    return id;
  }

  // ── Supprimer ─────────────────────────────────────────────────────────

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

  // ── Outils ────────────────────────────────────────────────────────────

  Future<_Row> _lineById(int id) async => (await _db.query('lines', where: 'id = ?', whereArgs: [id])).single;

  static void _checkSpoken(LineRowKind kind) {
    if (!kind.isSpoken) throw ArgumentError.value(kind, 'kind', 'Seulement réplique, pensée ou narration');
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

  /// Nom anglais de [speaker] pour la ligne [row] : inchangé si le
  /// personnage ne change pas, sinon repris d'une autre ligne de l'histoire.
  Future<Object?> _speakerEnFor(_Row row, String? speaker) async =>
      speaker == row['speaker'] ? row['speaker_en'] : await _speakerEn(row['part_id']! as int, speaker);

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
}
