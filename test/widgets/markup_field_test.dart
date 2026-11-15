import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lads_trad/text/markup.dart';
import 'package:lads_trad/widgets/markup_field.dart';

void main() {
  test('mettre un passage en gras puis en italique, et le retirer', () {
    final c = MarkupController(markup: 'Tu es là.')..selection = const TextSelection(baseOffset: 3, extentOffset: 5);
    c.toggle(Marks.bold);
    expect(c.markup, 'Tu <b>es</b> là.');
    expect(c.isActive(Marks.bold), isTrue);

    c
      ..selection = const TextSelection(baseOffset: 0, extentOffset: 9)
      ..toggle(Marks.italic);
    expect(c.markup, '<i>Tu </i><b><i>es</i></b><i> là.</i>');

    c
      ..selection = const TextSelection(baseOffset: 3, extentOffset: 5)
      ..toggle(Marks.bold);
    expect(c.markup, '<i>Tu es là.</i>');
    expect(c.text, 'Tu es là.', reason: 'le champ ne montre pas les balises');
  });

  test('un caractère tapé prend le style de celui qui le précède', () {
    final c = MarkupController(markup: 'a<b>bc</b>d');
    // On tape « X » après « bc », puis on efface « a ».
    c.value = const TextEditingValue(text: 'abcXd', selection: TextSelection.collapsed(offset: 4));
    expect(c.markup, 'a<b>bcX</b>d');
    c.value = const TextEditingValue(text: 'bcXd', selection: TextSelection.collapsed(offset: 0));
    expect(c.markup, '<b>bcX</b>d');
  });

  test('sans sélection, G et I ne font rien', () {
    final c = MarkupController(markup: 'Salut')..selection = const TextSelection.collapsed(offset: 2);
    c.toggle(Marks.bold);
    expect(c.markup, 'Salut');
    expect(c.isActive(Marks.bold), isFalse);
  });

  test('remplacer le contenu repart de ses balises', () {
    final c = MarkupController()..markup = '<i>Hm.</i>';
    expect((c.text, c.markup), ('Hm.', '<i>Hm.</i>'));
  });
}
