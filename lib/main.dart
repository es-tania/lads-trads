import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'data/device_library.dart';
import 'data/overlay_settings.dart';
import 'data/services.dart';
import 'overlay/overlay_app.dart';
import 'overlay/overlay_host.dart';
import 'theme/ink.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(InkTheme.systemUi);
  _registerFontLicenses();

  final library = await openDeviceLibrary();
  final settings = OverlaySettings(await SharedPreferences.getInstance());

  runApp(Services(library: library, settings: settings, child: const LadsTradApp()));
}

/// Point d'entrée de la fenêtre flottante, lancé par le système dans un
/// moteur Flutter séparé (le nom « overlayMain » est attendu par le plugin).
@pragma('vm:entry-point')
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(OverlayApp(host: PluginOverlayHost()));
}

/// Les trois polices sont sous licence SIL OFL : on les déclare dans
/// l'écran des licences de l'app.
void _registerFontLicenses() {
  const fonts = {
    'Instrument Sans': 'OFL-instrumentsans.txt',
    'Figtree': 'OFL-figtree.txt',
    'JetBrains Mono': 'OFL-jetbrainsmono.txt',
  };
  LicenseRegistry.addLicense(() async* {
    for (final MapEntry(key: name, value: file) in fonts.entries) {
      final text = await rootBundle.loadString('assets/fonts/$file');
      yield LicenseEntryWithLineBreaks([name], text);
    }
  });
}
