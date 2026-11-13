import 'package:material_ui/material_ui.dart';

import '../../app.dart';
import '../../theme/ink.dart';
import '../../widgets/ink_widgets.dart';
import 'admin_page.dart';

/// Répliques de démonstration (étape 1).
const _sample = [
  ('Rafayel', 'Tu as raison.'),
  ('', 'Rafayel se redresse et se tourne vers les enfants.'),
  ('Moi', 'Tu devrais faire attention à ton comportement…'),
];

class EditorScreen extends StatelessWidget {
  const EditorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AdminPage(
      eyebrow: 'Into The Canvas',
      title: 'Kindled',
      children: [
        InkGroup(
          children: [
            for (final (i, (speaker, text)) in _sample.indexed)
              _LinePreview(
                number: i + 1,
                speaker: speaker,
                text: text,
                onTap: () => Navigator.pushNamed(context, Routes.editLine),
              ),
          ],
        ),
        const SizedBox(height: 16),
        const InkComingSoon(text: 'L\'éditeur complet (parties, branches, insertion) arrive à l\'étape 5.'),
      ],
    );
  }
}

class _LinePreview extends StatelessWidget {
  const _LinePreview({required this.number, required this.speaker, required this.text, required this.onTap});

  final int number;
  final String speaker;
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final narration = speaker.isEmpty;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (!narration) ...[
                  Text(
                    speaker,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: InkColors.forSpeaker(speaker)),
                  ),
                  const SizedBox(width: 8),
                ],
                Text('L.${number.toString().padLeft(3, '0')}', style: InkText.count.copyWith(fontSize: 11)),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              text,
              style: InkText.dialogue.copyWith(color: narration ? InkColors.textMuted : InkColors.text),
            ),
          ],
        ),
      ),
    );
  }
}
