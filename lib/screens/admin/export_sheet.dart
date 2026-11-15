import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/models.dart';
import '../../data/services.dart';
import '../../docx/story_export.dart';
import '../../theme/ink.dart';
import '../../widgets/ink_widgets.dart';
import '../../widgets/ink_sheet.dart';

const _docxMime = 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';

/// Panneau « Exporter en .docx » d'une histoire.
Future<void> showExportSheet(BuildContext context, Story story, {ExportTarget target = const _DeviceExportTarget()}) =>
    showInkSheet<void>(context, builder: (_) => ExportSheet(story: story, target: target));

/// Enregistre ou partage les fichiers produits. Remplaçable dans les tests.
abstract class ExportTarget {
  /// Enregistre chaque fichier là où la traductrice le choisit ; renvoie le
  /// nombre de fichiers enregistrés (0 si elle a annulé).
  Future<int> save(List<ExportFile> files);

  Future<void> share(List<ExportFile> files, {required String subject});
}

class _DeviceExportTarget implements ExportTarget {
  const _DeviceExportTarget();

  @override
  Future<int> save(List<ExportFile> files) async {
    var saved = 0;
    for (final f in files) {
      // L'écran Android « Enregistrer sous », un fichier après l'autre.
      final uri = await FilePicker.saveFile(fileName: f.name, bytes: f.bytes, mimeType: _docxMime);
      if (uri != null) saved++;
    }
    return saved;
  }

  @override
  Future<void> share(List<ExportFile> files, {required String subject}) async {
    await SharePlus.instance.share(ShareParams(
      subject: subject,
      files: [for (final f in files) XFile.fromData(f.bytes, name: f.name, mimeType: _docxMime)],
      fileNameOverrides: [for (final f in files) f.name],
    ));
  }
}

class ExportSheet extends StatefulWidget {
  const ExportSheet({super.key, required this.story, this.target = const _DeviceExportTarget()});

  final Story story;
  final ExportTarget target;

  @override
  State<ExportSheet> createState() => _ExportSheetState();
}

class _ExportSheetState extends State<ExportSheet> {
  var _language = ExportLanguage.fr;
  var _notes = false;
  var _busy = false;

  /// L'anglais n'a pas de notes : elles sont sur la traduction.
  bool get _notesApply => _language != ExportLanguage.en;

  Future<void> _run({required bool share}) async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final files = await exportStory(
        context.library,
        widget.story.id,
        language: _language,
        notes: _notes && _notesApply,
      );
      if (share) {
        await widget.target.share(files, subject: widget.story.title);
      } else {
        final saved = await widget.target.save(files);
        if (saved > 0) {
          messenger
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(saved == 1 ? 'Fichier enregistré.' : '$saved fichiers enregistrés.')));
          if (mounted) Navigator.pop(context);
          return;
        }
      }
    } on Object catch (e) {
      if (mounted) showStepSnack(context, 'Export impossible : $e');
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final names = exportFileNames(widget.story.title, _language);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkSheetHeader(eyebrow: widget.story.title, title: 'Exporter en .docx'),
        const SizedBox(height: 20),
        const Text('Langue', style: TextStyle(fontSize: 13, color: InkColors.textMuted)),
        const SizedBox(height: 8),
        _LanguageList(value: _language, onChanged: (l) => setState(() => _language = l)),
        const SizedBox(height: 20),
        Opacity(
          opacity: _notesApply ? 1 : 0.4,
          child: SwitchListTile(
            value: _notes && _notesApply,
            onChanged: _notesApply ? (v) => setState(() => _notes = v) : null,
            contentPadding: EdgeInsets.zero,
            title: const Text('Inclure mes notes de traduction', style: TextStyle(fontSize: 15)),
            subtitle: const Text(
              'En commentaires Word, dans la marge',
              style: TextStyle(fontSize: 13, color: InkColors.textFaint),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: InkColors.bg, borderRadius: BorderRadius.circular(10)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final name in names) ...[
                Text(name, style: InkText.count.copyWith(color: InkColors.text)),
                const SizedBox(height: 4),
              ],
              Text(
                _language == ExportLanguage.bilingual
                    ? 'Pour relire : ce fichier ne se réimporte pas'
                    : "Même mise en forme que tes fichiers d'origine, donc réimportable",
                style: const TextStyle(fontSize: 13, color: InkColors.textFaint),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _busy ? null : () => _run(share: true),
                style: OutlinedButton.styleFrom(
                  backgroundColor: const Color(0x00000000),
                  minimumSize: const Size(44, 48),
                  textStyle: const TextStyle(fontFamily: InkFonts.ui, fontSize: 15),
                ),
                icon: const Icon(Icons.share_outlined, size: 16, color: InkColors.textMuted),
                label: const Text('Partager'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton(
                onPressed: _busy ? null : () => _run(share: false),
                child: Text(_busy ? 'Export…' : 'Télécharger'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Boutons radio des langues, avec une explication sous chacune.
class _LanguageList extends StatelessWidget {
  const _LanguageList({required this.value, required this.onChanged});

  final ExportLanguage value;
  final ValueChanged<ExportLanguage> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: InkColors.bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: InkColors.border),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          children: [
            for (final (i, language) in ExportLanguage.values.indexed) ...[
              if (i > 0) const SizedBox(height: 2),
              _option(language, language == value),
            ],
          ],
        ),
      ),
    );
  }

  Widget _option(ExportLanguage language, bool selected) {
    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      button: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => onChanged(language),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(color: selected ? InkColors.raised : null, borderRadius: BorderRadius.circular(8)),
          child: Row(
            children: [
              Container(
                width: 16,
                height: 16,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: selected ? InkColors.accent : InkColors.textFaint, width: 1.5),
                ),
                child: selected
                    ? Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(color: InkColors.accent, shape: BoxShape.circle),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(language.label, style: const TextStyle(fontSize: 15, color: InkColors.text)),
                    const SizedBox(height: 2),
                    Text(language.hint, style: const TextStyle(fontSize: 13, color: InkColors.textFaint)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
