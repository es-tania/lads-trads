/// Gras et italique dans le texte d'une réplique.
///
/// Stockés sous forme de balises `<b>…</b>` et `<i>…</i>` (pas d'astérisques :
/// elles apparaissent dans de vraies répliques). Code pur, partagé par l'app,
/// la fenêtre flottante et l'export.
library;

/// Style d'un caractère : combinaison de [bold] et [italic].
abstract final class Marks {
  static const none = 0;
  static const bold = 1;
  static const italic = 2;
}

/// Morceau de texte d'un même style.
class MarkupSpan {
  const MarkupSpan(this.text, {this.bold = false, this.italic = false});

  final String text;
  final bool bold;
  final bool italic;

  @override
  bool operator ==(Object other) =>
      other is MarkupSpan && other.text == text && other.bold == bold && other.italic == italic;

  @override
  int get hashCode => Object.hash(text, bold, italic);

  @override
  String toString() => '${bold ? 'G' : ''}${italic ? 'I' : ''}«$text»';
}

final _tag = RegExp(r'</?[bi]>');

/// Texte sans balises, et le style de chaque caractère (voir [Marks]).
/// Une balise fermante sans ouvrante est ignorée.
(String, List<int>) parseMarks(String markup) {
  final text = StringBuffer();
  final marks = <int>[];
  var bold = 0;
  var italic = 0;
  var last = 0;
  void addText(String s) {
    text.write(s);
    final m = (bold > 0 ? Marks.bold : 0) | (italic > 0 ? Marks.italic : 0);
    marks.addAll(List.filled(s.length, m));
  }

  for (final match in _tag.allMatches(markup)) {
    addText(markup.substring(last, match.start));
    last = match.end;
    switch (match.group(0)) {
      case '<b>':
        bold++;
      case '</b>':
        if (bold > 0) bold--;
      case '<i>':
        italic++;
      case '</i>':
        if (italic > 0) italic--;
    }
  }
  addText(markup.substring(last));
  return (text.toString(), marks);
}

/// Texte et styles → balises. Le gras englobe l'italique : les caractères
/// gras qui se suivent forment un seul `<b>…</b>`, l'italique est dedans.
String toMarkup(String text, List<int> marks) {
  assert(marks.length == text.length);
  final out = StringBuffer();
  var i = 0;
  while (i < text.length) {
    final bold = marks[i] & Marks.bold != 0;
    var end = i;
    while (end < text.length && (marks[end] & Marks.bold != 0) == bold) {
      end++;
    }
    if (bold) out.write('<b>');
    // Dans ce groupe, les passages en italique.
    var j = i;
    while (j < end) {
      final italic = marks[j] & Marks.italic != 0;
      var k = j;
      while (k < end && (marks[k] & Marks.italic != 0) == italic) {
        k++;
      }
      final part = text.substring(j, k);
      out.write(italic ? '<i>$part</i>' : part);
      j = k;
    }
    if (bold) out.write('</b>');
    i = end;
  }
  return out.toString();
}

/// Morceaux de même style, dans l'ordre.
List<MarkupSpan> markupSpans(String markup) {
  final (text, marks) = parseMarks(markup);
  final spans = <MarkupSpan>[];
  var start = 0;
  for (var i = 1; i <= text.length; i++) {
    if (i == text.length || marks[i] != marks[start]) {
      spans.add(MarkupSpan(
        text.substring(start, i),
        bold: marks[start] & Marks.bold != 0,
        italic: marks[start] & Marks.italic != 0,
      ));
      start = i;
    }
  }
  return spans;
}

/// Le texte tel qu'on le lit, sans balises.
String plainText(String markup) => parseMarks(markup).$1;

/// Vrai si le texte contient du gras ou de l'italique.
bool hasMarks(String markup) => _tag.hasMatch(markup);
