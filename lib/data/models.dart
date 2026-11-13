/// Données de la bibliothèque, telles que stockées en base.
///
/// Personnage › Dossier › Histoire › Parties › Lignes.
library;

class Character {
  const Character({required this.id, required this.name});

  final int id;
  final String name;
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
  final List<String> covers;

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

  /// Numéro du paragraphe dans le FR.docx d'origine.
  final int? paragraph;
}
