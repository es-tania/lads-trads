import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

/// Personnages proposés au premier lancement, dans l'ordre des onglets.
const defaultCharacters = ['Rafayel', 'Xavier', 'Zayne', 'Sylus', 'Caleb'];

/// Version 2 : image et recadrage des personnages.
/// Version 3 : note de traduction sur chaque ligne (colonne gardée, l'app
/// ne s'en sert plus).
/// Version 4 : cadrage des couvertures.
/// Version 5 : plus d'anglais. Les colonnes `title_en`, `text_en` et
/// `speaker_en` restent, vides : l'app ne les lit ni ne les écrit plus.
const libraryDatabaseVersion = 5;

/// Ouvre (ou crée) la base locale.
///
/// [factory] et [path] sont réglables pour les tests ([inMemoryDatabasePath],
/// avec [singleInstance] à `false` pour repartir d'une base vide).
/// [version] ne sert qu'aux tests de migration.
Future<Database> openLibraryDatabase({
  required DatabaseFactory factory,
  required String path,
  bool singleInstance = true,
  @visibleForTesting int version = libraryDatabaseVersion,
}) {
  return factory.openDatabase(
    path,
    options: OpenDatabaseOptions(
      version: version,
      singleInstance: singleInstance,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      // Une base neuve passe par le même chemin qu'une ancienne : schéma v1,
      // puis chaque migration. Ainsi les deux ne peuvent pas diverger.
      onCreate: (db, version) async {
        await _createV1(db);
        await _upgrade(db, 1, version);
      },
      onUpgrade: _upgrade,
    ),
  );
}

/// Migrations successives, sans perte de données.
Future<void> _upgrade(Database db, int from, int to) async {
  if (from < 2 && to >= 2) {
    // Chemin de l'image dans le stockage de l'app, et cercle de recadrage :
    // centre (fraction de la largeur, de la hauteur) et diamètre (fraction
    // du plus petit côté). NULL : pas encore recadré.
    final batch = db.batch()
      ..execute('ALTER TABLE characters ADD COLUMN image_path TEXT')
      ..execute('ALTER TABLE characters ADD COLUMN crop_x REAL')
      ..execute('ALTER TABLE characters ADD COLUMN crop_y REAL')
      ..execute('ALTER TABLE characters ADD COLUMN crop_d REAL');
    await batch.commit(noResult: true);
  }
  if (from < 3 && to >= 3) {
    // Note de la traductrice, visible seulement en mode admin.
    await db.execute('ALTER TABLE lines ADD COLUMN note TEXT');
  }
  if (from < 4 && to >= 4) {
    // Cadre 3:4 choisi sur la couverture (voir ImageCrop). NULL : le plus
    // grand cadre centré, comme avant.
    final batch = db.batch()
      ..execute('ALTER TABLE stories ADD COLUMN cover_crop_x REAL')
      ..execute('ALTER TABLE stories ADD COLUMN cover_crop_y REAL')
      ..execute('ALTER TABLE stories ADD COLUMN cover_crop_d REAL');
    await batch.commit(noResult: true);
  }
  if (from < 5 && to >= 5) {
    // L'app n'importe plus le texte anglais du jeu : celui déjà importé est
    // effacé, pour qu'il ne soit jamais envoyé en ligne.
    final batch = db.batch()
      ..execute("UPDATE stories SET title_en = ''")
      ..execute("UPDATE parts SET title_en = ''")
      ..execute("UPDATE lines SET text_en = '', speaker_en = NULL");
    await batch.commit(noResult: true);
  }
}

Future<void> _createV1(Database db) async {
  final batch = db.batch()
    ..execute('''
      CREATE TABLE characters (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL UNIQUE,
        position INTEGER NOT NULL
      )''')
    ..execute('''
      CREATE TABLE folders (
        id INTEGER PRIMARY KEY,
        character_id INTEGER NOT NULL REFERENCES characters(id) ON DELETE CASCADE,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        rarity INTEGER,
        created_at INTEGER NOT NULL
      )''')
    ..execute('''
      CREATE TABLE stories (
        id INTEGER PRIMARY KEY,
        folder_id INTEGER NOT NULL REFERENCES folders(id) ON DELETE CASCADE,
        title TEXT NOT NULL,
        title_en TEXT NOT NULL DEFAULT '',
        cover_path TEXT,
        created_at INTEGER NOT NULL
      )''')
    ..execute('''
      CREATE TABLE parts (
        id INTEGER PRIMARY KEY,
        story_id INTEGER NOT NULL REFERENCES stories(id) ON DELETE CASCADE,
        position INTEGER NOT NULL,
        title TEXT NOT NULL,
        title_en TEXT NOT NULL DEFAULT ''
      )''')
    ..execute('''
      CREATE TABLE lines (
        id INTEGER PRIMARY KEY,
        part_id INTEGER NOT NULL REFERENCES parts(id) ON DELETE CASCADE,
        position INTEGER NOT NULL,
        kind TEXT NOT NULL,
        speaker TEXT,
        speaker_en TEXT,
        text TEXT NOT NULL,
        text_en TEXT NOT NULL DEFAULT '',
        parent_id INTEGER REFERENCES lines(id) ON DELETE CASCADE,
        paragraph INTEGER
      )''')
    ..execute('CREATE INDEX folders_character ON folders(character_id)')
    ..execute('CREATE INDEX stories_folder ON stories(folder_id)')
    ..execute('CREATE INDEX parts_story ON parts(story_id, position)')
    ..execute('CREATE INDEX lines_part ON lines(part_id, position)');
  for (final (i, name) in defaultCharacters.indexed) {
    batch.insert('characters', {'name': name, 'position': i});
  }
  await batch.commit(noResult: true);
}
