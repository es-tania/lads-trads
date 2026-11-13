import 'package:material_ui/material_ui.dart';

import '../../widgets/ink_widgets.dart';
import 'admin_page.dart';

class ExportScreen extends StatelessWidget {
  const ExportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AdminPage(
      modal: true,
      title: 'Exporter en .docx',
      bottomLabel: 'Télécharger',
      onBottom: () => showStepSnack(context, 'L\'export .docx arrive à l\'étape 5.'),
      children: const [
        InkComingSoon(text: 'Choix de la langue et des parties à exporter.'),
      ],
    );
  }
}
