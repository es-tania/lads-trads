import 'package:material_ui/material_ui.dart';

import '../../../app.dart';
import '../../../data/library_repository.dart';
import '../../../data/models.dart';
import '../../../data/services.dart';
import 'line_sheet.dart';
import 'option_sheet.dart';
import 'editor_bars.dart';
import 'line_list.dart';

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
              child: EditorHeader(title: story?.title ?? '', part: 'Aucune partie', saved: false),
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
                EditorHeader(title: story.title, part: part.displayTitle, saved: _saved),
                if (data.parts.length > 1)
                  EditorPartTabs(
                    parts: data.parts,
                    selected: index,
                    onChanged: (i) => setState(() {
                      _partIndex = i;
                      _selected = null;
                    }),
                  ),
                Expanded(
                  child: EditorLineList(
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
          bottomNavigationBar: EditorBottomBar(
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
