import 'package:flutter_test/flutter_test.dart';
import 'package:lads_trad/text/line_labels.dart';

void main() {
  test('numéro sur trois chiffres', () {
    expect(paddedNumber(7), '007');
    expect(paddedNumber(42), '042');
    expect(paddedNumber(1234), '1234');
  });

  test("numéro d'une réplique", () => expect(lineLabel(12), 'L.012'));

  test("lettre d'une branche", () {
    expect(optionLetter(0), 'A');
    expect(optionLetter(2), 'C');
  });
}
