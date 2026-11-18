import 'package:flutter_test/flutter_test.dart';
import 'package:lads_trad/docx/aligner.dart';
import 'package:lads_trad/docx/story_parser.dart';

ParaInfo say(String speaker, String text) => ParaInfo(ParaKind.dialogue, text, speaker: speaker);
ParaInfo narr(String text) => ParaInfo(ParaKind.narration, text);

Iterable<(int?, int?)> pairs(List<AlignedPair> aligned) => aligned.map((p) => (p.fr, p.en));

void main() {
  group('sameSpeaker', () {
    test('même nom, sans tenir compte de la casse ni de la ponctuation', () {
      expect(sameSpeaker('Rafayel', 'rafayel'), isTrue);
      expect(sameSpeaker('Rafayel :', 'Rafayel'), isTrue);
    });
    test('« Moi » est « Me » en anglais', () => expect(sameSpeaker('Moi', 'Me'), isTrue));
    test('deux personnages différents', () => expect(sameSpeaker('Rafayel', 'Me'), isFalse));
    test('un nom absent ne correspond à rien', () {
      expect(sameSpeaker(null, 'Me'), isFalse);
      expect(sameSpeaker('Moi', null), isFalse);
    });
  });

  group('alignLines', () {
    test('ligne pour ligne quand les deux fichiers se suivent', () {
      final fr = [say('Moi', 'Bonjour.'), say('Rafayel', 'Te voilà enfin.'), narr('Il sourit.')];
      final en = [say('Me', 'Hello.'), say('Rafayel', 'There you are.'), narr('He smiles.')];
      expect(pairs(alignLines(fr, en)), [(0, 0), (1, 1), (2, 2)]);
    });

    test("une ligne d'interface en anglais reste seule", () {
      final fr = [say('Moi', 'Bonjour.'), say('Rafayel', 'Te voilà enfin.')];
      final en = [say('Me', 'Hello.'), narr('Taste'), say('Rafayel', 'There you are.')];
      expect(pairs(alignLines(fr, en)), [(0, 0), (null, 1), (1, 2)]);
    });

    test('une ligne ajoutée en français reste seule', () {
      final fr = [say('Moi', 'Bonjour.'), narr('(Note de traduction)'), say('Rafayel', 'Te voilà.')];
      final en = [say('Me', 'Hello.'), say('Rafayel', 'There you are.')];
      expect(pairs(alignLines(fr, en)), [(0, 0), (1, null), (2, 1)]);
    });

    test('listes vides ou sans vis-à-vis', () {
      expect(alignLines(const [], const []), isEmpty);
      expect(pairs(alignLines([narr('Seule')], const [])), [(0, null)]);
    });
  });
}
