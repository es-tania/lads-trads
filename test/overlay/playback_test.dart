import 'package:flutter_test/flutter_test.dart';
import 'package:lads_trad/overlay/playback.dart';

PlayItem line(String text, [String? speaker]) =>
    PlayItem.line(PlayLine(kind: speaker == null ? 'narration' : 'dialogue', text: text, speaker: speaker));

PlayLine branch(String text) => PlayLine(kind: 'dialogue', text: text, speaker: 'Rafayel');

final story = [
  PlayPart(title: 'ÉPISODE 1', items: [line('a', 'Moi'), line('b')]),
  PlayPart(title: 'KINDLED', items: [
    line('c', 'Rafayel'),
    PlayItem.choice([
      PlayOption(label: 'Réussite !', lines: [branch('bravo')]),
      PlayOption(label: 'Échec…', lines: [branch('dommage'), branch('encore')]),
    ]),
    line('d'),
  ]),
];

void main() {
  test('avance et recule réplique par réplique, d\'une partie à l\'autre', () {
    final p = Playback(story);
    expect(p.current!.line!.text, 'a');
    expect(p.canGoBack, isFalse);
    expect(p.counter, (1, 2));

    p.next();
    expect(p.current!.line!.text, 'b');
    expect(p.counter, (2, 2));

    p.next();
    expect(p.partIndex, 1);
    expect(p.atPartStart, isTrue);
    expect(p.current!.line!.text, 'c');

    p.previous();
    expect(p.partIndex, 0);
    expect(p.current!.line!.text, 'b');
  });

  test('un choix bloque l\'avance jusqu\'à la réponse, puis suit la branche', () {
    final p = Playback(story, part: 1)..next();
    expect(p.current!.isChoice, isTrue);
    expect(p.canGoForward, isFalse);
    expect(p.counter, (1, 3), reason: 'le choix sans réponse compte la première option');

    p.pick(1);
    expect(p.current!.line!.text, 'dommage');
    expect(p.branchLetter, 'B');
    expect(p.counter, (2, 4));

    p.next();
    expect(p.current!.line!.text, 'encore');
    p.next();
    expect(p.current!.line!.text, 'd');
    expect(p.branchLetter, isNull);
    expect(p.canGoForward, isFalse, reason: 'fin de l\'histoire');
  });

  test('revenir sur un choix garde la réponse ; changer de branche l\'oublie', () {
    final p = Playback(story, part: 1)
      ..next()
      ..pick(0);
    expect(p.current!.line!.text, 'bravo');

    p.previous();
    expect(p.current!.isChoice, isTrue);
    expect(p.pickedOption, 0);
    expect(p.canGoForward, isTrue);
    p.next();
    expect(p.current!.line!.text, 'bravo');

    p.changeBranch();
    expect(p.current!.isChoice, isTrue);
    expect(p.pickedOption, isNull);
    p.pick(1);
    expect(p.current!.line!.text, 'dommage');
  });

  test('passe par JSON sans rien perdre', () {
    final copy = [for (final part in story) PlayPart.fromJson(part.toJson())];
    final p = Playback(copy, part: 1)
      ..next()
      ..pick(1);
    expect(p.part.title, 'KINDLED');
    expect(p.current!.line!.speaker, 'Rafayel');
    expect(p.current!.line!.text, 'dommage');
  });
}
