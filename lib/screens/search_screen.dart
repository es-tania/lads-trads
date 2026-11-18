import 'package:material_ui/material_ui.dart';

import '../app.dart';
import '../data/models.dart';
import '../data/services.dart';
import '../theme/ink.dart';
import '../widgets/cover.dart';
import '../widgets/ink_widgets.dart';

/// Recherche d'une histoire par son titre (FR ou EN), tous personnages confondus.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 20, 8),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Retour',
                    onPressed: () => Navigator.maybePop(context),
                    icon: const Icon(Icons.chevron_left_rounded, size: 24),
                  ),
                  Expanded(
                    child: TextField(
                      autofocus: true,
                      textInputAction: TextInputAction.search,
                      onChanged: (v) => setState(() => _query = v),
                      decoration: const InputDecoration(
                        hintText: 'Titre en français ou en anglais',
                        prefixIcon: Icon(Icons.search_rounded, size: 18),
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: LibraryQuery<List<Story>>(
                args: _query,
                load: (library) => library.searchStories(_query),
                builder: (context, results) {
                  if (_query.trim().isEmpty) return const SizedBox.shrink();
                  if (results.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(20),
                      child: InkComingSoon(text: 'Aucune histoire ne correspond.'),
                    );
                  }
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                    children: [
                      InkGroup(
                        children: [
                          for (final story in results)
                            InkWell(
                              onTap: () => Navigator.pushReplacementNamed(context, Routes.story, arguments: story.id),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 30,
                                      height: 40,
                                      child: StoryCover(cover: story.cover, radius: 4, emptyLabel: null, decodeWidth: 90),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(story.title, style: InkText.row),
                                          Text(
                                            '${story.characterName} · ${story.folderName}',
                                            style: InkText.hint,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
