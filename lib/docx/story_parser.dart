import 'dart:typed_data';

import 'aligner.dart';
import 'docx_reader.dart';
import 'story_model.dart';

/// Lit FR.docx et EN.docx et construit l'histoire bilingue.
ParsedStory parseStoryDocx({required Uint8List fr, required Uint8List en}) =>
    parseStoryParagraphs(fr: readDocxParagraphs(fr), en: readDocxParagraphs(en));

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

  /// Nom de plus de 4 mots (« Propriétaire de la boutique de vins ») : sans
  /// doute un personnage, mais ce pourrait être le début d'une phrase.
  bool get hasLongSpeaker => speaker != null && speaker!.split(RegExp(r'\s+')).length > 4;

  /// La même ligne, lue comme de la narration.
  ParaInfo asNarration() => ParaInfo(ParaKind.narration, raw);
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

bool _looksLikeSpeaker(String s) =>
    s.isNotEmpty &&
    s.length <= _maxSpeakerLength &&
    s.split(RegExp(r'\s+')).length <= _maxSpeakerWords &&
    !_sentencePunctuation.hasMatch(s);

/// Paragraphe utile d'un fichier, avec sa position d'origine dans le .docx.
class _Kept {
  const _Kept(this.paragraph, this.info);

  final int paragraph;
  final ParaInfo info;
}

/// Garde les paragraphes qui comptent pour l'alignement FR/EN.
///
/// Les lignes vides et les « --- » sont retirés, sauf le « --- » qui ferme un
/// choix. Ainsi, un « --- » de mise en page présent dans un seul des deux
/// fichiers ne décale pas les répliques suivantes.
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

/// Construit l'histoire à partir des paragraphes FR et EN.
///
/// Les lignes utiles des deux fichiers (voir [_keepMeaningful]) sont mises en
/// correspondance par [alignLines]. La structure (parties, choix) suit le FR.
ParsedStory parseStoryParagraphs({required List<DocParagraph> fr, required List<DocParagraph> en}) {
  final warnings = <ImportWarning>[];
  final untranslated = <EnOnlyLine>[];
  final frOnly = _FrOnlyRuns();
  final keptFr = _keepMeaningful(fr);
  final keptEn = _keepMeaningful(en);
  final pairs = alignLines([for (final k in keptFr) k.info], [for (final k in keptEn) k.info]);
  final b = _Builder(warnings);
  var first = true;

  for (final pair in pairs) {
    if (pair.fr == null) {
      // Ligne EN sans traduction : en général l'interface du jeu.
      final e = keptEn[pair.en!];
      untranslated.add(EnOnlyLine(e.paragraph, e.info.raw));
      continue;
    }

    final i = keptFr[pair.fr!].paragraph;
    if (pair.en != null) frOnly.close(warnings);
    var f = keptFr[pair.fr!].info;
    var e = pair.en == null ? null : keptEn[pair.en!].info;
    if (e == null) {
      frOnly.add(i, f.raw);
      e = const ParaInfo(ParaKind.empty, '');
    }

    // Un titre de partie sans le style « Titre 1 » d'un côté.
    if (e.kind == ParaKind.heading && f.kind == ParaKind.narration && _isShort(f.raw)) {
      f = ParaInfo(ParaKind.heading, f.raw);
    }

    // Réplique d'un côté, narration de l'autre : un nom long (plus de 4 mots)
    // était sans doute le début d'une phrase.
    if (f.kind == ParaKind.narration && e.hasLongSpeaker) e = e.asNarration();
    if (e.kind == ParaKind.narration && f.hasLongSpeaker) f = f.asNarration();

    if (pair.en != null) _checkSameKind(i, f, e, warnings);

    // Le premier « Titre 1 » suivi directement d'un autre « Titre 1 » est le
    // titre de l'histoire, pas une partie.
    if (first) {
      first = false;
      if (f.kind == ParaKind.heading && keptFr.length > 1 && keptFr[1].info.kind == ParaKind.heading) {
        b.setTitle(Bi(f.text, e.raw));
        continue;
      }
    }

    switch (f.kind) {
      case ParaKind.empty:
        break;
      case ParaKind.heading:
        b.startPart(i, Bi(f.text, e.raw));
      case ParaKind.separator:
        b.endChoice();
      case ParaKind.choicePrompt:
        b.startChoice(i, Bi(f.text, e.text));
      case ParaKind.choiceOption:
        b.startOption(i, Bi(f.text, e.text));
      case ParaKind.dialogue || ParaKind.thought || ParaKind.narration:
        b.line(StoryLine(
          paragraph: i,
          kind: switch (f.kind) {
            ParaKind.dialogue => LineKind.dialogue,
            ParaKind.thought => LineKind.thought,
            _ => LineKind.narration,
          },
          speaker: f.speaker == null ? null : Bi(f.speaker!, e.speaker ?? ''),
          text: Bi(f.text, e.text),
        ));
    }
  }

  frOnly.close(warnings);
  return b.finish(paragraphCount: fr.length, untranslated: untranslated);
}

bool _isShort(String s) => s.trim().split(RegExp(r'\s+')).length <= 4;

String _short(String s) => s.length <= 40 ? s : '${s.substring(0, 40)}…';

/// Regroupe les lignes FR sans EN en face en un avertissement par passage.
/// C'est souvent un passage absent de l'EN.docx : ta traduction reste
/// affichée, seule la référence anglaise manque.
class _FrOnlyRuns {
  int? _first;
  int? _last;
  String _firstText = '';
  var _count = 0;

  void add(int paragraph, String text) {
    if (_first == null) {
      _first = paragraph;
      _firstText = text;
    }
    _last = paragraph;
    _count++;
  }

  void close(List<ImportWarning> warnings) {
    if (_first == null) return;
    warnings.add(ImportWarning(
      _first,
      _count == 1
          ? 'Pas de ligne EN en face de « ${_short(_firstText)} ».'
          : "$_count lignes sans EN en face (jusqu'au §$_last), à partir de « ${_short(_firstText)} ».",
    ));
    _first = null;
    _count = 0;
  }
}

/// Signale une différence de structure entre FR et EN (titre, choix, option
/// face à une ligne ordinaire). Une réplique d'un côté et de la narration de
/// l'autre n'est pas signalée : l'EN omet parfois le nom du personnage, et
/// c'est le FR qui fait foi.
void _checkSameKind(int i, ParaInfo f, ParaInfo e, List<ImportWarning> warnings) {
  bool structural(ParaKind k) => !{ParaKind.dialogue, ParaKind.thought, ParaKind.narration}.contains(k);
  if (!structural(f.kind) && !structural(e.kind)) return;
  // Titre de partie sans le style « Titre 1 » dans l'EN : rien à signaler.
  if (f.kind == ParaKind.heading && e.kind == ParaKind.narration && _isShort(e.raw)) return;
  String group(ParaKind k) => switch (k) {
        ParaKind.dialogue || ParaKind.thought => 'réplique',
        ParaKind.narration => 'narration',
        ParaKind.heading => 'titre de partie',
        ParaKind.separator => '« --- »',
        ParaKind.choicePrompt => '« Choix: »',
        ParaKind.choiceOption => 'option de choix',
        ParaKind.empty => 'ligne vide',
      };
  final gf = group(f.kind);
  final ge = group(e.kind);
  if (gf != ge) warnings.add(ImportWarning(i, 'FR : $gf, EN : $ge.'));
}

class _Builder {
  _Builder(this.warnings);

  final List<ImportWarning> warnings;
  final parts = <StoryPart>[];

  Bi title = const Bi('', '');
  String? subtitle;

  int? _partParagraph;
  Bi? _partTitle;
  var _items = <PartItem>[];

  int? _choiceParagraph;
  Bi? _choicePrompt;
  final _options = <ChoiceOption>[];
  int? _optionParagraph;
  Bi? _optionLabel;
  var _optionLines = <StoryLine>[];

  bool get inChoice => _choicePrompt != null;

  void setTitle(Bi raw) {
    final mFr = _titleSuffix.firstMatch(raw.fr);
    final mEn = _titleSuffix.firstMatch(raw.en);
    title = Bi(mFr?.group(1) ?? raw.fr, mEn?.group(1) ?? raw.en);
    subtitle = mFr?.group(2);
  }

  void startPart(int paragraph, Bi partTitle) {
    if (inChoice) {
      warnings.add(ImportWarning(_choiceParagraph, 'Choix sans « --- » de fin avant « ${partTitle.fr} ».'));
      _closeChoice();
    }
    _closePart();
    _partParagraph = paragraph;
    // « *START OF KINDLED* » → « START OF KINDLED ».
    _partTitle = Bi(partTitle.fr, partTitle.en.replaceAll('*', '').trim());
  }

  /// « --- » qui ferme un choix (les autres ont été retirés avant).
  void endChoice() {
    if (inChoice) _closeChoice();
  }

  void startChoice(int paragraph, Bi prompt) {
    if (inChoice) {
      warnings.add(ImportWarning(_choiceParagraph, 'Choix sans « --- » de fin avant le choix suivant.'));
      _closeChoice();
    }
    _ensurePart(paragraph);
    _choiceParagraph = paragraph;
    _choicePrompt = prompt;
  }

  void startOption(int paragraph, Bi label) {
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

  ParsedStory finish({required int paragraphCount, required List<EnOnlyLine> untranslated}) {
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
      untranslated: List.unmodifiable(untranslated),
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
    _partTitle = const Bi('', '');
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
