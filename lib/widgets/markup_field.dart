import 'package:material_ui/material_ui.dart';

import '../text/markup.dart';
import '../theme/ink.dart';

/// Champ de texte qui garde le gras et l'italique de chaque caractère.
///
/// [text] est le texte lisible ; [markup] le même avec ses balises, à
/// enregistrer. Un caractère tapé prend le style de celui qui le précède.
class MarkupController extends TextEditingController {
  MarkupController({String markup = ''}) : this._(parseMarks(markup));

  MarkupController._((String, List<int>) parsed)
      : _marks = List.of(parsed.$2),
        super(text: parsed.$1);

  List<int> _marks;

  String get markup => toMarkup(text, _marks);

  set markup(String value) {
    final (text, marks) = parseMarks(value);
    _marks = List.of(marks);
    super.value = TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
  }

  @override
  set value(TextEditingValue newValue) {
    final old = text;
    final next = newValue.text;
    if (old != next) {
      // Ce qui a changé : entre le début commun et la fin commune.
      var prefix = 0;
      while (prefix < old.length && prefix < next.length && old[prefix] == next[prefix]) {
        prefix++;
      }
      var suffix = 0;
      while (suffix < old.length - prefix &&
          suffix < next.length - prefix &&
          old[old.length - 1 - suffix] == next[next.length - 1 - suffix]) {
        suffix++;
      }
      final inherited = prefix > 0 ? _marks[prefix - 1] : (old.length > prefix ? _marks[prefix] : Marks.none);
      _marks = [
        ..._marks.sublist(0, prefix),
        ...List.filled(next.length - prefix - suffix, inherited),
        ..._marks.sublist(old.length - suffix),
      ];
    }
    super.value = newValue;
  }

  (int, int)? get _range {
    final s = selection;
    if (!s.isValid || s.isCollapsed) return null;
    return (s.start, s.end);
  }

  /// Le passage sélectionné a-t-il entièrement ce style ?
  bool isActive(int mark) {
    final r = _range;
    if (r == null) return false;
    for (var i = r.$1; i < r.$2; i++) {
      if (_marks[i] & mark == 0) return false;
    }
    return true;
  }

  /// Met le passage sélectionné dans ce style, ou le lui retire s'il l'a déjà.
  void toggle(int mark) {
    final r = _range;
    if (r == null) return;
    final on = !isActive(mark);
    for (var i = r.$1; i < r.$2; i++) {
      _marks[i] = on ? _marks[i] | mark : _marks[i] & ~mark;
    }
    notifyListeners();
  }

  @override
  TextSpan buildTextSpan({required BuildContext context, TextStyle? style, required bool withComposing}) {
    final spans = <TextSpan>[];
    var start = 0;
    for (var i = 1; i <= text.length; i++) {
      if (i == text.length || _marks[i] != _marks[start]) {
        final m = _marks[start];
        spans.add(TextSpan(
          text: text.substring(start, i),
          style: TextStyle(
            fontWeight: m & Marks.bold != 0 ? FontWeight.w600 : null,
            fontStyle: m & Marks.italic != 0 ? FontStyle.italic : null,
          ),
        ));
        start = i;
      }
    }
    return TextSpan(style: style, children: spans);
  }
}

/// Champ de saisie d'une réplique, avec « G » et « I » pour le passage
/// sélectionné (aussi dans le menu de sélection).
class MarkupField extends StatelessWidget {
  const MarkupField({
    super.key,
    required this.controller,
    this.style,
    this.decoration = const InputDecoration(),
    this.minLines,
    this.maxLines,
    this.autofocus = false,
    this.compact = false,
  });

  final MarkupController controller;
  final TextStyle? style;
  final InputDecoration decoration;
  final int? minLines;
  final int? maxLines;
  final bool autofocus;

  /// Boutons plus petits (fenêtre flottante).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Dans la zone du champ : toucher un bouton ne ferme pas le clavier.
        TextFieldTapRegion(
          child: ListenableBuilder(
            listenable: controller,
            builder: (context, _) => Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _MarkButton(
                  label: 'G',
                  tooltip: 'Gras',
                  bold: true,
                  compact: compact,
                  active: controller.isActive(Marks.bold),
                  enabled: !controller.selection.isCollapsed,
                  onTap: () => controller.toggle(Marks.bold),
                ),
                const SizedBox(width: 4),
                _MarkButton(
                  label: 'I',
                  tooltip: 'Italique',
                  italic: true,
                  compact: compact,
                  active: controller.isActive(Marks.italic),
                  enabled: !controller.selection.isCollapsed,
                  onTap: () => controller.toggle(Marks.italic),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: compact ? 4 : 6),
        TextField(
          controller: controller,
          autofocus: autofocus,
          minLines: minLines,
          maxLines: maxLines,
          textCapitalization: TextCapitalization.sentences,
          style: style,
          decoration: decoration,
          contextMenuBuilder: (context, state) => AdaptiveTextSelectionToolbar.buttonItems(
            anchors: state.contextMenuAnchors,
            buttonItems: [
              ...state.contextMenuButtonItems,
              if (!controller.selection.isCollapsed) ...[
                ContextMenuButtonItem(
                  label: 'Gras',
                  onPressed: () {
                    controller.toggle(Marks.bold);
                    state.hideToolbar();
                  },
                ),
                ContextMenuButtonItem(
                  label: 'Italique',
                  onPressed: () {
                    controller.toggle(Marks.italic);
                    state.hideToolbar();
                  },
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _MarkButton extends StatelessWidget {
  const _MarkButton({
    required this.label,
    required this.tooltip,
    required this.active,
    required this.enabled,
    required this.onTap,
    required this.compact,
    this.bold = false,
    this.italic = false,
  });

  final String label;
  final String tooltip;
  final bool active;
  final bool enabled;
  final VoidCallback onTap;
  final bool compact;
  final bool bold;
  final bool italic;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 30.0 : 36.0;
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        enabled: enabled,
        selected: active,
        label: tooltip,
        excludeSemantics: true,
        child: Opacity(
          opacity: enabled ? 1 : 0.4,
          child: Material(
            color: active ? InkColors.raised : const Color(0x00000000),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
              side: BorderSide(color: active ? InkColors.accent : InkColors.border),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: enabled ? onTap : null,
              child: SizedBox(
                width: size,
                height: size,
                child: Center(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontFamily: InkFonts.display,
                      fontSize: compact ? 14 : 16,
                      fontWeight: bold ? FontWeight.w600 : FontWeight.w500,
                      fontStyle: italic ? FontStyle.italic : FontStyle.normal,
                      color: active ? InkColors.text : InkColors.textMuted,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Une réplique affichée avec son gras et son italique.
class MarkupText extends StatelessWidget {
  const MarkupText(this.markup, {super.key, this.style, this.maxLines, this.overflow});

  final String markup;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) {
    if (!hasMarks(markup)) return Text(markup, style: style, maxLines: maxLines, overflow: overflow);
    return Text.rich(markupTextSpan(markup), style: style, maxLines: maxLines, overflow: overflow);
  }
}

/// Morceaux stylés d'une réplique, à mettre dans un [Text.rich].
TextSpan markupTextSpan(String markup, {TextStyle? style}) => TextSpan(
      style: style,
      children: [
        for (final s in markupSpans(markup))
          TextSpan(
            text: s.text,
            style: TextStyle(
              fontWeight: s.bold ? FontWeight.w600 : null,
              fontStyle: s.italic ? FontStyle.italic : null,
            ),
          ),
      ],
    );
