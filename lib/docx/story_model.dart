/// Modèle d'une histoire importée depuis un couple FR.docx / EN.docx.
///
/// Histoire › Parties › éléments (répliques et choix). Les « --- » hors choix
/// sont de la mise en page : ils ne sont pas gardés.
/// Chaque texte existe en deux langues : [Bi.fr] est affiché, [Bi.en] sert à
/// se repérer dans le jeu (et plus tard à la synchronisation par OCR).
library;

/// Un texte dans les deux langues.
class Bi {
  const Bi(this.fr, this.en);

  final String fr;
  final String en;

  @override
  String toString() => '$fr | $en';
}

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
  final Bi? speaker;
  final Bi text;

  @override
  String toString() => '${kind.name}#$paragraph ${speaker?.fr ?? '-'}: ${text.fr}';
}

/// « Choix: » suivi des options, jusqu'au « --- ».
class Choice extends PartItem {
  const Choice({required this.paragraph, required this.prompt, required this.options});

  final int paragraph;

  /// « Choix: » / « Choices : », tel qu'écrit dans les fichiers.
  final Bi prompt;
  final List<ChoiceOption> options;
}

class ChoiceOption {
  const ChoiceOption({required this.paragraph, required this.label, required this.lines});

  final int paragraph;

  /// Libellé de l'option, sans la numérotation « 01. » de l'anglais.
  final Bi label;

  /// Répliques propres à cette branche.
  final List<StoryLine> lines;
}

class StoryPart {
  const StoryPart({required this.paragraph, required this.title, required this.items});

  final int paragraph;

  /// « ÉPISODE 1 » / « EPISODE 1 ».
  final Bi title;
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

/// Ligne de l'EN sans équivalent dans le FR, en général du texte de
/// l'interface du jeu (« Taste », « *START OF KINDLED* »). Elle n'est pas
/// affichée ; on la garde pour la montrer dans l'écran d'import.
class EnOnlyLine {
  const EnOnlyLine(this.paragraph, this.text);

  /// Numéro du paragraphe dans l'EN.docx.
  final int paragraph;
  final String text;

  @override
  String toString() => 'EN§$paragraph $text';
}

class ParsedStory {
  const ParsedStory({
    required this.title,
    required this.subtitle,
    required this.parts,
    required this.paragraphCount,
    required this.warnings,
    this.untranslated = const [],
  });

  /// Titre tiré du premier « Titre 1 », sans la parenthèse finale. Peut être vide.
  final Bi title;

  /// Contenu de la parenthèse finale du titre (« Memoria »), s'il y en a une.
  final String? subtitle;
  final List<StoryPart> parts;

  /// Nombre de paragraphes du fichier FR (identique à l'EN quand tout va bien).
  final int paragraphCount;
  final List<ImportWarning> warnings;

  /// Lignes EN laissées de côté faute de traduction.
  final List<EnOnlyLine> untranslated;
}
