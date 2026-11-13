import 'dart:math';
import 'dart:typed_data';

import 'story_parser.dart';

/// Une case de l'alignement : un indice dans la liste FR, dans la liste EN,
/// ou dans les deux. `null` = pas de ligne en face.
class AlignedPair {
  const AlignedPair(this.fr, this.en);

  final int? fr;
  final int? en;

  @override
  String toString() => '($fr, $en)';
}

/// Met en correspondance les lignes FR et EN, comme un outil de comparaison.
///
/// Les deux fichiers ne sont pas toujours ligne pour ligne : l'EN peut contenir
/// des lignes de l'interface du jeu (« Taste », « *START OF KINDLED* ») qui ne
/// sont pas traduites, ou le FR une ligne ajoutée. On cherche donc l'alignement
/// qui maximise la ressemblance des paires (même personnage, même type de
/// ligne, longueurs proches, textes identiques), en acceptant de laisser des
/// lignes seules quand c'est plus cohérent.
///
/// Algorithme de Needleman-Wunsch avec pénalités affines (Gotoh) : ouvrir un
/// trou coûte plus cher que le prolonger, si bien qu'un passage absent d'un
/// fichier forme un seul trou au lieu d'être éparpillé entre des lignes qui
/// se ressemblent.
List<AlignedPair> alignLines(List<ParaInfo> fr, List<ParaInfo> en) {
  final scorer = _Scorer(fr, en);
  final n = fr.length;
  final m = en.length;
  final width = m + 1;

  // Trois états : _pair (les deux lignes appariées), _frGap (ligne FR seule),
  // _enGap (ligne EN seule). On garde deux rangées de scores par état, et
  // pour chaque case l'état précédent de chacun des trois (2 bits chacun).
  var prev = [for (var s = 0; s < 3; s++) Int32List(width)];
  var cur = [for (var s = 0; s < 3; s++) Int32List(width)];
  final from = Uint8List((n + 1) * width);

  void initRow(List<Int32List> row, int i) {
    for (var j = 0; j <= m; j++) {
      row[_pair][j] = (i == 0 && j == 0) ? 0 : _minusInf;
      row[_frGap][j] = (i > 0 && j == 0) ? _frOpen + (i - 1) * _frExtend : _minusInf;
      row[_enGap][j] = (i == 0 && j > 0) ? _enOpen + (j - 1) * _enExtend : _minusInf;
    }
  }

  initRow(prev, 0);
  for (var j = 1; j <= m; j++) {
    from[j] = (j == 1 ? _pair : _enGap) << (2 * _enGap);
  }

  for (var i = 1; i <= n; i++) {
    initRow(cur, i);
    from[i * width] = (i == 1 ? _pair : _frGap) << (2 * _frGap);
    for (var j = 1; j <= m; j++) {
      final cell = i * width + j;
      var bits = 0;

      // Paire : on vient de la case en diagonale, depuis n'importe quel état.
      final (pBest, pFrom) = _best3(prev[_pair][j - 1], prev[_frGap][j - 1], prev[_enGap][j - 1]);
      cur[_pair][j] = pBest + scorer.pair(i - 1, j - 1);
      bits |= pFrom << (2 * _pair);

      // Ligne FR seule : on vient de la case du dessus.
      final (fBest, fFrom) = _best3(
        prev[_pair][j] + _frOpen,
        prev[_frGap][j] + _frExtend,
        prev[_enGap][j] + _frOpen,
      );
      cur[_frGap][j] = fBest;
      bits |= fFrom << (2 * _frGap);

      // Ligne EN seule : on vient de la case de gauche.
      final (eBest, eFrom) = _best3(
        cur[_pair][j - 1] + _enOpen,
        cur[_frGap][j - 1] + _enOpen,
        cur[_enGap][j - 1] + _enExtend,
      );
      cur[_enGap][j] = eBest;
      bits |= eFrom << (2 * _enGap);

      from[cell] = bits;
    }
    final swap = prev;
    prev = cur;
    cur = swap;
  }

  // Remontée depuis le meilleur état de la dernière case.
  var (_, state) = _best3(prev[_pair][m], prev[_frGap][m], prev[_enGap][m]);
  final path = <AlignedPair>[];
  var i = n;
  var j = m;
  while (i > 0 || j > 0) {
    final previous = (from[i * width + j] >> (2 * state)) & 3;
    switch (state) {
      case _pair:
        path.add(AlignedPair(--i, --j));
      case _frGap:
        path.add(AlignedPair(--i, null));
      default:
        path.add(AlignedPair(null, --j));
    }
    state = previous;
  }
  return path.reversed.toList();
}

const _pair = 0;
const _frGap = 1;
const _enGap = 2;
const _minusInf = -1 << 28;

/// Meilleur des trois scores, avec son état. À égalité : paire d'abord.
(int, int) _best3(int pair, int frGap, int enGap) {
  if (pair >= frGap && pair >= enGap) return (pair, _pair);
  if (enGap >= frGap) return (enGap, _enGap);
  return (frGap, _frGap);
}

/// Coût d'un trou : ouverture, puis chaque ligne en plus. Une ligne FR sans EN
/// est plus suspecte qu'une ligne EN sans FR (interface du jeu non traduite).
const _frOpen = -5;
const _frExtend = -2;
const _enOpen = -4;
const _enExtend = -1;

final _nonWord = RegExp(r'[^\p{L}\p{N}?!]+', unicode: true);

String _norm(String s) => s.toLowerCase().replaceAll(_nonWord, '');

bool _isStructure(ParaKind k) =>
    k == ParaKind.heading || k == ParaKind.choicePrompt || k == ParaKind.choiceOption || k == ParaKind.separator;

bool _isSpoken(ParaKind k) => k == ParaKind.dialogue || k == ParaKind.thought;

/// Ressemblance d'une ligne FR et d'une ligne EN.
class _Scorer {
  _Scorer(this.fr, this.en)
      : normFr = [for (final f in fr) _norm(f.raw)],
        normEn = [for (final e in en) _norm(e.raw)] {
    final speakersFr = {for (final f in fr) if (f.speaker != null) _norm(f.speaker!)};
    final speakersEn = {for (final e in en) if (e.speaker != null) _norm(e.speaker!)};
    // Noms écrits pareil dans les deux langues (Rafayel, Zayne…), plus Moi/Me.
    known = speakersFr.intersection(speakersEn)..addAll(['moi', 'me']);
  }

  final List<ParaInfo> fr;
  final List<ParaInfo> en;
  final List<String> normFr;
  final List<String> normEn;
  late final Set<String> known;

  int pair(int i, int j) {
    final f = fr[i];
    final e = en[j];
    // Textes identiques : noms propres, « KINDLED », « ?! », titre de l'histoire…
    if (normFr[i].isNotEmpty && normFr[i] == normEn[j]) return 8;

    switch (f.kind) {
      case ParaKind.heading:
        if (e.kind == ParaKind.heading) return 6;
        // Titre sans style ni forme reconnue dans l'EN : ligne courte de narration.
        if (e.kind == ParaKind.narration && _wordCount(e.raw) <= 4) return 4;
        return -4;
      case ParaKind.choicePrompt:
        return e.kind == ParaKind.choicePrompt ? 8 : -6;
      case ParaKind.choiceOption:
        return e.kind == ParaKind.choiceOption ? 5 : -3;
      case ParaKind.separator:
        return e.kind == ParaKind.separator ? 6 : -6;
      default:
        break;
    }
    if (_isStructure(e.kind)) {
      if (e.kind == ParaKind.heading && f.kind == ParaKind.narration && _wordCount(f.raw) <= 4) return 4;
      return -6;
    }

    final length = _lengthScore(f.text, e.text);
    if (_isSpoken(f.kind) && _isSpoken(e.kind)) return 2 + _speakerScore(f.speaker!, e.speaker!) + length;
    if (f.kind == ParaKind.narration && e.kind == ParaKind.narration) return 2 + length;
    // Réplique d'un côté, narration de l'autre : possible si un nom de
    // personnage n'a pas été reconnu, mais peu probable.
    return -1 + length;
  }

  /// +3 pour le même personnage ; -3 pour deux personnages connus et
  /// différents (Zayne face à Moi) ; 0 si on ne peut pas savoir (un nom
  /// traduit, comme Devin / Foreseer).
  int _speakerScore(String fr, String en) {
    if (sameSpeaker(fr, en)) return 3;
    return known.contains(_norm(fr)) && known.contains(_norm(en)) ? -3 : 0;
  }
}

/// Le français est en général 10 à 20 % plus long que l'anglais : on note
/// de +3 (longueurs cohérentes) à -4 (l'une fait plus du double de l'autre).
int _lengthScore(String fr, String en) {
  final ratio = (fr.length + 10) / (en.length + 10) / 1.15;
  final distance = (log(ratio)).abs();
  return (3 - 7 * distance).round().clamp(-4, 3);
}

int _wordCount(String s) => s.trim().split(RegExp(r'\s+')).length;

const _sameSpeakers = {
  'moi': 'me',
};

/// Même personnage en FR et en EN (« Rafayel » / « Rafayel », « Moi » / « Me »).
bool sameSpeaker(String? fr, String? en) {
  if (fr == null || en == null) return false;
  final f = _norm(fr);
  final e = _norm(en);
  return f == e || _sameSpeakers[f] == e;
}
