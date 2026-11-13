import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'app.dart';
import 'theme/ink.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(InkTheme.systemUi);
  _registerFontLicenses();
  runApp(const LadsTradApp());
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
