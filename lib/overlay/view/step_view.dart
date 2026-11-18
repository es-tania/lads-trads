/// Ce que montre la fenêtre flottante pendant la lecture : la réplique ou le choix.
library;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../text/line_labels.dart';
import '../../theme/ink.dart';
import '../../widgets/markup_field.dart';
import '../playback.dart';

/// Contenu central : une réplique, ou un choix à faire.
class OverlayStepView extends StatelessWidget {
  const OverlayStepView({
    super.key,
    required this.playback,
    required this.fontSize,
    required this.onPick,
    required this.onChangeBranch,
    this.onEdit,
  });

  final Playback playback;
  final double fontSize;
  final ValueChanged<int> onPick;
  final VoidCallback onChangeBranch;

  /// Mode admin : corriger la réplique affichée.
  final ValueChanged<PlayLine>? onEdit;

  @override
  Widget build(BuildContext context) {
    final step = playback.current!;
    final (number, total) = playback.counter;
    final counter = 'L.${paddedNumber(number)}/${paddedNumber(total)}';
    final partTitle = _partTitle(playback.part.title);
    final showPart = playback.atPartStart || step.isChoice;

    final header = <Widget>[
      if (!step.isChoice && step.line!.speaker != null)
        Text(
          step.line!.speaker!,
          style: TextStyle(
            fontSize: 12,
            height: 16 / 12,
            fontWeight: FontWeight.w500,
            color: InkColors.forSpeaker(step.line!.speaker!),
          ),
        ),
      if (playback.branchLetter != null)
        Text(
          'branche ${playback.branchLetter}',
          style: const TextStyle(fontSize: 12, height: 16 / 12, color: InkColors.textFaint),
        ),
      Text(
        showPart && partTitle.isNotEmpty ? '$partTitle · $counter' : counter,
        style: InkText.count.copyWith(fontSize: 11, height: 16 / 11),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.end, children: header),
            ),
            if (playback.branchLetter != null)
              GestureDetector(
                onTap: onChangeBranch,
                behavior: HitTestBehavior.opaque,
                child: const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Text(
                    'Changer de branche',
                    style: TextStyle(fontSize: 12, height: 16 / 12, color: InkColors.accent),
                  ),
                ),
              ),
            if (onEdit != null && !step.isChoice && step.line!.id != null)
              Semantics(
                button: true,
                label: 'Modifier la réplique',
                child: GestureDetector(
                  onTap: () => onEdit!(step.line!),
                  behavior: HitTestBehavior.opaque,
                  child: const Padding(
                    padding: EdgeInsets.only(left: 12, right: 2),
                    child: Icon(Icons.edit_outlined, size: 14, color: InkColors.textFaint),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 2),
        if (step.isChoice)
          OverlayChoiceView(options: step.choiceOptions!, picked: playback.pickedOption, onPick: onPick)
        else
          OverlayLineText(line: step.line!, fontSize: fontSize),
      ],
    );
  }

  /// « KINDLED » → « Kindled ».
  static String _partTitle(String title) {
    final letters = title.replaceAll(RegExp(r'[^\p{L}]', unicode: true), '');
    if (letters.isEmpty || letters != letters.toUpperCase()) return title;
    final lower = title.toLowerCase();
    return lower[0].toUpperCase() + lower.substring(1);
  }
}

class OverlayLineText extends StatelessWidget {
  const OverlayLineText({super.key, required this.line, required this.fontSize});

  final PlayLine line;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return MarkupText(
      line.text,
      style: InkText.dialogue.copyWith(
        fontSize: fontSize,
        color: line.isNarration ? InkColors.textMuted : InkColors.text,
        fontStyle: line.isThought ? FontStyle.italic : FontStyle.normal,
      ),
    );
  }
}

class OverlayChoiceView extends StatelessWidget {
  const OverlayChoiceView({super.key, required this.options, required this.picked, required this.onPick});

  final List<PlayOption> options;
  final int? picked;
  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Quel choix as-tu fait ?', style: InkText.label),
        const SizedBox(height: 8),
        for (final (i, option) in options.indexed) ...[
          if (i > 0) const SizedBox(height: 6),
          Material(
            color: InkColors.raised,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: picked == i ? InkColors.accent : InkColors.borderSoft),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () {
                HapticFeedback.selectionClick();
                onPick(i);
              },
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 40),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: Row(
                    children: [
                      Text(optionLetter(i), style: InkText.count.copyWith(color: InkColors.textMuted)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(option.label, style: const TextStyle(fontFamily: InkFonts.display, fontSize: 15)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
