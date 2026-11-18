part of '../library_repository.dart';

// Passage des lignes de la base aux modèles, et retour.

typedef _Row = Map<String, Object?>;

/// Colonnes d'un cadrage : `crop_x`… pour un personnage, `cover_crop_x`…
/// pour une couverture.
const _characterCrop = 'crop_';
const _coverCrop = 'cover_crop_';

ImageCrop? _cropFrom(_Row r, String prefix) {
  final (x, y, d) = (r['${prefix}x'] as num?, r['${prefix}y'] as num?, r['${prefix}d'] as num?);
  return x == null || y == null || d == null ? null : ImageCrop(x: x.toDouble(), y: y.toDouble(), d: d.toDouble());
}

_Row _cropColumns(ImageCrop? crop, String prefix) => {
      '${prefix}x': crop?.x.clamp(0.0, 1.0),
      '${prefix}y': crop?.y.clamp(0.0, 1.0),
      '${prefix}d': crop?.d.clamp(0.0, 1.0),
    };

Character _character(_Row r) => Character(
      id: r['id']! as int,
      name: r['name']! as String,
      imagePath: r['image_path'] as String?,
      crop: _cropFrom(r, _characterCrop),
    );

Folder _folder(_Row r, {int storyCount = 0, List<CoverImage> covers = const []}) => Folder(
      id: r['id']! as int,
      characterId: r['character_id']! as int,
      name: r['name']! as String,
      type: FolderType.fromCode(r['type']! as String),
      rarity: r['rarity'] as int?,
      storyCount: storyCount,
      covers: covers,
    );

/// Une histoire, lue avec [_storySelect].
Story _story(_Row r) => Story(
      id: r['id']! as int,
      folderId: r['folder_id']! as int,
      title: r['title']! as String,
      titleEn: r['title_en']! as String,
      coverPath: r['cover_path'] as String?,
      coverCrop: _cropFrom(r, _coverCrop),
      createdAt: DateTime.fromMillisecondsSinceEpoch(r['created_at']! as int),
      partCount: r['part_count']! as int,
      characterName: r['character_name']! as String,
      folderName: r['folder_name']! as String,
    );

const _storySelect = '''
    SELECT s.*, f.name AS folder_name, c.name AS character_name,
      (SELECT COUNT(*) FROM parts p WHERE p.story_id = s.id) AS part_count
    FROM stories s
    JOIN folders f ON f.id = s.folder_id
    JOIN characters c ON c.id = f.character_id
  ''';

Part _part(_Row r, int storyId) => Part(
      id: r['id']! as int,
      storyId: storyId,
      position: r['position']! as int,
      title: r['title']! as String,
      titleEn: r['title_en']! as String,
      lineCount: r['line_count']! as int,
    );

LineRow _line(_Row r) => LineRow(
      id: r['id']! as int,
      partId: r['part_id']! as int,
      position: r['position']! as int,
      kind: LineRowKind.fromName(r['kind']! as String),
      text: r['text']! as String,
      textEn: r['text_en']! as String,
      speaker: r['speaker'] as String?,
      speakerEn: r['speaker_en'] as String?,
      parentId: r['parent_id'] as int?,
      paragraph: r['paragraph'] as int?,
    );

/// Texte sans espaces autour, ou `null` s'il est vide.
String? _clean(String? s) {
  final t = s?.trim();
  return t == null || t.isEmpty ? null : t;
}
