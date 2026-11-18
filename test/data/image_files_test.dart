import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lads_trad/data/image_files.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory root;
  late ImageFiles images;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('lads_images');
    // Le dossier n'existe pas encore : save le crée.
    images = ImageFiles(Directory(p.join(root.path, 'covers')));
  });

  tearDown(() => root.delete(recursive: true));

  test("save copie l'image avec le préfixe et l'extension en minuscules", () async {
    final path = await images.save(Uint8List.fromList([1, 2, 3]), 'Photo.JPG', prefix: 'story_4');
    expect(p.basename(path), matches(RegExp(r'^story_4_\d+\.jpg$')));
    expect(File(path).readAsBytesSync(), [1, 2, 3]);
  });

  test('sans extension, le fichier est un .png', () async {
    final path = await images.save(Uint8List(1), 'image', prefix: 'character_1');
    expect(p.extension(path), '.png');
  });

  test('delete efface le fichier, et ne dit rien s\'il manque déjà', () async {
    final path = await images.save(Uint8List(1), 'a.png', prefix: 'x');
    await images.delete(path);
    expect(File(path).existsSync(), isFalse);
    await images.delete(path);
    await images.delete(null);
  });
}
