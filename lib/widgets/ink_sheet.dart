import 'package:material_ui/material_ui.dart';

import '../theme/ink.dart';

/// Panneau du bas aux couleurs « ink », qui suit le clavier.
Future<T?> showInkSheet<T>(BuildContext context, {required WidgetBuilder builder}) {
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
        child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 32), child: builder(context)),
      ),
    ),
  );
}

/// Poignée, surtitre, titre et croix d'un panneau.
class InkSheetHeader extends StatelessWidget {
  const InkSheetHeader({super.key, required this.title, this.eyebrow});

  final String title;
  final String? eyebrow;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(color: InkColors.grabber, borderRadius: BorderRadius.circular(2)),
          ),
        ),
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
              textStyle: const TextStyle(fontFamily: InkFonts.ui, fontSize: 15),
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
