import 'package:flutter_test/flutter_test.dart';
import 'package:lads_trad/data/models.dart';
import 'package:lads_trad/screens/admin/folder_choice.dart';

void main() {
  group('FolderChoice.key', () {
    test('un dossier existant : son identifiant', () {
      const a = FolderChoice(id: 7, name: 'A', type: FolderType.myths);
      const b = FolderChoice(id: 7, name: 'B', type: FolderType.other);
      expect(a.key, b.key);
    });

    test('un dossier à créer : son type et sa rareté', () {
      const five = FolderChoice(name: 'Memoria 5★', type: FolderType.memoria, rarity: 5);
      const four = FolderChoice(name: 'Memoria 5★', type: FolderType.memoria, rarity: 4);
      expect(five.key, isNot(four.key));
      expect(five.key, const FolderChoice(name: 'autre nom', type: FolderType.memoria, rarity: 5).key);
    });

    test('existant et à créer ne se confondent pas', () {
      const existing = FolderChoice(id: 1, name: 'Myths', type: FolderType.myths);
      expect(existing.key, isNot(existing.asNew.key));
    });
  });

  test('asNew garde le type avec le nom par défaut', () {
    const renamed = FolderChoice(id: 3, name: 'Mes préférées', type: FolderType.memoria, rarity: 4);
    final fresh = renamed.asNew;
    expect(fresh.id, isNull);
    expect(fresh.name, 'Memoria 4★');
    expect(fresh.type, FolderType.memoria);
    expect(fresh.rarity, 4);
  });

  group('folderChoices', () {
    test('sans dossier : les cinq types par défaut', () {
      expect(folderChoices(const []).map((c) => c.name), [
        'Memoria 5★',
        'Memoria 4★',
        'Myths',
        'Secret Time',
        'Tender Moment',
      ]);
    });

    test("les dossiers existants d'abord, puis les types qui manquent", () {
      const folders = [
        Folder(id: 1, characterId: 1, name: 'À relire', type: FolderType.other),
        Folder(id: 2, characterId: 1, name: 'Mes Memoria', type: FolderType.memoria, rarity: 5),
      ];
      final choices = folderChoices(folders);
      expect(
        choices.map((c) => c.name),
        ['À relire', 'Mes Memoria', 'Memoria 4★', 'Myths', 'Secret Time', 'Tender Moment'],
      );
      expect(choices.take(2).map((c) => c.id), [1, 2]);
      expect(choices.skip(2).every((c) => c.id == null), isTrue);
    });
  });
}
