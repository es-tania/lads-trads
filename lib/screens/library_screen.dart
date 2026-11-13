import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../app.dart';
import '../state/admin_mode.dart';
import '../theme/ink.dart';
import '../widgets/ink_widgets.dart';

/// Données de démonstration de l'étape 1. Elles viendront de la base à l'étape 3.
const _characters = ['Rafayel', 'Xavier', 'Zayne', 'Sylus', 'Caleb'];
const _folders = ['Memoria 5★', 'Memoria 4★', 'Myths', 'Secret Time', 'Tender Moment'];

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  String _character = _characters.first;

  void _toggleAdmin() {
    HapticFeedback.mediumImpact();
    adminMode.value = !adminMode.value;
    showStepSnack(context, adminMode.value ? 'Mode admin activé' : 'Mode admin désactivé');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ValueListenableBuilder<bool>(
        valueListenable: adminMode,
        builder: (context, admin, _) => SafeArea(
          bottom: false,
          child: ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              _header(admin),
              const SizedBox(height: 16),
              _characterTabs(),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const InkSectionLabel('Ajoutées récemment'),
                    const InkComingSoon(
                      text: 'Les dernières histoires importées s\'afficheront ici, avec leur couverture.',
                    ),
                    const SizedBox(height: 32),
                    InkSectionLabel(
                      'Dossiers de $_character',
                      trailing: admin
                          ? TextButton.icon(
                              onPressed: () => Navigator.pushNamed(context, Routes.newFolder),
                              icon: const Icon(Icons.add_rounded, size: 16),
                              label: const Text('Nouveau dossier'),
                            )
                          : null,
                    ),
                    InkGroup(
                      children: [
                        for (final folder in _folders)
                          InkRow(
                            label: folder,
                            leading: const Icon(Icons.folder_outlined, size: 18, color: InkColors.textFaint),
                            trailing: const Icon(Icons.chevron_right_rounded, size: 18, color: InkColors.textFaint),
                            onTap: () => Navigator.pushNamed(context, Routes.folder, arguments: folder),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(bool admin) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(admin ? 'Traductions FR · admin' : 'Traductions FR', style: InkText.eyebrow),
                const SizedBox(height: 4),
                // Appui long : bascule le mode admin (connexion à l'étape 6).
                GestureDetector(
                  onLongPress: _toggleAdmin,
                  child: const Text('Bibliothèque', style: InkText.screenTitle),
                ),
              ],
            ),
          ),
          IconButton.outlined(
            tooltip: 'Rechercher',
            onPressed: () => showStepSnack(context, 'La recherche arrivera à l\'étape 3.'),
            style: IconButton.styleFrom(
              backgroundColor: InkColors.surface,
              side: const BorderSide(color: InkColors.border),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.search_rounded, size: 18),
          ),
          if (admin) ...[
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: () => Navigator.pushNamed(context, Routes.import),
              style: FilledButton.styleFrom(
                minimumSize: const Size(44, 44),
                padding: const EdgeInsets.only(left: 10, right: 12),
                textStyle: const TextStyle(fontFamily: InkFonts.ui, fontSize: 14, fontWeight: FontWeight.w500),
              ),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Importer'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _characterTabs() {
    return SizedBox(
      height: 32,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _characters.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final name = _characters[i];
          final selected = name == _character;
          return Semantics(
            selected: selected,
            button: true,
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => setState(() => _character = name),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? InkColors.raised : null,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: selected ? InkColors.borderStrong : const Color(0x00000000)),
                ),
                child: Text(
                  name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
                    color: selected ? InkColors.text : InkColors.textMuted,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
