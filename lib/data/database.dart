import 'package:sqflite/sqflite.dart';

/// Personnages proposés au premier lancement, dans l'ordre des onglets.
const defaultCharacters = ['Rafayel', 'Xavier', 'Zayne', 'Sylus', 'Caleb'];

const _version = 1;

/// Ouvre (ou crée) la base locale.
///
/// [factory] et [path] sont réglables pour les tests ([inMemoryDatabasePath],
/// avec [singleInstance] à `false` pour repartir d'une base vide).
Future<Database> openLibraryDatabase({
  required DatabaseFactory factory,
  required String path,
  bool singleInstance = true,
}) {
  return factory.openDatabase(
    path,
    options: OpenDatabaseOptions(
      version: _version,
      singleInstance: singleInstance,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: _create,
    ),
  );
}

Future<void> _create(Database db, int version) async {
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
