import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lads_trad/data/database.dart';
import 'package:lads_trad/data/library_repository.dart';
import 'package:lads_trad/data/models.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  late Directory dir;

  setUp(() async => dir = await Directory.systemTemp.createTemp('lads_db'));
  tearDown(() => dir.delete(recursive: true));

  test('les migrations depuis la v1 gardent les données (image, recadrage, note)', () async {
    final path = p.join(dir.path, 'lads_trad.db');

    // Base telle qu'elle existe sur le téléphone avant l'étape 5a.
    final v1 = await openLibraryDatabase(factory: databaseFactoryFfi, path: path, singleInstance: false, version: 1);
    final rafayel = (await v1.query('characters', where: 'name = ?', whereArgs: ['Rafayel'])).single['id']! as int;
    final folder = await v1.insert('folders', {
      'character_id': rafayel,
      'name': 'Memoria 5★',
      'type': 'memoria',
      'rarity': 5,
      'created_at': 1,
    });
    await v1.insert('stories', {'folder_id': folder, 'title': 'Into The Canvas', 'created_at': 2});
    final columnsV1 = (await v1.rawQuery('PRAGMA table_info(characters)')).map((c) => c['name']);
    expect(columnsV1, isNot(contains('image_path')));
    await v1.close();

    final v2 = await openLibraryDatabase(factory: databaseFactoryFfi, path: path, singleInstance: false);
    expect(await v2.getVersion(), libraryDatabaseVersion);
    final columns = (await v2.rawQuery('PRAGMA table_info(characters)')).map((c) => c['name']);
    expect(columns, containsAll(['image_path', 'crop_x', 'crop_y', 'crop_d']));
    final lineColumns = (await v2.rawQuery('PRAGMA table_info(lines)')).map((c) => c['name']);
    expect(lineColumns, contains('note'));
    final storyColumns = (await v2.rawQuery('PRAGMA table_info(stories)')).map((c) => c['name']);
    expect(storyColumns, containsAll(['cover_crop_x', 'cover_crop_y', 'cover_crop_d']));

    final repo = LibraryRepository(v2, coversDir: Directory(p.join(dir.path, 'covers')));
    final characters = await repo.characters();
    expect(characters.map((c) => c.name), defaultCharacters);
    expect(characters.every((c) => c.imagePath == null && c.crop == null), isTrue);
    final folders = await repo.folders(rafayel);
    expect(folders.single.name, 'Memoria 5★');
    expect(folders.single.storyCount, 1);
    expect((await repo.stories(folder)).single.title, 'Into The Canvas');

    await repo.setImageCrop(rafayel, const ImageCrop(x: 0.4, y: 0.3, d: 0.5));
    expect((await repo.characters()).first.crop, const ImageCrop(x: 0.4, y: 0.3, d: 0.5));
    await v2.close();
  });
}
