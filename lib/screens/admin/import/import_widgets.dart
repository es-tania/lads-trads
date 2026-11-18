/// Morceaux de l'écran d'import : fichiers choisis et vérifications.
library;

import 'package:material_ui/material_ui.dart';

import '../../../docx/story_model.dart';
import '../../../theme/ink.dart';
import '../../../widgets/ink_widgets.dart';

class ImportBadge extends StatelessWidget {
  const ImportBadge(this.text, {super.key});

  final String? text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: InkColors.raised, borderRadius: BorderRadius.circular(4)),
      child: text == null
          ? const Icon(Icons.image_outlined, size: 16, color: InkColors.textFaint)
          : Text(text!, style: const TextStyle(fontFamily: InkFonts.mono, fontSize: 11)),
    );
  }
}

class ImportFileRow extends StatelessWidget {
  const ImportFileRow({
    super.key,
    required this.badge,
    required this.title,
    required this.detail,
    required this.onTap,
    required this.changeLabel,
    this.subtitle,
    this.extraLabel,
    this.onExtra,
  });

  /// Deuxième action (« Changer » à côté de « Recadrer »).
  final String? extraLabel;
  final VoidCallback? onExtra;

  final Widget badge;
  final String title;
  final String? subtitle;
  final String detail;
  final VoidCallback onTap;
  final String changeLabel;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
        child: Row(
          children: [
            badge,
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(
                      text: title,
                      style: InkText.row,
                      children: [
                        if (subtitle != null)
                          TextSpan(
                            text: '  $subtitle',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                              color: InkColors.textFaint,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(detail, style: InkText.count, maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            TextButton(
              onPressed: onTap,
              child: Text(changeLabel, style: const TextStyle(fontSize: 14)),
            ),
            if (extraLabel != null)
              TextButton(
                onPressed: onExtra,
                child: Text(extraLabel!, style: const TextStyle(fontSize: 14)),
              ),
          ],
        ),
      ),
    );
  }
}

/// Section « À vérifier » : avertissements du parseur.
class ImportChecks extends StatelessWidget {
  const ImportChecks({super.key, required this.parsed});

  final ParsedStory parsed;

  @override
  Widget build(BuildContext context) {
    final warnings = parsed.warnings;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkSectionLabel(warnings.isEmpty ? 'À vérifier' : 'À vérifier · ${warnings.length}'),
        if (warnings.isEmpty)
          const InkComingSoon(text: 'Rien à signaler.')
        else
          InkGroup(
            children: [
              for (final w in warnings.take(20))
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 48,
                        child: Text(w.paragraph == null ? '—' : '§${w.paragraph}', style: InkText.count),
                      ),
                      Expanded(child: Text(w.message, style: const TextStyle(fontSize: 14, height: 1.35))),
                    ],
                  ),
                ),
              if (warnings.length > 20)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('… et ${warnings.length - 20} autres.', style: InkText.body),
                ),
            ],
          ),
      ],
    );
  }
}
