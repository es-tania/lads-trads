import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lads_trad/app.dart';
import 'package:lads_trad/state/admin_mode.dart';

/// Écran de téléphone : 390 × 844 points, comme la maquette.
void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

void main() {
  setUp(() => adminMode.value = false);

  testWidgets('La bibliothèque mène à un dossier puis à une histoire', (tester) async {
    _phone(tester);
    await tester.pumpWidget(const LadsTradApp());
    expect(find.text('Bibliothèque'), findsOneWidget);
    expect(find.text('Importer'), findsNothing);

    await tester.tap(find.text('Memoria 5★'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Into The Canvas'));
    await tester.pumpAndSettle();
    expect(find.text('Kindled'), findsOneWidget);
    expect(find.text('Modifier'), findsNothing);
  });

  testWidgets('Un appui long sur « Bibliothèque » affiche les boutons admin', (tester) async {
    _phone(tester);
    await tester.pumpWidget(const LadsTradApp());
    await tester.longPress(find.text('Bibliothèque'));
    await tester.pumpAndSettle();
    expect(find.text('Importer'), findsOneWidget);
    expect(find.text('Nouveau dossier'), findsOneWidget);

    await tester.tap(find.text('Importer'));
    await tester.pumpAndSettle();
    expect(find.text('Importer une histoire'), findsOneWidget);
  });
}
