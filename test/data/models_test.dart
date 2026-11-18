import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:lads_trad/data/models.dart';

void main() {
  group('Character.initial', () {
    Character c(String name) => Character(id: 1, name: name);

    test('première lettre en majuscule', () => expect(c('rafayel').initial, 'R'));
    test('ignore les espaces autour', () => expect(c('  élise ').initial, 'É'));
    test('« ? » pour un nom vide', () => expect(c('   ').initial, '?'));
  });

  group('FolderType', () {
    test('fromCode lit le code stocké', () {
      expect(FolderType.fromCode('secret_time'), FolderType.secretTime);
      expect(FolderType.fromCode('memoria'), FolderType.memoria);
    });

    test('un code inconnu devient « Autre »', () => expect(FolderType.fromCode('???'), FolderType.other));

    test('chaque code se relit', () {
      for (final t in FolderType.values) {
        expect(FolderType.fromCode(t.code), t);
      }
    });
  });

  group('Folder.defaultName', () {
    test('Memoria avec sa rareté', () {
      expect(Folder.defaultName(FolderType.memoria, rarity: 4), 'Memoria 4★');
    });
    test('Memoria sans rareté : 5★', () => expect(Folder.defaultName(FolderType.memoria), 'Memoria 5★'));
    test('les autres types : leur libellé', () {
      expect(Folder.defaultName(FolderType.myths), 'Myths');
      expect(Folder.defaultName(FolderType.other, rarity: 5), 'Autre');
    });
  });

  group('Part.displayTitle', () {
    Part part(String title, {int position = 0}) =>
        Part(id: 1, storyId: 1, position: position, title: title);

    test('un titre en capitales passe en minuscules', () {
      expect(part('ÉPISODE 1').displayTitle, 'Épisode 1');
      expect(part('KINDLED').displayTitle, 'Kindled');
    });
    test('un titre déjà en casse mixte est gardé', () => expect(part('Le Port').displayTitle, 'Le Port'));
    test('sans titre : « Partie n »', () => expect(part('', position: 2).displayTitle, 'Partie 3'));
  });

  group('ImageCrop', () {
    test("maxFrame : le plus grand cadre qui tient dans l'image", () {
      expect(ImageCrop.maxFrame(const Size(400, 300), 1), const Size(300, 300));
      expect(ImageCrop.maxFrame(const Size(300, 1000), coverAspect), const Size(300, 400));
      expect(ImageCrop.maxFrame(const Size(1000, 400), coverAspect), const Size(300, 400));
    });

    test("clampTo ramène le cadre dans l'image", () {
      final c = const ImageCrop(x: 0, y: 1, d: 0.5).clampTo(const Size(100, 100));
      expect(c, const ImageCrop(x: 0.25, y: 0.75, d: 0.5));
    });

    test('clampTo garde une taille entre 0,05 et 1', () {
      expect(const ImageCrop(x: 0.5, y: 0.5, d: 3).clampTo(const Size(10, 10)).d, 1);
      expect(const ImageCrop(x: 0.5, y: 0.5, d: 0).clampTo(const Size(10, 10)).d, 0.05);
    });

    test('clampTo ne touche à rien pour une image vide', () {
      const crop = ImageCrop(x: 2, y: -1, d: 9);
      expect(crop.clampTo(Size.zero), crop);
    });

    test('frameIn donne le cadre en pixels', () {
      expect(
        ImageCrop.character.frameIn(const Size(200, 100)),
        Rect.fromCenter(center: const Offset(100, 50), width: 80, height: 80),
      );
    });
  });
}
