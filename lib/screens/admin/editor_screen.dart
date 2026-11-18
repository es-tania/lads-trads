import 'package:material_ui/material_ui.dart';

import '../../app.dart';
import '../../data/library_repository.dart';
import '../../data/models.dart';
import '../../data/services.dart';
import '../../theme/ink.dart';
import '../../widgets/markup_field.dart';
import 'line_sheet.dart';
import '../../text/line_labels.dart';
import '../../widgets/one_line_label.dart';

/// Ce que l'éditeur affiche pour une partie.
typedef _EditorData = ({Story? story, List<Part> parts, List<LineRow> lines, List<String> speakers});

/// Éditeur des répliques d'une histoire, partie par partie. Chaque
/// modification est enregistrée tout de suite.
class EditorScreen extends StatefulWidget {
  const EditorScreen({super.key, required this.storyId});

  final int storyId;

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  var _partIndex = 0;

  /// Dernière réplique modifiée ou ajoutée : surlignée, avec le « + » après.
  int? _selected;
  var _saved = false;

  Future<_EditorData> _load(LibraryRepository library) async {
    final story = await library.story(widget.storyId);
    final parts = story == null ? const <Part>[] : await library.parts(story.id);
    final index = _partIndex.clamp(0, parts.isEmpty ? 0 : parts.length - 1);
    return (
      story: story,
      parts: parts,
      lines: parts.isEmpty ? const <LineRow>[] : await library.lines(parts[index].id),
      speakers: story == null ? const <String>[] : await library.speakers(story.id),
    );
  }

  void _done(int? lineId) {
    if (!mounted) return;
    setState(() {
      _selected = lineId;
      _saved = true;
    });
  }

  Future<void> _editLine(_EditorData data, Part part, LineRow line, String where) async {
    final result = await showLineSheet(
      context,
      eyebrow: '${part.displayTitle} · $where',
      storyId: widget.storyId,
      speakers: data.speakers,
      line: line,
    );
    if (!mounted || result == null) return;
    final library = context.library;
    switch (result) {
      case LineSaved(:final draft):
        await library.updateLine(line.id, kind: draft.kind, text: draft.text, speaker: draft.speaker);
        _done(line.id);
      case LineInsert(:final after):
        await _newLine(
          data,
          part,
          eyebrow: '${part.displayTitle} · ${after ? 'après' : 'avant'} $where',
          like: line,
          save: (d) => library.insertLineNextTo(
            line.id,
            after: after,
            kind: d.kind,
            text: d.text,
            speaker: d.speaker,
          ),
        );
      case LineDeleted():
        await library.deleteLine(line.id);
        _done(null);
    }
  }

  /// Ouvre le panneau pour une nouvelle réplique, puis l'enregistre avec [save].
  Future<void> _newLine(
    _EditorData data,
    Part part, {
    required String eyebrow,
    required Future<int> Function(LineDraft draft) save,
    LineRow? like,
  }) async {
    // Par défaut, même type et même personnage que la réplique voisine.
    final initial = like == null ? null : LineDraft(kind: like.kind, text: '', speaker: like.speaker);
    final result = await showLineSheet(
      context,
      eyebrow: eyebrow,
      storyId: widget.storyId,
      speakers: data.speakers,
      initial: initial,
    );
    if (result is LineSaved) _done(await save(result.draft));
  }

  Future<void> _editOption(Part part, LineRow option, String letter, int branchLines) async {
    final result = await showOptionSheet(
      context,
      eyebrow: '${part.displayTitle} · choix',
      title: 'Branche $letter',
      option: option,
      branchLines: branchLines,
    );
    if (!mounted || result == null) return;
    final library = context.library;
    switch (result) {
      case OptionSaved(:final label):
        await library.updateOptionLabel(option.id, label);
        _done(null);
      case OptionDeleted():
        await library.deleteLine(option.id);
        _done(null);
    }
  }

  Future<void> _addOption(Part part, LineRow choice, String letter) async {
    final result = await showOptionSheet(context, eyebrow: '${part.displayTitle} · choix', title: 'Branche $letter');
    if (!mounted || result is! OptionSaved) return;
    await context.library.addOption(choice.id, result.label);
    _done(null);
  }

  @override
  Widget build(BuildContext context) {
    return LibraryQuery<_EditorData>(
      args: _partIndex,
      load: _load,
      builder: (context, data) {
        final story = data.story;
        if (story == null || data.parts.isEmpty) {
          return Scaffold(
            body: SafeArea(
              child: _Header(title: story?.title ?? '', part: 'Aucune partie', saved: false),
            ),
          );
        }
        final index = _partIndex.clamp(0, data.parts.length - 1);
        final part = data.parts[index];
        final library = context.library;

        return Scaffold(
          body: SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Header(title: story.title, part: part.displayTitle, saved: _saved),
                if (data.parts.length > 1)
                  _PartTabs(
                    parts: data.parts,
                    selected: index,
                    onChanged: (i) => setState(() {
                      _partIndex = i;
                      _selected = null;
                    }),
                  ),
                Expanded(
                  child: _LineList(
                    lines: data.lines,
                    selected: _selected,
                    onEdit: (line, where) => _editLine(data, part, line, where),
                    onInsertAfter: (line, where) => _newLine(
                      data,
                      part,
                      eyebrow: '${part.displayTitle} · après $where',
                      like: line,
                      save: (d) => library.insertLineNextTo(
                        line.id,
                        after: true,
                        kind: d.kind,
                        text: d.text,
                        speaker: d.speaker,
                      ),
                    ),
                    onEditOption: (option, letter, n) => _editOption(part, option, letter, n),
                    onAddOption: (choice, letter) => _addOption(part, choice, letter),
                    onAddToBranch: (option, letter) => _newLine(
                      data,
                      part,
                      eyebrow: '${part.displayTitle} · branche $letter',
                      save: (d) => library.appendLine(
                        part.id,
                        optionId: option.id,
                        kind: d.kind,
                        text: d.text,
                        speaker: d.speaker,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: _BottomBar(
            onImport: () => Navigator.pushNamed(context, Routes.replaceContent, arguments: story.id),
            onAdd: () => _newLine(
              data,
              part,
              eyebrow: '${part.displayTitle} · à la fin',
              like: data.lines.where((l) => l.parentId == null && l.kind.isSpoken).lastOrNull,
              save: (d) => library.appendLine(part.id, kind: d.kind, text: d.text, speaker: d.speaker),
            ),
          ),
        );
      },
    );
  }
}


class _Header extends StatelessWidget {
  const _Header({required this.title, required this.part, required this.saved});

  final String title;
  final String part;
  final bool saved;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 12, 0),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Retour',
            onPressed: () => Navigator.maybePop(context),
            icon: const Icon(Icons.chevron_left_rounded, size: 24),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: InkText.eyebrow, maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(
                  part,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
          if (saved) const Text('Enregistré', style: InkText.hint),
        ],
      ),
    );
  }
}

/// Onglets des parties : répartis sur la largeur, ou défilants s'il y en a beaucoup.
class _PartTabs extends StatelessWidget {
  const _PartTabs({required this.parts, required this.selected, required this.onChanged});

  final List<Part> parts;
  final int selected;
  final ValueChanged<int> onChanged;

  /// « Épisode 3 » → « Ép. 3 » pour tenir dans un onglet.
  static String short(Part part) => part.displayTitle.replaceFirst(RegExp(r'^[ÉéEe]pisode\s+'), 'Ép. ');

  @override
  Widget build(BuildContext context) {
    Widget tab(int i) {
      final on = i == selected;
      return Semantics(
        selected: on,
        button: true,
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () => onChanged(i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            alignment: Alignment.center,
            decoration: BoxDecoration(color: on ? InkColors.raised : null, borderRadius: BorderRadius.circular(6)),
            child: Text(
              short(parts[i]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: on ? FontWeight.w500 : FontWeight.w400,
                color: on ? InkColors.text : InkColors.textMuted,
              ),
            ),
          ),
        ),
      );
    }

    final many = parts.length > 5;
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: InkColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: InkColors.border),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: many
            ? SizedBox(
                height: 32,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: parts.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 4),
                  itemBuilder: (_, i) => tab(i),
                ),
              )
            : Row(
                children: [
                  for (var i = 0; i < parts.length; i++) ...[
                    if (i > 0) const SizedBox(width: 4),
                    Expanded(child: tab(i)),
                  ],
                ],
              ),
      ),
    );
  }
}

/// Répliques d'une partie, choix et branches compris.
class _LineList extends StatelessWidget {
  const _LineList({
    required this.lines,
    required this.selected,
    required this.onEdit,
    required this.onInsertAfter,
    required this.onEditOption,
    required this.onAddOption,
    required this.onAddToBranch,
  });

  final List<LineRow> lines;
  final int? selected;

  /// [where] : « L.003 » ou « branche A », pour le surtitre du panneau.
  final void Function(LineRow line, String where) onEdit;
  final void Function(LineRow line, String where) onInsertAfter;
  final void Function(LineRow option, String letter, int branchLines) onEditOption;
  final void Function(LineRow choice, String nextLetter) onAddOption;
  final void Function(LineRow option, String letter) onAddToBranch;

  @override
  Widget build(BuildContext context) {
    final children = <int, List<LineRow>>{};
    for (final l in lines) {
      if (l.parentId != null) children.putIfAbsent(l.parentId!, () => []).add(l);
    }

    final rows = <Widget>[];
    // Même numérotation que la fenêtre flottante : un choix compte les
    // répliques de sa première branche.
    var number = 0;
    for (final line in lines.where((l) => l.parentId == null)) {
      if (line.kind == LineRowKind.option) continue;
      if (line.kind == LineRowKind.choice) {
        final options = children[line.id] ?? const <LineRow>[];
        rows.add(
          _ChoiceBlock(
            number: lineLabel(number + 1),
            options: [for (final o in options) (o, children[o.id] ?? const <LineRow>[])],
            selected: selected,
            onEdit: onEdit,
            onInsertAfter: onInsertAfter,
            onEditOption: onEditOption,
            onAddOption: () => onAddOption(line, optionLetter(options.length)),
            onAddToBranch: onAddToBranch,
          ),
        );
        number += options.isEmpty ? 0 : (children[options.first.id] ?? const []).length;
        if (selected == line.id) rows.add(_InsertDivider(onTap: () => onInsertAfter(line, 'le choix')));
        continue;
      }
      number++;
      final where = lineLabel(number);
      rows.add(_LineTile(number: where, line: line, selected: selected == line.id, onTap: () => onEdit(line, where)));
      if (selected == line.id) rows.add(_InsertDivider(onTap: () => onInsertAfter(line, where)));
    }
    if (rows.isEmpty) {
      rows.add(
        const Padding(
          padding: EdgeInsets.all(20),
          child: Text('Aucune réplique dans cette partie.', style: InkText.body),
        ),
      );
    }

    return ListView(padding: const EdgeInsets.fromLTRB(12, 8, 12, 24), children: rows);
  }
}

class _LineTile extends StatelessWidget {
  const _LineTile({required this.number, required this.line, required this.selected, required this.onTap});

  final String number;
  final LineRow line;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          decoration: selected
              ? BoxDecoration(
                  color: InkColors.raised,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: InkColors.accentSoft),
                )
              : null,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 40,
                child: Text(
                  number,
                  style: InkText.count.copyWith(height: 20 / 12, color: selected ? InkColors.accent : null),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(child: _LineText(line: line)),
              if (selected)
                const Padding(
                  padding: EdgeInsets.only(left: 8, top: 2),
                  child: Icon(Icons.edit_outlined, size: 16, color: InkColors.textMuted),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Personnage au-dessus du texte.
class _LineText extends StatelessWidget {
  const _LineText({required this.line, this.compact = false});

  final LineRow line;

  /// Dans une branche : personnage et texte sur la même ligne.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final speaker = line.speaker;
    final narration = line.kind == LineRowKind.narration || speaker == null;
    final textStyle = TextStyle(
      fontFamily: InkFonts.display,
      fontSize: 17,
      height: 1.4,
      color: narration ? InkColors.textMuted : InkColors.text,
      fontStyle: line.kind == LineRowKind.thought ? FontStyle.italic : FontStyle.normal,
    );
    final speakerStyle = TextStyle(
      fontFamily: InkFonts.ui,
      fontSize: 13,
      fontWeight: FontWeight.w500,
      fontStyle: FontStyle.normal,
      color: narration ? InkColors.textMuted : InkColors.forSpeaker(speaker),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (compact)
          Text.rich(
            TextSpan(
              children: [
                if (!narration) TextSpan(text: '$speaker  ', style: speakerStyle),
                markupTextSpan(line.text, style: textStyle),
              ],
            ),
          )
        else ...[
          if (!narration) ...[Text(speaker, style: speakerStyle), const SizedBox(height: 2)],
          MarkupText(line.text, style: textStyle),
        ],
      ],
    );
  }
}

class _ChoiceBlock extends StatelessWidget {
  const _ChoiceBlock({
    required this.number,
    required this.options,
    required this.selected,
    required this.onEdit,
    required this.onInsertAfter,
    required this.onEditOption,
    required this.onAddOption,
    required this.onAddToBranch,
  });

  final String number;
  final List<(LineRow, List<LineRow>)> options;
  final int? selected;
  final void Function(LineRow line, String where) onEdit;
  final void Function(LineRow line, String where) onInsertAfter;
  final void Function(LineRow option, String letter, int branchLines) onEditOption;
  final VoidCallback onAddOption;
  final void Function(LineRow option, String letter) onAddToBranch;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 40,
            child: Text(number, style: InkText.count.copyWith(height: 28 / 12)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Choix',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: InkColors.textMuted),
                      ),
                    ),
                    TextButton(
                      onPressed: onAddOption,
                      style: TextButton.styleFrom(
                        minimumSize: const Size(44, 28),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      child: const Text('Ajouter une branche'),
                    ),
                  ],
                ),
                for (final (i, (option, branch)) in options.indexed) ...[
                  const SizedBox(height: 12),
                  _Branch(
                    letter: optionLetter(i),
                    option: option,
                    lines: branch,
                    selected: selected,
                    onEdit: onEdit,
                    onInsertAfter: onInsertAfter,
                    onEditOption: () => onEditOption(option, optionLetter(i), branch.length),
                    onAdd: () => onAddToBranch(option, optionLetter(i)),
                  ),
                ],
                const SizedBox(height: 12),
                Text('--- suite commune', style: InkText.count),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Branch extends StatelessWidget {
  const _Branch({
    required this.letter,
    required this.option,
    required this.lines,
    required this.selected,
    required this.onEdit,
    required this.onInsertAfter,
    required this.onEditOption,
    required this.onAdd,
  });

  final String letter;
  final LineRow option;
  final List<LineRow> lines;
  final int? selected;
  final void Function(LineRow line, String where) onEdit;
  final void Function(LineRow line, String where) onInsertAfter;
  final VoidCallback onEditOption;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final where = 'branche $letter';
    return Container(
      padding: const EdgeInsets.only(left: 12),
      decoration: const BoxDecoration(
        border: Border(left: BorderSide(color: InkColors.borderStrong)),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: onEditOption,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: '$letter  ', style: InkText.count),
                      TextSpan(text: option.text),
                    ],
                  ),
                  style: InkText.label,
                ),
              ),
            ),
            for (final line in lines) ...[
              InkWell(
                borderRadius: BorderRadius.circular(6),
                onTap: () => onEdit(line, where),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                  decoration: selected == line.id
                      ? BoxDecoration(
                          color: InkColors.raised,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: InkColors.accentSoft),
                        )
                      : null,
                  child: _LineText(line: line, compact: true),
                ),
              ),
              if (selected == line.id) _InsertDivider(indent: 0, onTap: () => onInsertAfter(line, where)),
            ],
            if (lines.isEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: onAdd,
                  style: TextButton.styleFrom(
                    minimumSize: const Size(44, 32),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                  ),
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text('Ajouter une réplique'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Fine ligne avec un « + » : insère une réplique à cet endroit.
class _InsertDivider extends StatelessWidget {
  const _InsertDivider({required this.onTap, this.indent = 48});

  final VoidCallback onTap;
  final double indent;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Insérer une réplique ici',
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 32,
          child: Padding(
            padding: EdgeInsets.only(left: indent + 8, right: 8),
            child: const Row(
              children: [
                Expanded(child: Divider()),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(Icons.add_rounded, size: 16, color: InkColors.textFaint),
                ),
                Expanded(child: Divider()),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.onImport, required this.onAdd});

  final VoidCallback onImport;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: InkColors.sunken,
        border: Border(top: BorderSide(color: InkColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Row(
            children: [
              OutlinedButton.icon(
                onPressed: onImport,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(44, 48),
                  padding: InkSpacing.compactButton,
                  textStyle: InkText.button,
                ),
                icon: const Icon(Icons.upload_outlined, size: 18, color: InkColors.textMuted),
                label: const Text('Importer'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: onAdd,
                  style: FilledButton.styleFrom(padding: InkSpacing.compactButton),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const OneLineLabel('Ajouter une réplique'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
