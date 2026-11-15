import 'package:material_ui/material_ui.dart';

import '../app.dart';
import '../data/models.dart';
import '../data/overlay_settings.dart';
import '../data/services.dart';
import '../state/admin_mode.dart';
import '../theme/ink.dart';
import '../widgets/cover.dart';
import '../widgets/ink_widgets.dart';

class StoryScreen extends StatelessWidget {
  const StoryScreen({super.key, required this.storyId});

  final int storyId;

  Future<void> _launch(BuildContext context, Story story, Part part) async {
    final launcher = context.overlayLauncher;
    var granted = await launcher.hasPermission();
    if (!granted) {
      if (!context.mounted) return;
      final go = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: InkColors.raised,
          title: const Text('Afficher par-dessus le jeu'),
          content: const Text(
            'Pour afficher la traduction au-dessus de Love and Deepspace, Android doit autoriser '
            'LADS Trad à s\'afficher par-dessus les autres applis.\n\n'
            'Dans l\'écran qui s\'ouvre, active « LADS Trad », puis reviens ici.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Plus tard')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Autoriser')),
          ],
        ),
      );
      if (go != true) return;
      granted = await launcher.requestPermission();
    }
    if (!context.mounted) return;
    if (!granted) {
      showStepSnack(context, 'Sans cette autorisation, la traduction ne peut pas s\'afficher sur le jeu.');
      return;
    }
    await launcher.launch(
      storyId: story.id,
      storyTitle: story.title,
      partIndex: part.position,
      screenWidth: MediaQuery.sizeOf(context).width,
      pixelRatio: MediaQuery.devicePixelRatioOf(context),
      admin: adminMode.value,
    );
    if (context.mounted) showStepSnack(context, '${part.displayTitle} est prête : passe sur le jeu.');
  }

  @override
  Widget build(BuildContext context) {
    return LibraryQuery<(Story?, List<Part>)>(
      args: storyId,
      load: (library) async => (await library.story(storyId), await library.parts(storyId)),
      builder: (context, data) {
        final (story, parts) = data;
        if (story == null) {
          return const Scaffold(body: SafeArea(child: InkTopBar()));
        }
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
                          onPressed: () => Navigator.pushNamed(context, Routes.storyAdmin, arguments: story.id),
                          style: OutlinedButton.styleFrom(minimumSize: const Size(44, 36)),
                          icon: const Icon(Icons.edit_outlined, size: 16, color: InkColors.textMuted),
                          label: const Text('Modifier'),
                        ),
                    ],
                  ),
                  _Header(story: story),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const InkSectionLabel('Parties'),
                        InkGroup(
                          children: [
                            for (final part in parts)
                              InkRow(
                                height: 48,
                                label: part.displayTitle,
                                leading: SizedBox(
                                  width: 24,
                                  child: Text((part.position + 1).toString().padLeft(2, '0'), style: InkText.count),
                                ),
                                trailing: const Icon(Icons.play_arrow_outlined, size: 18, color: InkColors.textMuted),
                                onTap: () => _launch(context, story, part),
                              ),
                          ],
                        ),
                        const SizedBox(height: 32),
                        const InkSectionLabel('Fenêtre de traduction'),
                        const _OverlaySettingsCard(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          bottomNavigationBar: parts.isEmpty
              ? null
              : InkBottomAction(
                  label: 'Lancer depuis le début',
                  icon: Icons.play_arrow_rounded,
                  onPressed: () => _launch(context, story, parts.first),
                ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.story});

  final Story story;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          SizedBox(
            width: 96,
            height: 128,
            child: StoryCover(path: story.coverPath, emptyLabel: null, decodeWidth: 288),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${story.characterName} · ${story.folderName}', style: InkText.eyebrow),
                const SizedBox(height: 4),
                Text(story.title, style: InkText.screenTitle.copyWith(fontSize: 28)),
                const SizedBox(height: 8),
                Text(story.partCount == 1 ? '1 partie' : '${story.partCount} parties', style: InkText.count),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Opacité et taille du texte de la fenêtre flottante. La narration est
/// toujours affichée.
class _OverlaySettingsCard extends StatelessWidget {
  const _OverlaySettingsCard();

  @override
  Widget build(BuildContext context) {
    final settings = context.overlaySettings;
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) => InkGroup(
        children: [
          SizedBox(
            height: 48,
            child: Padding(
              padding: const EdgeInsets.only(left: 16, right: 4),
              child: Row(
                children: [
                  const Expanded(child: Text('Opacité du fond', style: TextStyle(fontSize: 15))),
                  SizedBox(
                    width: 160,
                    child: Slider(
                      value: settings.opacity,
                      min: OverlaySettings.minOpacity,
                      max: OverlaySettings.maxOpacity,
                      label: '${(settings.opacity * 100).round()} %',
                      semanticFormatterCallback: (v) => '${(v * 100).round()} %',
                      onChanged: settings.setOpacity,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(
            height: 48,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Expanded(child: Text('Taille du texte', style: TextStyle(fontSize: 15))),
                  _TextSizePicker(value: settings.textSize, onChanged: settings.setTextSize),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TextSizePicker extends StatelessWidget {
  const _TextSizePicker({required this.value, required this.onChanged});

  final OverlayTextSize value;
  final ValueChanged<OverlayTextSize> onChanged;

  static const _labels = {
    OverlayTextSize.small: 'Petit',
    OverlayTextSize.medium: 'Moyen',
    OverlayTextSize.large: 'Grand',
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: InkColors.bg, borderRadius: BorderRadius.circular(10)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final size in OverlayTextSize.values)
            Semantics(
              selected: size == value,
              button: true,
              label: _labels[size],
              excludeSemantics: true,
              child: InkWell(
                borderRadius: BorderRadius.circular(6),
                onTap: () => onChanged(size),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 40,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: size == value ? InkColors.raised : null,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Aa',
                    style: TextStyle(
                      fontFamily: InkFonts.display,
                      fontSize: size.fontSize - 2,
                      color: size == value ? InkColors.text : InkColors.textMuted,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
