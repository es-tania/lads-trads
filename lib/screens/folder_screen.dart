import 'package:material_ui/material_ui.dart';

import '../app.dart';
import '../state/admin_mode.dart';
import '../theme/ink.dart';
import '../widgets/cover.dart';
import '../widgets/ink_widgets.dart';

class FolderScreen extends StatelessWidget {
  const FolderScreen({super.key, required this.folderName});

  final String folderName;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ValueListenableBuilder<bool>(
          valueListenable: adminMode,
          builder: (context, admin, _) => ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              InkTopBar(
                actions: [
                  if (admin)
                    IconButton(
                      tooltip: 'Modifier le dossier',
                      onPressed: () => Navigator.pushNamed(context, Routes.newFolder, arguments: folderName),
                      icon: const Icon(Icons.more_horiz_rounded, size: 20),
                    ),
                ],
              ),
              InkHeading(eyebrow: 'Rafayel', title: folderName, count: '1 histoire'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                // Deux colonnes ; la hauteur suit le titre (une ou deux lignes).
                child: LayoutBuilder(
                  builder: (context, box) {
                    final tileWidth = (box.maxWidth - 12) / 2;
                    return Wrap(
                      spacing: 12,
                      runSpacing: 24,
                      children: [
                        SizedBox(
                          width: tileWidth,
                          child: _StoryTile(
                            title: 'Into The Canvas',
                            onTap: () => Navigator.pushNamed(context, Routes.story, arguments: 'Into The Canvas'),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StoryTile extends StatelessWidget {
  const _StoryTile({required this.title, required this.onTap});

  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AspectRatio(aspectRatio: 3 / 4, child: CoverPlaceholder(radius: 12)),
          const SizedBox(height: 8),
          Text(title, style: InkText.row, maxLines: 2, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}
