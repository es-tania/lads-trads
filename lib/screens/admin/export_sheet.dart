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
    showInkSheet<void>(
      context,
      builder: (_) => ExportSheet(story: story, target: target),
    );

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
    await SharePlus.instance.share(
      ShareParams(
        subject: subject,
        files: [for (final f in files) XFile.fromData(f.bytes, name: f.name, mimeType: _docxMime)],
        fileNameOverrides: [for (final f in files) f.name],
      ),
    );
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
  var _busy = false;

  Future<void> _run({required bool share}) async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final files = [await exportStory(context.library, widget.story.id)];
      if (share) {
        await widget.target.share(files, subject: widget.story.title);
      } else {
        final saved = await widget.target.save(files);
        if (saved > 0) {
          messenger
            ..hideCurrentSnackBar()
            ..showSnackBar(const SnackBar(content: Text('Fichier enregistré.')));
          if (mounted) Navigator.pop(context);
          return;
        }
      }
    } on Object catch (e) {
      if (mounted) showInkSnack(context, 'Export impossible : $e');
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkSheetHeader(eyebrow: widget.story.title, title: 'Exporter en .docx'),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: InkColors.bg, borderRadius: BorderRadius.circular(10)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(exportFileName(widget.story.title), style: InkText.count.copyWith(color: InkColors.text)),
              const SizedBox(height: 4),
              const Text("Même mise en forme que tes fichiers d'origine, donc réimportable", style: InkText.hint),
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
                  backgroundColor: InkColors.transparent,
                  minimumSize: const Size(44, 48),
                  textStyle: InkText.button,
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

