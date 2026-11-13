import 'package:material_ui/material_ui.dart';

import '../../theme/ink.dart';
import '../../widgets/ink_widgets.dart';

/// Gabarit commun des écrans admin de l'étape 1 : en-tête, contenu, action en bas.
class AdminPage extends StatelessWidget {
  const AdminPage({
    super.key,
    required this.title,
    required this.children,
    this.eyebrow,
    this.modal = false,
    this.bottomLabel,
    this.onBottom,
  });

  final String title;
  final String? eyebrow;
  final bool modal;
  final List<Widget> children;
  final String? bottomLabel;
  final VoidCallback? onBottom;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 16),
          children: [
            InkTopBar(close: modal),
            InkHeading(eyebrow: eyebrow, title: title),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
            ),
          ],
        ),
      ),
      bottomNavigationBar: bottomLabel == null
          ? null
          : InkBottomAction(label: bottomLabel!, onPressed: onBottom),
    );
  }
}

/// Ligne de navigation vers un autre écran admin.
class AdminLink extends StatelessWidget {
  const AdminLink({super.key, required this.label, required this.icon, required this.onTap});

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkRow(
      label: label,
      leading: Icon(icon, size: 18, color: InkColors.textFaint),
      trailing: const Icon(Icons.chevron_right_rounded, size: 18, color: InkColors.textFaint),
      onTap: onTap,
    );
  }
}
