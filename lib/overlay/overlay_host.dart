import 'dart:async';
import 'dart:ui' show Rect;

import 'package:flutter_overlay_window/flutter_overlay_window.dart';

/// Ce que la fenêtre flottante demande au système (taille, position,
/// messages avec l'app). Une interface pour pouvoir la tester sans téléphone.
///
/// Toutes les mesures sont en points (dp), comme dans Flutter.
abstract class OverlayHost {
  /// Change la taille de la fenêtre. [drag] : déplacement natif au doigt,
  /// avec aimantation au bord et cible × pour fermer (mode bulle).
  Future<void> resize(int width, int height, {required bool drag});

  /// Place le coin haut gauche de la fenêtre.
  Future<void> move(double x, double y);

  Future<({double x, double y})?> position();

  Future<({double width, double height})?> screenSize();

  /// Zone de la fenêtre depuis laquelle le système la fait glisser au doigt,
  /// sans cible de fermeture (la fenêtre ne se ferme pas par erreur).
  Future<void> setDragHandle(Rect area);

  /// Messages envoyés par l'app.
  Stream<Object?> get messages;

  Future<void> send(Object? message);
}

/// Implémentation réelle, via flutter_overlay_window.
class PluginOverlayHost implements OverlayHost {
  Stream<Object?>? _messages;

  @override
  Future<void> resize(int width, int height, {required bool drag}) =>
      FlutterOverlayWindow.resizeOverlay(width, height, drag);

  @override
  Future<void> move(double x, double y) =>
      FlutterOverlayWindow.moveOverlay(OverlayPosition(x, y));

  @override
  Future<({double x, double y})?> position() async {
    try {
      final p = await FlutterOverlayWindow.getOverlayPosition();
      return (x: p.x, y: p.y);
    } on Object {
      return null;
    }
  }

  @override
  Future<({double width, double height})?> screenSize() async {
    try {
      final s = await FlutterOverlayWindow.getScreenSize();
      return s.x > 0 ? (width: s.x, height: s.y) : null;
    } on Object {
      return null;
    }
  }

  @override
  Future<void> setDragHandle(Rect area) => FlutterOverlayWindow.setDragHandle(
        left: area.left,
        top: area.top,
        width: area.width,
        height: area.height,
      );

  // Le flux du plugin ne peut être écouté qu'une fois : on le partage.
  @override
  Stream<Object?> get messages => _messages ??= FlutterOverlayWindow.overlayListener.asBroadcastStream();

  @override
  Future<void> send(Object? message) => FlutterOverlayWindow.shareData(message);
}
