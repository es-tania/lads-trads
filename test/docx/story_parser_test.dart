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
  final ok = File('$dir/FR.docx').existsSync() && File('$dir/EN.docx').existsSync();
  return ok ? false : 'Copier FR.docx et EN.docx dans $dir pour lancer ces tests.';
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
      expect(classifyParagraph(p('Choices :')).kind, ParaKind.choicePrompt);
    });

    test('une puce ou « 01. » n\'est une option qu\'à l\'intérieur d\'un choix', () {
      final fr = classifyParagraph(p('Réussite !', list: true), inChoice: true);
      expect(fr.kind, ParaKind.choiceOption);
      expect(fr.text, 'Réussite !');

      final en = classifyParagraph(p('01. Success!'), inChoice: true);
      expect(en.kind, ParaKind.choiceOption);
      expect(en.text, 'Success!');

      expect(classifyParagraph(p('01. Success!')).kind, ParaKind.narration);
    });
  });

  group('Construction de l\'histoire', () {
    test('signale un choix sans « --- » de fin', () {
      final paras = [
        p('KINDLED', h1: true),
        p('Choix:'),
        p('A', list: true),
        p('Rafayel : Oui.'),
        p('FIN', h1: true),
        p('Rafayel : Au revoir.'),
      ];
      final story = parseStoryParagraphs(fr: paras, en: paras);
      expect(story.parts, hasLength(2));
      expect(story.parts.first.items.single, isA<Choice>());
      expect(story.warnings.single.message, contains('sans « --- » de fin'));
    });

    test('regroupe un passage FR sans EN en un seul avertissement', () {
      final story = parseStoryParagraphs(
        fr: [
          p('ÉPISODE 1', h1: true),
          p('Rafayel : Salut.'),
          p('Moi : Ça va ?'),
          p('Rafayel : Très bien, et toi, tu as passé une bonne journée ?'),
          p('Moi : Oui.'),
          p('Il sourit.'),
        ],
        en: [p('EPISODE 1', h1: true), p('Rafayel : Hi.'), p('He smiles.')],
      );
      expect(story.warnings, hasLength(1));
      expect(story.warnings.single.paragraph, 2);
      expect(story.warnings.single.message, startsWith('3 lignes sans EN'));
      expect(story.parts.single.allLines.last.text.en, 'He smiles.');
    });

    test("met de côté les lignes de l'interface du jeu absentes du FR", () {
      final story = parseStoryParagraphs(
        fr: [p('KINDLED', h1: true), p("Moi : C'est amer…"), p('Rafayel : Le souvenir est un ingrédient.'), p('FIN DU KINDLED')],
        en: [
          p('*START OF KINDLED*'),
          p('Me : It tastes bitter...'),
          p('Taste'),
          p('Rafayel : Memory is an ingredient.'),
          p('Shake your phone or swipe to mix drinks with Rafayel!'),
          p('*END OF KINDLED*'),
        ],
      );
      expect(story.warnings, isEmpty);
      expect(story.untranslated.map((l) => l.text), ['Taste', 'Shake your phone or swipe to mix drinks with Rafayel!']);
      expect(story.parts.single.title.en, 'START OF KINDLED');
      expect(story.parts.single.allLines.map((l) => l.text.en), ['It tastes bitter...', 'Memory is an ingredient.', '*END OF KINDLED*']);
    });

    test('reconnaît les titres sans style et les options « 1 – »', () {
      final story = parseStoryParagraphs(
        fr: [p('Chapitre 1'), p('Choix :'), p('1 – Cou'), p('Devin : ...'), p('---'), p('Fin'), p('Il part.')],
        en: [p('Episode 1'), p('Choices :'), p('1 – Neck'), p('Foreseer : ...'), p('---'), p('End'), p('He leaves.')],
      );
      expect(story.warnings, isEmpty);
      expect(story.parts.map((x) => x.title.fr), ['Chapitre 1', 'Fin']);
      final choice = story.parts.first.items.single as Choice;
      expect(choice.options.single.label.fr, 'Cou');
      expect(choice.options.single.label.en, 'Neck');
    });

    test('accepte un nom de personnage long', () {
      final info = classifyParagraph(p("Propriétaire de la boutique de vins : On fait comme d'habitude ?"));
      expect(info.kind, ParaKind.dialogue);
      expect(info.speaker, 'Propriétaire de la boutique de vins');
    });

    test('un « --- » hors choix présent d\'un seul côté ne décale rien', () {
      final story = parseStoryParagraphs(
        fr: [p('ÉPISODE 1', h1: true), p('Rafayel : Salut.'), p('Moi : Bonjour.')],
        en: [p('EPISODE 1', h1: true), p('---'), p('Rafayel : Hi.'), p(''), p('---'), p('Me : Hello.')],
      );
      expect(story.warnings, isEmpty);
      final lines = story.parts.single.allLines.toList();
      expect(lines.map((l) => l.text.en), ['Hi.', 'Hello.']);
      expect(lines.map((l) => l.paragraph), [1, 2], reason: 'numéros de paragraphe du FR');
    });

    test('le « --- » qui ferme un choix compte toujours', () {
      final fr = [p('KINDLED', h1: true), p('Choix:'), p('A', list: true), p('Rafayel : Oui.'), p('---'), p('Rafayel : Suite.')];
      final en = [p('KINDLED', h1: true), p('Choices :'), p('01. A'), p('Rafayel : Yes.'), p('---'), p('---'), p('Rafayel : Next.')];
      final story = parseStoryParagraphs(fr: fr, en: en);
      expect(story.warnings, isEmpty);
      final items = story.parts.single.items;
      expect(items.first, isA<Choice>());
      expect((items.last as StoryLine).text.en, 'Next.');
    });

    test("ne signale pas un nom de personnage absent de l'EN", () {
      final story = parseStoryParagraphs(
        fr: [p('ÉPISODE 1', h1: true), p('Rafayel : … Hein ?')],
        en: [p('EPISODE 1', h1: true), p('...Huh?')],
      );
      expect(story.warnings, isEmpty);
      expect(story.parts.single.allLines.single.speaker!.fr, 'Rafayel');
    });
  });

  group('Into The Canvas (vrais fichiers)', skip: _missing('into_the_canvas'), () {
    late ParsedStory story;

    setUpAll(() {
      const dir = 'test/fixtures/into_the_canvas';
      story = parseStoryDocx(
        fr: File('$dir/FR.docx').readAsBytesSync(),
        en: File('$dir/EN.docx').readAsBytesSync(),
      );
    });

    test('les deux fichiers ont 174 paragraphes et aucun avertissement', () {
      expect(readDocxParagraphs(File('test/fixtures/into_the_canvas/FR.docx').readAsBytesSync()), hasLength(174));
      expect(readDocxParagraphs(File('test/fixtures/into_the_canvas/EN.docx').readAsBytesSync()), hasLength(174));
      expect(story.paragraphCount, 174);
      expect(story.warnings, isEmpty);
    });

    test('le premier « Titre 1 » donne le titre et la catégorie', () {
      expect(story.title.fr, 'Into The Canvas');
      expect(story.title.en, 'Into The Canvas');
      expect(story.subtitle, 'Memoria');
    });

    test('cinq parties, titres FR et EN', () {
      expect(story.parts.map((x) => x.title.fr), ['ÉPISODE 1', 'ÉPISODE 2', 'ÉPISODE 3', 'KINDLED', 'FIN']);
      expect(story.parts.map((x) => x.title.en), ['EPISODE 1', 'EPISODE 2', 'EPISODE 3', 'KINDLED', 'THE END']);
      expect(story.parts.map((x) => x.allLines.length), [60, 32, 22, 14, 32]);
    });

    test('répliques, pensées et narration', () {
      final lines = {for (final l in story.parts.expand((x) => x.allLines)) l.paragraph: l};

      expect(lines[3]!.kind, LineKind.narration, reason: 'phrase contenant « : »');
      expect(lines[6]!.kind, LineKind.thought);
      expect(lines[6]!.speaker!.fr, 'Moi');
      expect(lines[6]!.speaker!.en, 'Me');

      final l12 = lines[12]!;
      expect(l12.kind, LineKind.dialogue);
      expect(l12.speaker!.fr, 'Rafayel');
      expect(l12.text.fr, 'Enfin. Ça fait une éternité que je te regarde.');
      expect(l12.text.en, 'Finally. I\'ve been looking at you since like forever.');

      expect(lines[40]!.speaker!.fr, 'Petite fille (audio uniquement)');
      expect(lines[40]!.speaker!.en, 'Little Girl (Audio Only)');
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
      expect(choice.options.map((o) => o.label.fr), ['Réussite !', 'Échec…']);
      expect(choice.options.map((o) => o.label.en), ['Success!', 'Failure...']);
      expect(choice.options.map((o) => o.lines.single.paragraph), [127, 129]);

      // Après le « --- » du paragraphe 130, on reprend le tronc commun.
      final after = kindled.items.skipWhile((i) => i is! Choice).skip(1).first as StoryLine;
      expect(after.paragraph, 131);
    });
  });

  group('Nightly Overflow (vrais fichiers : titres EN sans style, interface du jeu)', skip: _missing('nightly_overflow'), () {
    late ParsedStory story;

    setUpAll(() {
      const dir = 'test/fixtures/nightly_overflow';
      story = parseStoryDocx(
        fr: File('$dir/FR.docx').readAsBytesSync(),
        en: File('$dir/EN.docx').readAsBytesSync(),
      );
    });

    test('aucun avertissement et six parties', () {
      expect(story.warnings, isEmpty);
      expect(story.title.fr, 'Nightly Overflow');
      expect(story.parts.map((x) => x.title.fr), ['ÉPISODE 1', 'ÉPISODE 2', 'ÉPISODE 3', 'KINDLED', 'ÉPISODE 4', 'FIN']);
      expect(story.parts[1].title.en, 'EPISODE 2');
    });

    test('les sept lignes d’interface de KINDLED sont mises de côté', () {
      expect(story.untranslated.map((l) => l.text), [
        'KINDLED',
        '*KINDLED CONTINUED...*',
        'Taste',
        'Shake your phone or swipe to mix drinks with Rafayel!',
        'Done',
        'Taste',
        'Wait',
      ]);
    });

    test('le nom long « Propriétaire de la boutique de vins » est un personnage', () {
      final owner = story.parts.expand((x) => x.allLines).firstWhere((l) => l.paragraph == 166);
      expect(owner.speaker!.fr, 'Propriétaire de la boutique de vins');
      expect(owner.speaker!.en, 'Wine Shop Owner');
    });

    test('KINDLED reste aligné après les lignes d’interface', () {
      final kindled = story.parts[3].allLines.toList();
      expect(kindled.first.text.en, 'Do you always do this when you make drinks?');
      expect(kindled.last.text.fr, 'FIN DU KINDLED');
    });
  });

  test("sans EN.docx, l'histoire n'a que le français, sans avertissement", () {
    final fr = [
      p('Into The Canvas (Memoria)', h1: true),
      p('ÉPISODE 1', h1: true),
      p('Rafayel : Salut.'),
      p('Moi : (Il sourit.)'),
      p('Choix:'),
      p('Réussite !', list: true),
      p('Rafayel : Bravo.'),
      p('---'),
      p('Il part.'),
    ];
    final s = parseStoryParagraphs(fr: fr);
    expect(s.warnings, isEmpty);
    expect(s.title.fr, 'Into The Canvas');
    expect(s.title.en, isEmpty);
    expect(s.subtitle, 'Memoria');
    final part = s.parts.single;
    expect(part.title.fr, 'ÉPISODE 1');
    expect(part.allLines.map((l) => (l.kind, l.speaker?.fr, l.text.fr, l.text.en)), [
      (LineKind.dialogue, 'Rafayel', 'Salut.', ''),
      (LineKind.thought, 'Moi', '(Il sourit.)', ''),
      (LineKind.dialogue, 'Rafayel', 'Bravo.', ''),
      (LineKind.narration, null, 'Il part.', ''),
    ]);
    expect((part.items[2] as Choice).options.single.label.fr, 'Réussite !');
  });
}
