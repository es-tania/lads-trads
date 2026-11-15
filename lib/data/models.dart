/// Données de la bibliothèque, telles que stockées en base.
///
/// Personnage › Dossier › Histoire › Parties › Lignes.
library;

import 'dart:math' as math;
import 'dart:ui' show Offset, Rect, Size;

class Character {
  const Character({required this.id, required this.name, this.imagePath, this.crop});

  final int id;
  final String name;

  /// Image du personnage dans le stockage de l'app.
  final String? imagePath;

  /// Cercle choisi sur l'image, ou `null` pour le cadrage par défaut.
  final ImageCrop? crop;

  /// Initiale affichée quand il n'y a pas d'image.
  String get initial {
    final trimmed = name.trim();
    return trimmed.isEmpty ? '?' : String.fromCharCode(trimmed.runes.first).toUpperCase();
  }
}

/// Rapport largeur sur hauteur des couvertures.
const coverAspect = 3 / 4;

/// Une couverture : son fichier et son cadrage.
class CoverImage {
  const CoverImage(this.path, [this.crop]);

  final String path;
  final ImageCrop? crop;

  @override
  bool operator ==(Object other) => other is CoverImage && other.path == path && other.crop == crop;

  @override
  int get hashCode => Object.hash(path, crop);
}

/// Cadrage d'une image : un cadre (cercle d'un personnage, rectangle 3:4
/// d'une couverture) placé sur l'image, en fractions de l'image.
///
/// [x] : centre en fraction de la largeur, [y] : en fraction de la hauteur.
/// [d] : taille du cadre en fraction du plus grand cadre de même forme qui
/// tient dans l'image (1 : le plus grand possible). Pour un cercle, c'est
/// le diamètre en fraction du plus petit côté. Tous entre 0 et 1.
class ImageCrop {
  const ImageCrop({required this.x, required this.y, required this.d});

  /// Personnage par défaut : centré, 80 % du plus petit côté.
  static const character = ImageCrop(x: 0.5, y: 0.5, d: 0.8);

  /// Couverture par défaut : le plus grand cadre centré (comme « cover »).
  static const full = ImageCrop(x: 0.5, y: 0.5, d: 1);

  /// Plus petite taille proposée.
  static const minSize = 0.2;

  final double x;
  final double y;
  final double d;

  /// Taille en pixels du plus grand cadre de rapport [aspect] (largeur sur
  /// hauteur) qui tient dans une image de taille [size].
  static Size maxFrame(Size size, double aspect) {
    final w = math.min(size.width, size.height * aspect);
    return Size(w, w / aspect);
  }

  /// Même cadre, ramené à l'intérieur d'une image de taille [size].
  ImageCrop clampTo(Size size, {double aspect = 1}) {
    if (size.isEmpty) return this;
    final dd = d.clamp(0.05, 1.0);
    final max = maxFrame(size, aspect);
    final hw = dd * max.width / 2;
    final hh = dd * max.height / 2;
    return ImageCrop(
      x: (x * size.width).clamp(hw, math.max(hw, size.width - hw)) / size.width,
      y: (y * size.height).clamp(hh, math.max(hh, size.height - hh)) / size.height,
      d: dd,
    );
  }

  /// Le cadre, en pixels d'une image de taille [size].
  Rect frameIn(Size size, {double aspect = 1}) {
    final c = clampTo(size, aspect: aspect);
    final max = maxFrame(size, aspect);
    return Rect.fromCenter(
      center: Offset(c.x * size.width, c.y * size.height),
      width: c.d * max.width,
      height: c.d * max.height,
    );
  }

  @override
  bool operator ==(Object other) => other is ImageCrop && other.x == x && other.y == y && other.d == d;

  @override
  int get hashCode => Object.hash(x, y, d);

  @override
  String toString() => 'ImageCrop($x, $y, $d)';
}

enum FolderType {
  memoria('memoria', 'Memoria'),
  myths('myths', 'Myths'),
  secretTime('secret_time', 'Secret Time'),
  tenderMoment('tender_moment', 'Tender Moment'),
  other('other', 'Autre');

  const FolderType(this.code, this.label);

  /// Valeur stockée en base.
  final String code;
  final String label;

  static FolderType fromCode(String code) =>
      values.firstWhere((t) => t.code == code, orElse: () => FolderType.other);
}

class Folder {
  const Folder({
    required this.id,
    required this.characterId,
    required this.name,
    required this.type,
    this.rarity,
    this.storyCount = 0,
    this.covers = const [],
  });

  final int id;
  final int characterId;

  /// Nom affiché (« Memoria 5★ », « À relire »…).
  final String name;
  final FolderType type;

  /// 4 ou 5 pour un dossier Memoria, sinon `null`.
  final int? rarity;

  /// Calculés à la lecture : nombre d'histoires et jusqu'à trois couvertures.
  final int storyCount;
  final List<CoverImage> covers;

  /// Nom par défaut d'un dossier selon son type.
  static String defaultName(FolderType type, {int? rarity}) =>
      type == FolderType.memoria ? 'Memoria ${rarity ?? 5}★' : type.label;
}

class Story {
  const Story({
    required this.id,
    required this.folderId,
    required this.title,
    required this.titleEn,
    required this.createdAt,
    this.coverPath,
    this.coverCrop,
    this.partCount = 0,
    this.characterName = '',
    this.folderName = '',
  });

  final int id;
  final int folderId;
  final String title;
  final String titleEn;
  final DateTime createdAt;

  /// Chemin de l'image de couverture dans le stockage de l'app.
  final String? coverPath;

  /// Cadre 3:4 choisi sur la couverture, `null` : le plus grand, centré.
  final ImageCrop? coverCrop;

  CoverImage? get cover => coverPath == null ? null : CoverImage(coverPath!, coverCrop);

  /// Calculés à la lecture.
  final int partCount;
  final String characterName;
  final String folderName;
}

class Part {
  const Part({
    required this.id,
    required this.storyId,
    required this.position,
    required this.title,
    required this.titleEn,
    this.lineCount = 0,
  });

  final int id;
  final int storyId;

  /// Ordre dans l'histoire, à partir de 0.
  final int position;
  final String title;
  final String titleEn;

  /// Nombre de répliques, branches comprises.
  final int lineCount;

  /// Titre lisible : « ÉPISODE 1 » → « Épisode 1 », « KINDLED » → « Kindled ».
  String get displayTitle => title.isEmpty ? 'Partie ${position + 1}' : _sentenceCase(title);

  static String _sentenceCase(String s) {
    final letters = s.replaceAll(RegExp(r'[^\p{L}]', unicode: true), '');
    if (letters.isEmpty || letters != letters.toUpperCase()) return s;
    final lower = s.toLowerCase();
    return lower[0].toUpperCase() + lower.substring(1);
  }
}

/// Type d'une ligne stockée.
enum LineRowKind {
  dialogue,
  thought,
  narration,

  /// « Choix: ». Ses options ont pour parent cette ligne.
  choice,

  /// Une option d'un choix. Les répliques de sa branche ont pour parent cette ligne.
  option;

  static LineRowKind fromName(String name) => values.byName(name);
}

/// Une ligne d'une partie, dans l'ordre du fichier.
class LineRow {
  const LineRow({
    required this.id,
    required this.partId,
    required this.position,
    required this.kind,
    required this.text,
    required this.textEn,
    this.speaker,
    this.speakerEn,
    this.parentId,
    this.paragraph,
    this.note,
  });

  final int id;
  final int partId;
  final int position;
  final LineRowKind kind;
  final String text;
  final String textEn;
  final String? speaker;
  final String? speakerEn;

  /// Choix d'une option, ou option d'une réplique de branche.
  final int? parentId;

  /// Numéro du paragraphe dans le FR.docx d'origine (`null` pour une ligne
  /// ajoutée dans l'éditeur).
  final int? paragraph;

  /// Note de traduction, visible seulement en mode admin.
  final String? note;
}
