import 'package:material_ui/material_ui.dart';

import '../theme/ink.dart';

/// En-tête d'écran secondaire : retour (ou fermer) à gauche, actions à droite.
class InkTopBar extends StatelessWidget {
  const InkTopBar({super.key, this.close = false, this.actions = const []});

  /// `true` pour une fenêtre modale (croix), `false` pour un retour (chevron).
  final bool close;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 8, 0),
      child: Row(
        children: [
          IconButton(
            tooltip: close ? 'Fermer' : 'Retour',
            onPressed: () => Navigator.of(context).maybePop(),
            icon: Icon(close ? Icons.close_rounded : Icons.chevron_left_rounded, size: 24),
          ),
          const Spacer(),
          ...actions,
        ],
      ),
    );
  }
}

/// Titre d'écran avec un surtitre (personnage, dossier…) et un compteur optionnel.
class InkHeading extends StatelessWidget {
  const InkHeading({super.key, required this.title, this.eyebrow, this.count});

  final String title;
  final String? eyebrow;
  final String? count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (eyebrow != null) ...[
            Text(eyebrow!, style: InkText.eyebrow),
            const SizedBox(height: 4),
          ],
          Text(title, style: InkText.screenTitle),
          if (count != null) ...[
            const SizedBox(height: 8),
            Text(count!, style: InkText.count),
          ],
        ],
      ),
    );
  }
}

/// Libellé de section (« Parties », « Dossiers de Rafayel »…).
class InkSectionLabel extends StatelessWidget {
  const InkSectionLabel(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SizedBox(
        height: 32,
        child: Row(
          children: [
            Expanded(child: Text(text, style: InkText.sectionLabel)),
            ?trailing,
          ],
        ),
      ),
    );
  }
}

/// Carte groupée : lignes séparées par une bordure fine, coins de 16.
class InkGroup extends StatelessWidget {
  const InkGroup({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) rows.add(const Divider());
      rows.add(children[i]);
    }
    return Container(
      decoration: BoxDecoration(
        color: InkColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: InkColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        type: MaterialType.transparency,
        child: Column(mainAxisSize: MainAxisSize.min, children: rows),
      ),
    );
  }
}

/// Ligne cliquable d'une [InkGroup].
class InkRow extends StatelessWidget {
  const InkRow({
    super.key,
    required this.label,
    this.leading,
    this.trailing,
    this.onTap,
    this.height = 56,
  });

  final String label;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final double height;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: height,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              if (leading != null) ...[leading!, const SizedBox(width: 12)],
              Expanded(child: Text(label, style: InkText.row)),
              ?trailing,
            ],
          ),
        ),
      ),
    );
  }
}

/// Zone vide qui dit ce qui arrivera à quelle étape.
class InkComingSoon extends StatelessWidget {
  const InkComingSoon({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: InkColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: InkColors.border),
      ),
      child: Text(text, style: InkText.body),
    );
  }
}

/// Bouton principal pleine largeur, collé en bas d'écran.
class InkBottomAction extends StatelessWidget {
  const InkBottomAction({super.key, required this.label, this.icon, this.onPressed});

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: SizedBox(
          width: double.infinity,
          child: icon == null
              ? FilledButton(onPressed: onPressed, child: Text(label))
              : FilledButton.icon(onPressed: onPressed, icon: Icon(icon, size: 18), label: Text(label)),
        ),
      ),
    );
  }
}

/// Message bref en bas de l'écran ; remplace le précédent s'il est encore affiché.
void showInkSnack(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}
