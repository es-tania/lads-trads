import 'dart:async';
import 'dart:math' as math;

import 'overlay_host.dart';

/// Pendant une modification, garde la fenêtre flottante au-dessus du clavier.
///
/// Le clavier recouvre la fenêtre : elle monte d'autant (plus [gap]). Le
/// clavier se ferme, ou la modification se termine : elle revient là où
/// elle était. Android ne prévient pas la fenêtre quand le clavier se ferme
/// sans la recouvrir : l'état du clavier est donc relu toutes les
/// [interval] tant que la modification dure.
class KeyboardAvoider {
  KeyboardAvoider(this.host, {this.gap = 8, this.interval = const Duration(milliseconds: 250)});

  final OverlayHost host;

  /// Espace laissé entre la fenêtre et le haut du clavier, en points.
  final double gap;
  final Duration interval;

  Timer? _timer;
  ({double x, double y})? _home;
  var _checking = false;

  bool get isActive => _timer != null;

  /// La fenêtre est-elle montée au-dessus du clavier ?
  bool get isRaised => _home != null;

  /// Début de la modification : la fenêtre suit le clavier.
  void start() {
    if (_timer != null) return;
    _timer = Timer.periodic(interval, (_) => unawaited(_check()));
    unawaited(_check());
  }

  /// Fin de la modification : la fenêtre revient à sa place.
  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    await _restore();
  }

  Future<void> _check() async {
    if (_checking) return;
    _checking = true;
    try {
      final keyboard = await host.keyboard();
      if (_timer == null) return;
      if (keyboard.overlap > 0.5 && keyboard.visible != false) {
        final at = await host.position();
        if (at == null || _timer == null) return;
        _home ??= at;
        await host.move(at.x, math.max(0, at.y - keyboard.overlap - gap));
      } else if (keyboard.visible == false) {
        // Avant Android 11, `visible` est inconnu : la fenêtre ne revient
        // qu'à la fin de la modification.
        await _restore();
      }
    } on Object {
      // Service pas prêt, ou fenêtre fermée : on réessaiera au prochain tour.
    } finally {
      _checking = false;
    }
  }

  Future<void> _restore() async {
    final home = _home;
    _home = null;
    if (home != null) await host.move(home.x, home.y);
  }
}
