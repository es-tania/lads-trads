import 'package:material_ui/material_ui.dart';

import '../../widgets/ink_widgets.dart';
import 'admin_page.dart';

class EditLineScreen extends StatelessWidget {
  const EditLineScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AdminPage(
      modal: true,
      title: 'Modifier la réplique',
      bottomLabel: 'Enregistrer',
      onBottom: () => Navigator.maybePop(context),
      children: const [
        InkComingSoon(
          text: 'Type (réplique, pensée, narration), personnage, texte et note de traduction.',
        ),
      ],
    );
  }
}
