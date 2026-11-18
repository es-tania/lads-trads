import 'package:material_ui/material_ui.dart';

import '../theme/ink.dart';

/// Boutons côte à côte dont un seul est choisi (type, rareté…).
class InkSegmented<T> extends StatelessWidget {
  const InkSegmented({super.key, required this.value, required this.options, required this.onChanged});

  final T value;
  final Map<T, String> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: InkColors.bg, borderRadius: BorderRadius.circular(10)),
      child: Material(
        type: MaterialType.transparency,
        child: Row(
          children: [
            for (final (i, MapEntry(key: option, value: label)) in options.entries.indexed) ...[
              if (i > 0) const SizedBox(width: 4),
              Expanded(
                child: Semantics(
                  selected: option == value,
                  button: true,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: () => onChanged(option),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: option == value ? InkColors.raised : null,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: option == value ? FontWeight.w500 : FontWeight.w400,
                          color: option == value ? InkColors.text : InkColors.textMuted,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
