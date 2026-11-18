import 'package:material_ui/material_ui.dart';

import '../theme/ink.dart';

/// Un champ avec son libellé au-dessus (« Nom », « Personnage »…).
class InkLabeled extends StatelessWidget {
  const InkLabeled({
    super.key,
    required this.label,
    required this.child,
    this.gap = 4,
    this.alignment = CrossAxisAlignment.stretch,
  });

  final String label;
  final Widget child;

  /// Espace entre le libellé et le champ.
  final double gap;
  final CrossAxisAlignment alignment;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignment,
      children: [
        Text(label, style: InkText.label),
        SizedBox(height: gap),
        child,
      ],
    );
  }
}
