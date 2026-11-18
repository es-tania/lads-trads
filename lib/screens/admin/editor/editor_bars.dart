/// En-tête, onglets des parties et barre du bas de l'éditeur.
library;

import 'package:material_ui/material_ui.dart';

import '../../../data/models.dart';
import '../../../theme/ink.dart';
import '../../../widgets/one_line_label.dart';

class EditorHeader extends StatelessWidget {
  const EditorHeader({super.key, required this.title, required this.part, required this.saved});

  final String title;
  final String part;
  final bool saved;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 12, 0),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Retour',
            onPressed: () => Navigator.maybePop(context),
            icon: const Icon(Icons.chevron_left_rounded, size: 24),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: InkText.eyebrow, maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(
                  part,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: InkFonts.display,
                    fontSize: 24,
                    height: 1.15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (saved) const Text('Enregistré', style: InkText.hint),
        ],
      ),
    );
  }
}

/// Onglets des parties : répartis sur la largeur, ou défilants s'il y en a beaucoup.
class EditorPartTabs extends StatelessWidget {
  const EditorPartTabs({super.key, required this.parts, required this.selected, required this.onChanged});

  final List<Part> parts;
  final int selected;
  final ValueChanged<int> onChanged;

  /// « Épisode 3 » → « Ép. 3 » pour tenir dans un onglet.
  static String short(Part part) => part.displayTitle.replaceFirst(RegExp(r'^[ÉéEe]pisode\s+'), 'Ép. ');

  @override
  Widget build(BuildContext context) {
    Widget tab(int i) {
      final on = i == selected;
      return Semantics(
        selected: on,
        button: true,
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () => onChanged(i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            alignment: Alignment.center,
            decoration: BoxDecoration(color: on ? InkColors.raised : null, borderRadius: BorderRadius.circular(6)),
            child: Text(
              short(parts[i]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: on ? FontWeight.w500 : FontWeight.w400,
                color: on ? InkColors.text : InkColors.textMuted,
              ),
            ),
          ),
        ),
      );
    }

    final many = parts.length > 5;
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: InkColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: InkColors.border),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: many
            ? SizedBox(
                height: 32,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: parts.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 4),
                  itemBuilder: (_, i) => tab(i),
                ),
              )
            : Row(
                children: [
                  for (var i = 0; i < parts.length; i++) ...[
                    if (i > 0) const SizedBox(width: 4),
                    Expanded(child: tab(i)),
                  ],
                ],
              ),
      ),
    );
  }
}

class EditorBottomBar extends StatelessWidget {
  const EditorBottomBar({super.key, required this.onImport, required this.onAdd});

  final VoidCallback onImport;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: InkColors.sunken,
        border: Border(top: BorderSide(color: InkColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Row(
            children: [
              OutlinedButton.icon(
                onPressed: onImport,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(44, 48),
                  padding: InkSpacing.compactButton,
                  textStyle: InkText.button,
                ),
                icon: const Icon(Icons.upload_outlined, size: 18, color: InkColors.textMuted),
                label: const Text('Importer'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: onAdd,
                  style: FilledButton.styleFrom(padding: InkSpacing.compactButton),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const OneLineLabel('Ajouter une réplique'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
