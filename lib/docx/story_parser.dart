import 'dart:typed_data';

import 'docx_reader.dart';
import 'story_model.dart';

/// Lit un FR.docx et construit l'histoire.
ParsedStory parseStoryDocx(Uint8List bytes) => parseStoryParagraphs(readDocxParagraphs(bytes));

/// Nature d'un paragraphe, dans une seule langue.
enum ParaKind { empty, heading, separator, choicePrompt, choiceOption, dialogue, thought, narration }

class ParaInfo {
  const ParaInfo(this.kind, this.text, {String? raw, this.speaker}) : raw = raw ?? text;

  final ParaKind kind;

  /// Texte sans le locuteur ni la numérotation d'option.
  final String text;

  /// Paragraphe complet, tel qu'écrit dans le fichier.
  final String raw;
  final String? speaker;

  bool get isLine => kind == ParaKind.dialogue || kind == ParaKind.thought || kind == ParaKind.narration;
}

final _separator = RegExp(r'^-{3,}$');
final _choicePrompt = RegExp(r'^(choix|choices?)\s*:\s*$', caseSensitive: false);
/// Numérotation d'option : « 01. », « 1) », « 1 – », « 1 - ».
final _optionNumber = RegExp(r'^\d{1,2}\s*(?:[.)]|\s[–—-])\s*');

/// Titres de partie reconnus même sans le style « Titre 1 ».
final _unstyledHeading = RegExp(
  r'^(?:[ée]pisode|chapitre|chapter)\s*\d+$|^(?:kindled|fin|the end|end|prologue|[ée]pilogue)$',
  caseSensitive: false,
);
final _titleSuffix = RegExp(r'^(.*?)\s*\(([^()]+)\)\s*$');

/// Ponctuation qui ne peut pas apparaître dans un nom de locuteur : si le texte
/// avant « : » en contient, c'est une phrase de narration (« … magnétiques : il s'agit… »).
final _sentencePunctuation = RegExp('[.!?…;,"«»“”]');

/// Limites d'un nom de personnage. « Propriétaire de la boutique de vins »
/// (6 mots, 35 caractères) passe ; « Nous avons localisé la source des
/// fluctuations magnétiques » (58 caractères) reste de la narration.
const _maxSpeakerLength = 50;
const _maxSpeakerWords = 8;

/// Reconnaît la nature d'un paragraphe.
///
/// [inChoice] : on est entre « Choix: » et « --- » ; une puce ou un « 01. »
/// y est alors une option.
ParaInfo classifyParagraph(DocParagraph p, {bool inChoice = false}) {
  final text = p.text.trim();
  if (text.isEmpty) return const ParaInfo(ParaKind.empty, '');
  if (p.isHeading1 || _unstyledHeading.hasMatch(text)) return ParaInfo(ParaKind.heading, text);
  if (_separator.hasMatch(text)) return ParaInfo(ParaKind.separator, text);
  if (_choicePrompt.hasMatch(text)) return ParaInfo(ParaKind.choicePrompt, text);
  if (inChoice && (p.isListItem || _optionNumber.hasMatch(text))) {
    return ParaInfo(ParaKind.choiceOption, text.replaceFirst(_optionNumber, '').trim(), raw: text);
  }

  final colon = text.indexOf(':');
  if (colon > 0) {
    final speaker = text.substring(0, colon).trim();
    final rest = text.substring(colon + 1).trim();
    if (_looksLikeSpeaker(speaker) && rest.isNotEmpty) {
      final thought = rest.startsWith('(');
      return ParaInfo(thought ? ParaKind.thought : ParaKind.dialogue, rest, raw: text, speaker: speaker);
    }
  }
  return ParaInfo(ParaKind.narration, text);
}

/// Personnage dont le nom n'est pas encore connu dans le jeu : « ?? »,
/// « ??? » (y compris le point d'interrogation pleine chasse « ？ »).
final _unknownSpeaker = RegExp(r'^[?？]+$');

bool _looksLikeSpeaker(String s) =>
    _unknownSpeaker.hasMatch(s) ||
    (s.isNotEmpty &&
        s.length <= _maxSpeakerLength &&
        s.split(RegExp(r'\s+')).length <= _maxSpeakerWords &&
        !_sentencePunctuation.hasMatch(s));

/// Paragraphe utile d'un fichier, avec sa position d'origine dans le .docx.
class _Kept {
  const _Kept(this.paragraph, this.info);

  final int paragraph;
  final ParaInfo info;
}

/// Garde les paragraphes utiles.
///
/// Les lignes vides et les « --- » de mise en page sont retirés ; seul reste
/// le « --- » qui ferme un choix.
List<_Kept> _keepMeaningful(List<DocParagraph> paragraphs) {
  final kept = <_Kept>[];
  var inChoice = false;
  for (final (i, p) in paragraphs.indexed) {
    final info = classifyParagraph(p, inChoice: inChoice);
    switch (info.kind) {
      case ParaKind.empty:
        continue;
      case ParaKind.separator:
        if (!inChoice) continue;
        inChoice = false;
      case ParaKind.choicePrompt:
        inChoice = true;
      case ParaKind.heading:
        // Un titre de partie ferme aussi un choix oublié ; le parseur le signalera.
        inChoice = false;
      default:
        break;
    }
    kept.add(_Kept(i, info));
  }
  return kept;
}

/// Construit l'histoire à partir des paragraphes du fichier.
ParsedStory parseStoryParagraphs(List<DocParagraph> paragraphs) {
  final warnings = <ImportWarning>[];
  final kept = _keepMeaningful(paragraphs);
  final b = _Builder(warnings);

  for (final (k, _Kept(paragraph: i, :info)) in kept.indexed) {
    // Le premier « Titre 1 » suivi directement d'un autre « Titre 1 » est le
    // titre de l'histoire, pas une partie.
    if (k == 0 && info.kind == ParaKind.heading && kept.length > 1 && kept[1].info.kind == ParaKind.heading) {
      b.setTitle(info.text);
      continue;
    }

    switch (info.kind) {
      case ParaKind.empty:
        break;
      case ParaKind.heading:
        b.startPart(i, info.text);
      case ParaKind.separator:
        b.endChoice();
      case ParaKind.choicePrompt:
        b.startChoice(i, info.text);
      case ParaKind.choiceOption:
        b.startOption(i, info.text);
      case ParaKind.dialogue || ParaKind.thought || ParaKind.narration:
        b.line(StoryLine(
          paragraph: i,
          kind: switch (info.kind) {
            ParaKind.dialogue => LineKind.dialogue,
            ParaKind.thought => LineKind.thought,
            _ => LineKind.narration,
          },
          speaker: info.speaker,
          text: info.text,
        ));
    }
  }

  return b.finish(paragraphCount: paragraphs.length);
}

class _Builder {
  _Builder(this.warnings);

  final List<ImportWarning> warnings;
  final parts = <StoryPart>[];

  String title = '';
  String? subtitle;

  int? _partParagraph;
  String? _partTitle;
  var _items = <PartItem>[];

  int? _choiceParagraph;
  String? _choicePrompt;
  final _options = <ChoiceOption>[];
  int? _optionParagraph;
  String? _optionLabel;
  var _optionLines = <StoryLine>[];

  bool get inChoice => _choicePrompt != null;

  void setTitle(String raw) {
    final m = _titleSuffix.firstMatch(raw);
    title = m?.group(1) ?? raw;
    subtitle = m?.group(2);
  }

  void startPart(int paragraph, String partTitle) {
    if (inChoice) {
      warnings.add(ImportWarning(_choiceParagraph, 'Choix sans « --- » de fin avant « $partTitle ».'));
      _closeChoice();
    }
    _closePart();
    _partParagraph = paragraph;
    _partTitle = partTitle;
  }

  /// « --- » qui ferme un choix (les autres ont été retirés avant).
  void endChoice() {
    if (inChoice) _closeChoice();
  }

  void startChoice(int paragraph, String prompt) {
    if (inChoice) {
      warnings.add(ImportWarning(_choiceParagraph, 'Choix sans « --- » de fin avant le choix suivant.'));
      _closeChoice();
    }
    _ensurePart(paragraph);
    _choiceParagraph = paragraph;
    _choicePrompt = prompt;
  }

  void startOption(int paragraph, String label) {
    _closeOption();
    _optionParagraph = paragraph;
    _optionLabel = label;
  }

  void line(StoryLine line) {
    _ensurePart(line.paragraph);
    if (inChoice) {
      if (_optionLabel == null) {
        warnings.add(ImportWarning(line.paragraph, 'Réplique entre « Choix: » et la première option.'));
        _items.add(line);
      } else {
        _optionLines.add(line);
      }
      return;
    }
    _items.add(line);
  }

  ParsedStory finish({required int paragraphCount}) {
    if (inChoice) {
      warnings.add(ImportWarning(_choiceParagraph, 'Choix sans « --- » de fin à la fin du fichier.'));
      _closeChoice();
    }
    _closePart();
    if (_untitledStart != null && parts.length > 1) {
      warnings.add(ImportWarning(_untitledStart, 'Texte avant le premier titre de partie : partie sans titre créée.'));
    }
    if (parts.isEmpty) {
      warnings.add(const ImportWarning(null, 'Aucune partie trouvée : vérifie le style « Titre 1 ».'));
    }
    return ParsedStory(
      title: title,
      subtitle: subtitle,
      parts: List.unmodifiable(parts),
      paragraphCount: paragraphCount,
      warnings: List.unmodifiable(warnings),
    );
  }

  /// Paragraphe où commence une partie sans titre, s'il y en a une.
  int? _untitledStart;

  /// Du texte avant le premier titre de partie : on ouvre une partie sans
  /// titre. C'est normal pour une histoire d'un seul tenant (Secret Time,
  /// Tender Moment) ; [finish] ne le signale que s'il y a d'autres parties.
  void _ensurePart(int paragraph) {
    if (_partTitle != null) return;
    _untitledStart ??= paragraph;
    _partParagraph = paragraph;
    _partTitle = '';
  }

  void _closeOption() {
    if (_optionLabel == null) return;
    _options.add(ChoiceOption(paragraph: _optionParagraph!, label: _optionLabel!, lines: List.unmodifiable(_optionLines)));
    _optionLabel = null;
    _optionLines = [];
  }

  void _closeChoice() {
    _closeOption();
    if (_options.isEmpty) {
      warnings.add(ImportWarning(_choiceParagraph, 'Choix sans option (puces ou « 01. »).'));
    }
    _items.add(Choice(paragraph: _choiceParagraph!, prompt: _choicePrompt!, options: List.unmodifiable(_options)));
    _options.clear();
    _choicePrompt = null;
    _choiceParagraph = null;
  }

  void _closePart() {
    if (_partTitle == null) return;
    // Un titre seul en fin de fichier (« FIN ») ne fait pas une partie.
    if (_items.isNotEmpty) parts.add(StoryPart(paragraph: _partParagraph!, title: _partTitle!, items: List.unmodifiable(_items)));
    _partTitle = null;
    _items = [];
  }
}
