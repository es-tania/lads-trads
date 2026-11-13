import 'package:material_ui/material_ui.dart';

import '../app.dart';
import '../state/admin_mode.dart';
import '../theme/ink.dart';
import '../widgets/cover.dart';
import '../widgets/ink_widgets.dart';

/// Parties de démonstration (étape 1). Elles viendront du .docx à l'étape 2-3.
const _parts = ['Épisode 1', 'Épisode 2', 'Épisode 3', 'Kindled', 'Fin'];

class StoryScreen extends StatelessWidget {
  const StoryScreen({super.key, required this.title});

  final String title;

  void _launch(BuildContext context, String part) =>
      showStepSnack(context, 'La fenêtre flottante arrive à l\'étape 4 ($part).');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ValueListenableBuilder<bool>(
          valueListenable: adminMode,
          builder: (context, admin, _) => ListView(
            padding: const EdgeInsets.only(bottom: 16),
            children: [
              InkTopBar(
                actions: [
                  if (admin)
                    OutlinedButton.icon(
                      onPressed: () => Navigator.pushNamed(context, Routes.storyAdmin),
                      style: OutlinedButton.styleFrom(minimumSize: const Size(44, 36)),
                      icon: const Icon(Icons.edit_outlined, size: 16, color: InkColors.textMuted),
                      label: const Text('Modifier'),
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const SizedBox(width: 96, height: 128, child: CoverPlaceholder(label: null)),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Rafayel · Memoria 5★', style: InkText.eyebrow),
                          const SizedBox(height: 4),
                          Text(title, style: InkText.screenTitle.copyWith(fontSize: 28)),
                          const SizedBox(height: 8),
                          Text('${_parts.length} parties', style: InkText.count),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const InkSectionLabel('Parties'),
                    InkGroup(
                      children: [
                        for (final (i, part) in _parts.indexed)
                          InkRow(
                            height: 48,
                            label: part,
                            leading: SizedBox(
                              width: 24,
                              child: Text((i + 1).toString().padLeft(2, '0'), style: InkText.count),
                            ),
                            trailing: const Icon(Icons.play_arrow_outlined, size: 18, color: InkColors.textMuted),
                            onTap: () => _launch(context, part),
                          ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    const InkSectionLabel('Fenêtre de traduction'),
                    const InkComingSoon(
                      text: 'Opacité du fond, taille du texte et affichage de la narration : réglages de l\'étape 3.',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: InkBottomAction(
        label: 'Lancer depuis le début',
        icon: Icons.play_arrow_rounded,
        onPressed: () => _launch(context, _parts.first),
      ),
    );
  }
}
