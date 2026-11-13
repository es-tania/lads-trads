import 'package:material_ui/material_ui.dart';

import 'screens/admin/characters_screen.dart';
import 'screens/admin/edit_line_screen.dart';
import 'screens/admin/editor_screen.dart';
import 'screens/admin/export_screen.dart';
import 'screens/admin/import_screen.dart';
import 'screens/admin/new_folder_screen.dart';
import 'screens/admin/story_admin_screen.dart';
import 'screens/folder_screen.dart';
import 'screens/library_screen.dart';
import 'screens/search_screen.dart';
import 'screens/story_screen.dart';
import 'theme/ink.dart';

/// Noms des routes. Les écrans admin portent le préfixe /admin.
///
/// Arguments : [folder] et [story] attendent un identifiant (int),
/// [import] un identifiant de personnage facultatif.
abstract final class Routes {
  static const library = '/';
  static const search = '/recherche';
  static const folder = '/dossier';
  static const story = '/histoire';

  static const import = '/admin/import';
  static const storyAdmin = '/admin/fiche';
  static const newFolder = '/admin/nouveau-dossier';
  static const editor = '/admin/editeur';
  static const editLine = '/admin/replique';
  static const export = '/admin/export';
  static const characters = '/admin/personnages';

  /// Écrans qui s'ouvrent comme une fenêtre (croix en haut à gauche).
  static const _modals = {newFolder, editLine, export};
}

class LadsTradApp extends StatelessWidget {
  const LadsTradApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LADS Trad',
      debugShowCheckedModeBanner: false,
      theme: InkTheme.dark,
      darkTheme: InkTheme.dark,
      themeMode: ThemeMode.dark,
      initialRoute: Routes.library,
      onGenerateRoute: _onGenerateRoute,
    );
  }

  static Route<void> _onGenerateRoute(RouteSettings settings) {
    final arg = settings.arguments;
    final Widget page = switch (settings.name) {
      Routes.search => const SearchScreen(),
      Routes.folder => FolderScreen(folderId: arg! as int),
      Routes.story => StoryScreen(storyId: arg! as int),
      Routes.import => ImportScreen(characterId: arg as int?),
      Routes.storyAdmin => StoryAdminScreen(storyId: arg! as int),
      Routes.newFolder => NewFolderScreen(editing: arg as String?),
      Routes.editor => const EditorScreen(),
      Routes.editLine => const EditLineScreen(),
      Routes.export => const ExportScreen(),
      Routes.characters => const CharactersScreen(),
      _ => const LibraryScreen(),
    };
    return MaterialPageRoute<void>(
      settings: settings,
      fullscreenDialog: Routes._modals.contains(settings.name),
      builder: (_) => page,
    );
  }
}
