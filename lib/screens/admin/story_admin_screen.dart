import 'package:material_ui/material_ui.dart';

import '../../app.dart';
import '../../data/services.dart';
import '../../theme/ink.dart';
import '../../widgets/ink_widgets.dart';
import 'admin_page.dart';

class StoryAdminScreen extends StatelessWidget {
  const StoryAdminScreen({super.key, required this.storyId});

  final int storyId;

  Future<void> _delete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: InkColors.raised,
        title: const Text('Supprimer l\'histoire ?'),
        content: const Text('Ses parties, ses répliques et sa couverture seront effacées de ce téléphone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFF28B82)),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await context.library.deleteStory(storyId);
    if (!context.mounted) return;
    Navigator.popUntil(context, (route) => route.settings.name == Routes.folder || route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return AdminPage(
      title: 'Fiche de l\'histoire',
      children: [
        const InkComingSoon(text: 'Couverture, titre, personnage et dossier : modifiables à l\'étape 5.'),
        const SizedBox(height: 32),
        const InkSectionLabel('Contenu'),
        InkGroup(
          children: [
            AdminLink(
              label: 'Modifier les répliques',
              icon: Icons.edit_note_rounded,
              onTap: () => Navigator.pushNamed(context, Routes.editor),
            ),
            AdminLink(
              label: 'Exporter en .docx',
              icon: Icons.download_outlined,
              onTap: () => Navigator.pushNamed(context, Routes.export),
            ),
          ],
        ),
        const SizedBox(height: 32),
        OutlinedButton.icon(
          onPressed: () => _delete(context),
          style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFF28B82)),
          icon: const Icon(Icons.delete_outline_rounded, size: 18),
          label: const Text('Supprimer l\'histoire'),
        ),
      ],
    );
  }
}
