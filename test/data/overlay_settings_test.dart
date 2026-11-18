import 'package:flutter_test/flutter_test.dart';
import 'package:lads_trad/data/overlay_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<OverlaySettings> open([Map<String, Object> values = const {}]) async {
    SharedPreferences.setMockInitialValues(values);
    return OverlaySettings(await SharedPreferences.getInstance());
  }

  test('valeurs par défaut', () async {
    final settings = await open();
    expect(settings.opacity, 0.85);
    expect(settings.textSize, OverlayTextSize.medium);
  });

  test("l'opacité reste entre 0,2 et 1", () async {
    final settings = await open();
    await settings.setOpacity(0.05);
    expect(settings.opacity, OverlaySettings.minOpacity);
    await settings.setOpacity(3);
    expect(settings.opacity, OverlaySettings.maxOpacity);
    await settings.setOpacity(0.5);
    expect(settings.opacity, 0.5);
  });

  test('la taille du texte est gardée', () async {
    final settings = await open();
    await settings.setTextSize(OverlayTextSize.large);
    expect(settings.textSize, OverlayTextSize.large);
    expect(settings.textSize.fontSize, 18);
    expect((await open({'overlay.textSize': 'large'})).textSize, OverlayTextSize.large);
  });

  test('une taille inconnue revient à « moyen »', () async {
    expect((await open({'overlay.textSize': 'énorme'})).textSize, OverlayTextSize.medium);
  });

  test('prévient ses auditeurs', () async {
    final settings = await open();
    var calls = 0;
    settings.addListener(() => calls++);
    await settings.setOpacity(0.4);
    await settings.setTextSize(OverlayTextSize.small);
    expect(calls, 2);
  });
}
