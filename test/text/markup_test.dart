import 'package:flutter_test/flutter_test.dart';
import 'package:lads_trad/text/markup.dart';

void main() {
  test('lit les balises en texte et styles', () {
    final (text, marks) = parseMarks('Un <b>mot</b> et <i>un autre</i>.');
    expect(text, 'Un mot et un autre.');
    expect(marks.sublist(3, 6), [Marks.bold, Marks.bold, Marks.bold]);
    expect(marks[2], Marks.none);
    expect(marks.sublist(10, 18).toSet(), {Marks.italic});
  });

  test('gras et italique imbriqués, dans les deux sens', () {
    expect(markupSpans('<b>a<i>b</i></b>c'), const [
      MarkupSpan('a', bold: true),
      MarkupSpan('b', bold: true, italic: true),
      MarkupSpan('c'),
    ]);
    expect(markupSpans('<i>a<b>b</b></i>'), const [
      MarkupSpan('a', italic: true),
      MarkupSpan('b', bold: true, italic: true),
    ]);
  });

  test('une balise isolée ou inconnue reste du texte lisible', () {
    expect(plainText('a</b>b'), 'ab');
    expect(plainText('2 < 3 et <u>x</u>'), '2 < 3 et <u>x</u>');
    expect(hasMarks('Il sourit.'), isFalse);
  });

  test("l'écriture des balises redonne exactement les mêmes styles", () {
    const samples = [
      'Simple.',
      'Un <b>mot</b> et <i>un autre</i>.',
      '<b>a<i>b</i></b>c',
      '<i>a</i><b><i>b</i>c</b>',
      '<b>tout</b>',
      'x<i>y</i>',
    ];
    for (final s in samples) {
      final (text, marks) = parseMarks(s);
      final (text2, marks2) = parseMarks(toMarkup(text, marks));
      expect(text2, text, reason: s);
      expect(marks2, marks, reason: s);
    }
    expect(toMarkup('abc', [Marks.none, Marks.bold, Marks.none]), 'a<b>b</b>c');
    expect(toMarkup('ab', [Marks.bold | Marks.italic, Marks.bold]), '<b><i>a</i>b</b>');
    expect(toMarkup('ab', [Marks.italic, Marks.bold | Marks.italic]), '<i>a</i><b><i>b</i></b>');
  });
}
