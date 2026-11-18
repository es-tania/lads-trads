import 'package:material_ui/material_ui.dart';

import '../theme/ink.dart';

/// Panneau du bas aux couleurs « ink », qui suit le clavier.
///
/// [scrollable] `false` : le contenu n'est pas mis dans une liste qui
/// défile (pour un contenu qui a besoin de sa hauteur, comme un recadrage).
Future<T?> showInkSheet<T>(BuildContext context, {required WidgetBuilder builder, bool scrollable = true}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: InkColors.surface,
    barrierColor: InkColors.barrier,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      side: BorderSide(color: InkColors.borderSoft),
    ),
    builder: (context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: scrollable
            ? SingleChildScrollView(padding: _padding, child: builder(context))
            : Padding(padding: _padding, child: builder(context)),
      ),
    ),
  );
}

const _padding = EdgeInsets.fromLTRB(20, 8, 20, 32);

/// Poignée en haut d'un panneau.
class InkSheetGrabber extends StatelessWidget {
  const InkSheetGrabber({super.key, this.color = InkColors.grabber});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 36,
        height: 4,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
      ),
    );
  }
}

/// Poignée, surtitre, titre et croix d'un panneau.
class InkSheetHeader extends StatelessWidget {
  const InkSheetHeader({super.key, required this.title, this.eyebrow, this.titleSize = 24});

  final String title;
  final String? eyebrow;
  final double titleSize;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const InkSheetGrabber(),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (eyebrow != null) ...[Text(eyebrow!, style: InkText.count), const SizedBox(height: 4)],
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: InkFonts.display,
                      fontSize: titleSize,
                      height: 1.15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Fermer',
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close_rounded, size: 18),
            ),
          ],
        ),
      ],
    );
  }
}

/// Champ de saisie sur fond sombre, comme dans les maquettes des panneaux.
InputDecoration inkSheetField({String? hint, bool strong = false}) => InputDecoration(
  hintText: hint,
  fillColor: InkColors.bg,
  contentPadding: const EdgeInsets.all(12),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: BorderSide(color: strong ? InkColors.borderStrong : InkColors.border),
  ),
);

/// Annuler / bouton principal, en bas d'un panneau.
class InkSheetActions extends StatelessWidget {
  const InkSheetActions({super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              backgroundColor: InkColors.transparent,
              minimumSize: const Size(44, 48),
              textStyle: InkText.button,
            ),
            child: const Text('Annuler'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: FilledButton(onPressed: onPressed, child: Text(label)),
        ),
      ],
    );
  }
}
