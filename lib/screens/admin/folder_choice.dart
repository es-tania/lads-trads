import '../../data/models.dart';

/// Dossier proposé dans une liste : existant, ou à créer à l'enregistrement.
class FolderChoice {
  const FolderChoice({required this.name, required this.type, this.rarity, this.id});

  final int? id;
  final String name;
  final FolderType type;
  final int? rarity;

  /// Deux choix sont le même dossier s'ils désignent le même dossier existant,
  /// ou le même type à créer.
  String get key => id != null ? 'id:$id' : 'new:${type.code}:$rarity';

  /// Même type à créer, pour garder le classement en changeant de personnage.
  FolderChoice get asNew => FolderChoice(name: Folder.defaultName(type, rarity: rarity), type: type, rarity: rarity);
}

const defaultFolderChoices = [
  FolderChoice(name: 'Memoria 5★', type: FolderType.memoria, rarity: 5),
  FolderChoice(name: 'Memoria 4★', type: FolderType.memoria, rarity: 4),
  FolderChoice(name: 'Myths', type: FolderType.myths),
  FolderChoice(name: 'Secret Time', type: FolderType.secretTime),
  FolderChoice(name: 'Tender Moment', type: FolderType.tenderMoment),
];

/// Dossiers existants d'un personnage, puis les types par défaut qu'il n'a
/// pas encore.
List<FolderChoice> folderChoices(List<Folder> folders) {
  final existing = [
    for (final f in folders) FolderChoice(id: f.id, name: f.name, type: f.type, rarity: f.rarity),
  ];
  final missing = defaultFolderChoices.where(
    (d) => !folders.any((f) => f.type == d.type && f.rarity == d.rarity),
  );
  return [...existing, ...missing];
}
