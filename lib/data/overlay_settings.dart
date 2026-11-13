import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum OverlayTextSize {
  small(13),
  medium(15),
  large(18);

  const OverlayTextSize(this.fontSize);

  /// Taille du texte des répliques dans la fenêtre flottante.
  final double fontSize;
}

/// Réglages de la fenêtre de traduction, gardés sur le téléphone.
class OverlaySettings extends ChangeNotifier {
  OverlaySettings(this._prefs);

  final SharedPreferences _prefs;

  static const _opacityKey = 'overlay.opacity';
  static const _textSizeKey = 'overlay.textSize';

  static const minOpacity = 0.2;
  static const maxOpacity = 1.0;

  /// Opacité du fond de la fenêtre, de 0,2 à 1.
  double get opacity => _prefs.getDouble(_opacityKey) ?? 0.85;

  OverlayTextSize get textSize =>
      OverlayTextSize.values.asNameMap()[_prefs.getString(_textSizeKey)] ?? OverlayTextSize.medium;

  Future<void> setOpacity(double value) async {
    await _prefs.setDouble(_opacityKey, value.clamp(minOpacity, maxOpacity));
    notifyListeners();
  }

  Future<void> setTextSize(OverlayTextSize value) async {
    await _prefs.setString(_textSizeKey, value.name);
    notifyListeners();
  }
}
