/// Repères affichés à côté des répliques, dans l'éditeur et la fenêtre
/// flottante.
library;

/// Numéro sur trois chiffres : 12 → « 012 ».
String paddedNumber(int n) => n.toString().padLeft(3, '0');

/// Numéro d'une réplique : 12 → « L.012 ».
String lineLabel(int n) => 'L.${paddedNumber(n)}';

/// Lettre d'une branche d'un choix : 0 → « A », 1 → « B ».
String optionLetter(int index) => String.fromCharCode(65 + index);
