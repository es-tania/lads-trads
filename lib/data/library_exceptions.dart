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
