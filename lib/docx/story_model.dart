/// Modèle d'une histoire importée depuis un FR.docx.
///
/// Histoire › Parties › éléments (répliques et choix). Les « --- » hors choix
/// sont de la mise en page : ils ne sont pas gardés.
library;

enum LineKind {
  /// « Nom : texte »
  dialogue,

  /// « Moi : (…) »
  thought,

  /// Ligne sans locuteur.
  narration,
}

/// Élément d'une partie.
sealed class PartItem {
  const PartItem();
}

class StoryLine extends PartItem {
  const StoryLine({
    required this.paragraph,
    required this.kind,
    required this.text,
    this.speaker,
  });

  /// Numéro du paragraphe dans le FR.docx (0 = premier).
  final int paragraph;
  final LineKind kind;

  /// Nom du locuteur, `null` pour la narration.
  final String? speaker;
  final String text;

  @override
  String toString() => '${kind.name}#$paragraph ${speaker ?? '-'}: $text';
}

/// « Choix: » suivi des options, jusqu'au « --- ».
class Choice extends PartItem {
  const Choice({required this.paragraph, required this.prompt, required this.options});

  final int paragraph;

  /// « Choix: », tel qu'écrit dans le fichier.
  final String prompt;
  final List<ChoiceOption> options;
}

class ChoiceOption {
  const ChoiceOption({required this.paragraph, required this.label, required this.lines});

  final int paragraph;

  /// Libellé de l'option, sans numérotation (« 01. »).
  final String label;

  /// Répliques propres à cette branche.
  final List<StoryLine> lines;
}

class StoryPart {
  const StoryPart({required this.paragraph, required this.title, required this.items});

  final int paragraph;

  /// « ÉPISODE 1 ».
  final String title;
  final List<PartItem> items;

  /// Toutes les répliques, branches de choix comprises, dans l'ordre du fichier.
  Iterable<StoryLine> get allLines sync* {
    for (final item in items) {
      switch (item) {
        case StoryLine():
          yield item;
        case Choice(:final options):
          for (final option in options) {
            yield* option.lines;
          }
      }
    }
  }
}

/// Problème détecté pendant l'import, à montrer dans « À vérifier ».
class ImportWarning {
  const ImportWarning(this.paragraph, this.message);

  /// Numéro du paragraphe concerné, ou `null` pour l'ensemble du fichier.
  final int? paragraph;
  final String message;

  @override
  String toString() => paragraph == null ? message : '§$paragraph : $message';
}

class ParsedStory {
  const ParsedStory({
    required this.title,
    required this.subtitle,
    required this.parts,
    required this.paragraphCount,
    required this.warnings,
  });

  /// Titre tiré du premier « Titre 1 », sans la parenthèse finale. Peut être vide.
  final String title;

  /// Contenu de la parenthèse finale du titre (« Memoria »), s'il y en a une.
  final String? subtitle;
  final List<StoryPart> parts;

  /// Nombre de paragraphes du fichier.
  final int paragraphCount;
  final List<ImportWarning> warnings;
}
