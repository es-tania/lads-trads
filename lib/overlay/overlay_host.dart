import 'dart:async';
import 'dart:ui' show Rect;

import 'package:flutter_overlay_window/flutter_overlay_window.dart';

import '../data/device_library.dart';
import '../data/library_repository.dart';
import 'overlay_messages.dart';

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

  /// Laisse la fenêtre recevoir le clavier (pendant une modification), ou
  /// le rend au jeu.
  Future<void> setKeyboard(bool enabled);

  /// Enregistre le texte et le personnage d'une ligne dans la base du
  /// téléphone ([speaker] `null` : narration). Renvoie le type obtenu
  /// (« dialogue », « thought » ou « narration »).
  Future<String> saveLine(int lineId, {required String text, required String? speaker});

  /// Renomme un personnage dans toutes les répliques de l'histoire [storyId].
  Future<void> renameSpeaker(int storyId, {required String from, required String to});

  /// Messages envoyés par l'app.
  Stream<Object?> get messages;

  /// Envoie un message à l'app. Depuis la fenêtre, le Future ne se termine
  /// jamais (le service Android ne renvoie pas de réponse) : ne pas l'attendre.
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

  @override
  Future<void> setKeyboard(bool enabled) =>
      FlutterOverlayWindow.updateFlag(enabled ? OverlayFlag.focusPointer : OverlayFlag.defaultFlag);

  LibraryRepository? _library;

  /// La fenêtre écrit elle-même dans la base : l'app est peut-être fermée
  /// pendant la lecture. Si elle est ouverte, elle est prévenue.
  @override
  Future<String> saveLine(int lineId, {required String text, required String? speaker}) async {
    final library = _library ??= await openDeviceLibrary();
    final kind = (await library.updateLineWhileReading(lineId, text: text, speaker: speaker)).name;
    // Sans attendre : le service ne répond jamais à un message de la
    // fenêtre vers l'app (voir [send]).
    unawaited(send(OverlayMessages.editedMessage(
      lineId: lineId,
      text: text.trim(),
      speaker: speaker?.trim().isEmpty ?? true ? null : speaker!.trim(),
      kind: kind,
    )));
    return kind;
  }

  @override
  Future<void> renameSpeaker(int storyId, {required String from, required String to}) async {
    final library = _library ??= await openDeviceLibrary();
    await library.renameSpeaker(from, to, storyId: storyId);
    unawaited(send(OverlayMessages.renamedMessage(from: from, to: to.trim())));
  }

  // Le flux du plugin ne peut être écouté qu'une fois : on le partage.
  @override
  Stream<Object?> get messages => _messages ??= FlutterOverlayWindow.overlayListener.asBroadcastStream();

  @override
  Future<void> send(Object? message) => FlutterOverlayWindow.shareData(message);
}
