/// Correction d'une réplique pendant la lecture, en mode admin.
library;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../theme/ink.dart';
import '../../widgets/markup_field.dart';

/// Correction de la réplique affichée, sans quitter le jeu.
class OverlayEditView extends StatelessWidget {
  const OverlayEditView({
    super.key,
    required this.speakers,
    required this.speaker,
    required this.speakersOpen,
    required this.onToggleSpeakers,
    required this.onSpeaker,
    required this.newSpeaker,
    required this.renaming,
    required this.onRename,
    required this.onOther,
    required this.onConfirmOther,
    required this.controller,
    required this.fontSize,
    required this.error,
    required this.saving,
    required this.onCancel,
    required this.onSave,
  });

  final List<String> speakers;

  /// Personnage choisi, `null` pour une narration.
  final String? speaker;

  /// Liste des personnages dépliée (sinon : seulement le personnage choisi).
  final bool speakersOpen;
  final VoidCallback onToggleSpeakers;
  final ValueChanged<String?> onSpeaker;

  /// Champ « + Autre » (ou « ✎ Renommer ») ouvert, ou `null`.
  final TextEditingController? newSpeaker;
  final bool renaming;

  /// Renommer le personnage choisi dans toute l'histoire (`null` : impossible).
  final VoidCallback? onRename;
  final VoidCallback onOther;
  final VoidCallback onConfirmOther;
  final MarkupController controller;
  final double fontSize;
  final String? error;
  final bool saving;
  final VoidCallback onCancel;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          speaker == null ? 'Modifier · narration' : 'Modifier · $speaker',
          style: TextStyle(
            fontSize: 12,
            height: 16 / 12,
            fontWeight: FontWeight.w500,
            color: speaker == null ? InkColors.textMuted : InkColors.forSpeaker(speaker!),
          ),
        ),
        const SizedBox(height: 6),
        // Qui parle : replié, une seule puce (le personnage choisi) qui
        // déplie la liste ; déplié, toutes les puces, qui passent à la ligne.
        if (!speakersOpen)
          Align(
            alignment: Alignment.centerLeft,
            child: OverlaySpeakerChip(
              label: speaker ?? 'Narration',
              dot: speaker == null ? null : InkColors.forSpeaker(speaker!),
              selected: true,
              trailing: Icons.expand_more_rounded,
              semanticsLabel: 'Changer de personnage',
              onTap: onToggleSpeakers,
            ),
          )
        else
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final name in speakers)
                OverlaySpeakerChip(
                  label: name,
                  dot: InkColors.forSpeaker(name),
                  selected: name == speaker,
                  onTap: () => onSpeaker(name),
                ),
              OverlaySpeakerChip(label: 'Narration', selected: speaker == null, onTap: () => onSpeaker(null)),
              OverlaySpeakerChip(
                label: '+ Autre',
                selected: newSpeaker != null && !renaming,
                dashed: true,
                onTap: onOther,
              ),
              if (speaker != null && onRename != null)
                OverlaySpeakerChip(label: '✎ Renommer', selected: renaming, dashed: true, onTap: onRename!),
              OverlaySpeakerChip(
                label: '',
                selected: false,
                trailing: Icons.expand_less_rounded,
                semanticsLabel: 'Replier la liste',
                onTap: onToggleSpeakers,
              ),
            ],
          ),
        if (newSpeaker != null) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: newSpeaker,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => onConfirmOther(),
                  style: const TextStyle(fontSize: 14),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: renaming ? 'Nouveau nom (toute l\'histoire)' : 'Nom du personnage',
                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    fillColor: InkColors.surface,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              ListenableBuilder(
                listenable: newSpeaker!,
                builder: (context, _) => TextButton(
                  onPressed: newSpeaker!.text.trim().isEmpty ? null : onConfirmOther,
                  style: TextButton.styleFrom(
                    minimumSize: const Size(44, 32),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  child: const Text('OK'),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 6),
        MarkupField(
          controller: controller,
          compact: true,
          autofocus: newSpeaker == null,
          minLines: 2,
          maxLines: 5,
          style: InkText.dialogue.copyWith(fontSize: fontSize),
          decoration: const InputDecoration(
            isDense: true,
            contentPadding: EdgeInsets.all(8),
            fillColor: InkColors.surface,
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 4),
          Text(error!, style: const TextStyle(fontSize: 12, color: InkColors.error)),
        ],
        const SizedBox(height: 6),
        // Wrap : les deux boutons passent à la ligne si la fenêtre est étroite.
        Wrap(
          alignment: WrapAlignment.end,
          spacing: 4,
          children: [
            TextButton(
              onPressed: saving ? null : onCancel,
              style: TextButton.styleFrom(
                minimumSize: const Size(44, 32),
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
              child: const Text('Annuler'),
            ),
            ListenableBuilder(
              listenable: controller,
              builder: (context, _) => FilledButton(
                onPressed: saving || controller.text.trim().isEmpty ? null : onSave,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(44, 32),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  textStyle: const TextStyle(fontFamily: InkFonts.ui, fontSize: 13, fontWeight: FontWeight.w500),
                ),
                child: Text(saving ? 'Enregistrement…' : 'Enregistrer'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Puce d'un personnage dans la fenêtre (choix de qui parle).
class OverlaySpeakerChip extends StatelessWidget {
  const OverlaySpeakerChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.dot,
    this.dashed = false,
    this.trailing,
    this.semanticsLabel,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? dot;
  final bool dashed;

  /// Flèche pour déplier ou replier la liste.
  final IconData? trailing;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      label: semanticsLabel,
      // Le libellé dit l'action (« Changer de personnage ») : on ne le mêle
      // pas au nom affiché.
      excludeSemantics: semanticsLabel != null,
      child: Material(
        color: selected ? InkColors.raised : InkColors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: selected ? InkColors.accent : (dashed ? InkColors.borderStrong : InkColors.borderSoft),
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: Container(
            height: 30,
            // Un nom très long est coupé (« Petit garçon (audio uniq… »).
            constraints: const BoxConstraints(maxWidth: 170),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (dot != null) ...[
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 6),
                ],
                if (label.isNotEmpty)
                  Flexible(
                    child: Tooltip(
                      message: label,
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, color: selected ? InkColors.text : InkColors.textMuted),
                      ),
                    ),
                  ),
                if (trailing != null) ...[
                  if (label.isNotEmpty) const SizedBox(width: 2),
                  Icon(trailing, size: 16, color: InkColors.textMuted),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
