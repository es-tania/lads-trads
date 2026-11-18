import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lads_trad/docx/docx_reader.dart';
import 'package:lads_trad/docx/story_model.dart';
import 'package:lads_trad/docx/story_parser.dart';

DocParagraph p(String text, {bool h1 = false, bool list = false}) =>
    DocParagraph(text: text, isHeading1: h1, isListItem: list);

/// Les vraies histoires de test ne sont pas dans git (voir .gitignore) :
/// sans elles, ces tests sont sautés au lieu d'échouer.
Object _missing(String story) {
  final dir = 'test/fixtures/$story';
  return File('$dir/FR.docx').existsSync() ? false : 'Copier FR.docx dans $dir pour lancer ces tests.';
}

void main() {
  group('Reconnaissance d\'un paragraphe', () {
    test('« Nom : texte » est une réplique', () {
      final info = classifyParagraph(p('Rafayel : Enfin.'));
      expect(info.kind, ParaKind.dialogue);
      expect(info.speaker, 'Rafayel');
      expect(info.text, 'Enfin.');
    });

    test('accepte « Nom: texte » sans espace et les noms avec parenthèse', () {
      expect(classifyParagraph(p('Zephyr: Vite !')).speaker, 'Zephyr');
      final info = classifyParagraph(p('Petite fille (audio uniquement) : Moi aussi !'));
      expect(info.kind, ParaKind.dialogue);
      expect(info.speaker, 'Petite fille (audio uniquement)');
    });

    test('« Moi : (…) » est une pensée', () {
      final info = classifyParagraph(p('Moi : (Je viendrai en vacances !)'));
      expect(info.kind, ParaKind.thought);
      expect(info.speaker, 'Moi');
    });

    test('une phrase avec « : » au milieu reste de la narration', () {
      final info = classifyParagraph(
        p('Nous avons localisé la source des fluctuations magnétiques : il s’agit d’une centrale.'),
      );
      expect(info.kind, ParaKind.narration);
      expect(info.speaker, isNull);
    });

    test('une ligne sans « : » est de la narration', () {
      expect(classifyParagraph(p('Cinq jours plus tard…')).kind, ParaKind.narration);
    });

    test('titres, séparateurs et choix', () {
      expect(classifyParagraph(p('ÉPISODE 1', h1: true)).kind, ParaKind.heading);
      expect(classifyParagraph(p('---')).kind, ParaKind.separator);
      expect(classifyParagraph(p('Choix: ')).kind, ParaKind.choicePrompt);
    });

    test('une puce ou « 01. » n\'est une option qu\'à l\'intérieur d\'un choix', () {
      final bullet = classifyParagraph(p('Réussite !', list: true), inChoice: true);
      expect(bullet.kind, ParaKind.choiceOption);
      expect(bullet.text, 'Réussite !');

      final numbered = classifyParagraph(p('01. Réussite !'), inChoice: true);
      expect(numbered.kind, ParaKind.choiceOption);
      expect(numbered.text, 'Réussite !');

      expect(classifyParagraph(p('01. Réussite !')).kind, ParaKind.narration);
    });

    test('accepte un nom de personnage long', () {
      final info = classifyParagraph(p("Propriétaire de la boutique de vins : On fait comme d'habitude ?"));
      expect(info.kind, ParaKind.dialogue);
      expect(info.speaker, 'Propriétaire de la boutique de vins');
    });

    test('« ?? : » et « ??? : » sont des personnages inconnus', () {
      for (final name in ['?', '??', '???', '？？']) {
        final info = classifyParagraph(p('$name : Qui es-tu ?'));
        expect(info.kind, ParaKind.dialogue, reason: name);
        expect(info.speaker, name);
        expect(info.text, 'Qui es-tu ?');
      }
      expect(classifyParagraph(p('??: (Encore lui…)')).kind, ParaKind.thought);
      // Une vraie phrase avec « ? » avant « : » reste de la narration.
      expect(classifyParagraph(p('Tu viens ? Il me demande : non.')).kind, ParaKind.narration);
    });
  });

  group('Construction de l\'histoire', () {
    test('titre, catégorie, parties, choix et types de lignes', () {
      final s = parseStoryParagraphs([
        p('Into The Canvas (Memoria)', h1: true),
        p('ÉPISODE 1', h1: true),
        p('Rafayel : Salut.'),
        p('Moi : (Il sourit.)'),
        p('Choix:'),
        p('Réussite !', list: true),
        p('Rafayel : Bravo.'),
        p('---'),
        p('Il part.'),
      ]);
      expect(s.warnings, isEmpty);
      expect(s.title, 'Into The Canvas');
      expect(s.subtitle, 'Memoria');
      final part = s.parts.single;
      expect(part.title, 'ÉPISODE 1');
      expect(part.allLines.map((l) => (l.kind, l.speaker, l.text)), [
        (LineKind.dialogue, 'Rafayel', 'Salut.'),
        (LineKind.thought, 'Moi', '(Il sourit.)'),
        (LineKind.dialogue, 'Rafayel', 'Bravo.'),
        (LineKind.narration, null, 'Il part.'),
      ]);
      expect((part.items[2] as Choice).options.single.label, 'Réussite !');
    });

    test('signale un choix sans « --- » de fin', () {
      final story = parseStoryParagraphs([
        p('KINDLED', h1: true),
        p('Choix:'),
        p('A', list: true),
        p('Rafayel : Oui.'),
        p('FIN', h1: true),
        p('Rafayel : Au revoir.'),
      ]);
      expect(story.parts, hasLength(2));
      expect(story.parts.first.items.single, isA<Choice>());
      expect(story.warnings.single.message, contains('sans « --- » de fin'));
    });

    test('reconnaît les titres sans style et les options « 1 – »', () {
      final story = parseStoryParagraphs(
        [p('Chapitre 1'), p('Choix :'), p('1 – Cou'), p('Devin : ...'), p('---'), p('Fin'), p('Il part.')],
      );
      expect(story.warnings, isEmpty);
      expect(story.parts.map((x) => x.title), ['Chapitre 1', 'Fin']);
      final choice = story.parts.first.items.single as Choice;
      expect(choice.options.single.label, 'Cou');
    });

    test('un « --- » hors choix et les lignes vides ne comptent pas', () {
      final story = parseStoryParagraphs(
        [p('ÉPISODE 1', h1: true), p('---'), p('Rafayel : Salut.'), p(''), p('---'), p('Moi : Bonjour.')],
      );
      expect(story.warnings, isEmpty);
      final lines = story.parts.single.allLines.toList();
      expect(lines.map((l) => l.text), ['Salut.', 'Bonjour.']);
      expect(lines.map((l) => l.paragraph), [2, 5], reason: 'numéros de paragraphe du fichier');
    });

    test('le « --- » qui ferme un choix compte toujours', () {
      final story = parseStoryParagraphs(
        [p('KINDLED', h1: true), p('Choix:'), p('A', list: true), p('Rafayel : Oui.'), p('---'), p('Rafayel : Suite.')],
      );
      expect(story.warnings, isEmpty);
      final items = story.parts.single.items;
      expect(items.first, isA<Choice>());
      expect((items.last as StoryLine).text, 'Suite.');
    });
  });

  group('Into The Canvas (vrai fichier)', skip: _missing('into_the_canvas'), () {
    late ParsedStory story;

    setUpAll(() => story = parseStoryDocx(File('test/fixtures/into_the_canvas/FR.docx').readAsBytesSync()));

    test('174 paragraphes et aucun avertissement', () {
      expect(story.paragraphCount, 174);
      expect(story.warnings, isEmpty);
    });

    test('le premier « Titre 1 » donne le titre et la catégorie', () {
      expect(story.title, 'Into The Canvas');
      expect(story.subtitle, 'Memoria');
    });

    test('cinq parties', () {
      expect(story.parts.map((x) => x.title), ['ÉPISODE 1', 'ÉPISODE 2', 'ÉPISODE 3', 'KINDLED', 'FIN']);
      expect(story.parts.map((x) => x.allLines.length), [60, 32, 22, 14, 32]);
    });

    test('répliques, pensées et narration', () {
      final lines = {for (final l in story.parts.expand((x) => x.allLines)) l.paragraph: l};

      expect(lines[3]!.kind, LineKind.narration, reason: 'phrase contenant « : »');
      expect(lines[6]!.kind, LineKind.thought);
      expect(lines[6]!.speaker, 'Moi');

      final l12 = lines[12]!;
      expect(l12.kind, LineKind.dialogue);
      expect(l12.speaker, 'Rafayel');
      expect(l12.text, 'Enfin. Ça fait une éternité que je te regarde.');

      expect(lines[40]!.speaker, 'Petite fille (audio uniquement)');
    });

    test('la partie ÉPISODE 2 enchaîne ses scènes sans le « --- » du milieu', () {
      final ep2 = story.parts[1].items.cast<StoryLine>().map((l) => l.paragraph).toList();
      expect(ep2, containsAllInOrder([79, 81]));
      expect(ep2, isNot(contains(80)));
    });

    test('le choix de KINDLED a deux branches d\'une réplique', () {
      final kindled = story.parts[3];
      final choice = kindled.items.whereType<Choice>().single;
      expect(choice.paragraph, 125);
      expect(choice.options.map((o) => o.label), ['Réussite !', 'Échec…']);
      expect(choice.options.map((o) => o.lines.single.paragraph), [127, 129]);

      // Après le « --- » du paragraphe 130, on reprend le tronc commun.
      final after = kindled.items.skipWhile((i) => i is! Choice).skip(1).first as StoryLine;
      expect(after.paragraph, 131);
    });
  });

  group('Nightly Overflow (vrai fichier)', skip: _missing('nightly_overflow'), () {
    late ParsedStory story;

    setUpAll(() => story = parseStoryDocx(File('test/fixtures/nightly_overflow/FR.docx').readAsBytesSync()));

    test('aucun avertissement et six parties', () {
      expect(story.warnings, isEmpty);
      expect(story.title, 'Nightly Overflow');
      expect(story.parts.map((x) => x.title), ['ÉPISODE 1', 'ÉPISODE 2', 'ÉPISODE 3', 'KINDLED', 'ÉPISODE 4', 'FIN']);
    });

    test('le nom long « Propriétaire de la boutique de vins » est un personnage', () {
      final owner = story.parts.expand((x) => x.allLines).firstWhere((l) => l.paragraph == 166);
      expect(owner.speaker, 'Propriétaire de la boutique de vins');
    });

    test('KINDLED se termine sur « FIN DU KINDLED »', () {
      expect(story.parts[3].allLines.last.text, 'FIN DU KINDLED');
    });
  });
}
