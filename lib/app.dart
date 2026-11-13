import 'package:material_ui/material_ui.dart';

import 'screens/admin/characters_screen.dart';
import 'screens/admin/editor_screen.dart';
import 'screens/admin/export_screen.dart';
import 'screens/admin/import_screen.dart';
import 'screens/admin/story_admin_screen.dart';
import 'screens/folder_screen.dart';
import 'screens/library_screen.dart';
import 'screens/search_screen.dart';
import 'screens/story_screen.dart';
import 'theme/ink.dart';

/// Noms des routes. Les écrans admin portent le préfixe /admin.
///
/// Arguments : [folder] attend un identifiant de dossier (int) ; [story],
/// [storyAdmin], [editor] et [replaceContent] un identifiant d'histoire ;
/// [import] un identifiant de personnage facultatif.
abstract final class Routes {
  static const library = '/';
  static const search = '/recherche';
  static const folder = '/dossier';
  static const story = '/histoire';

  static const import = '/admin/import';
  static const replaceContent = '/admin/remplacer';
  static const storyAdmin = '/admin/fiche';
  static const editor = '/admin/editeur';
  static const export = '/admin/export';
  static const characters = '/admin/personnages';

  /// Écrans qui s'ouvrent comme une fenêtre (croix en haut à gauche).
  static const _modals = {export};
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
      Routes.replaceContent => ImportScreen(replaceStoryId: arg! as int),
      Routes.storyAdmin => StoryAdminScreen(storyId: arg! as int),
      Routes.editor => EditorScreen(storyId: arg! as int),
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
