import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

import '../data/library_repository.dart';
import '../data/models.dart';
import '../data/overlay_settings.dart';
import '../theme/ink.dart';
import 'overlay_messages.dart';
import 'playback.dart';

/// Transforme les lignes stockées d'une histoire en parties à dérouler.
Future<List<PlayPart>> loadPlayParts(LibraryRepository library, int storyId) async {
  final parts = <PlayPart>[];
  for (final part in await library.parts(storyId)) {
    final rows = await library.lines(part.id);
    final children = <int, List<LineRow>>{};
    for (final row in rows) {
      if (row.parentId != null) children.putIfAbsent(row.parentId!, () => []).add(row);
    }

    PlayLine toLine(LineRow r) => PlayLine(kind: r.kind.name, text: r.text, speaker: r.speaker, id: r.id);

    final items = <PlayItem>[];
    for (final row in rows.where((r) => r.parentId == null)) {
      if (row.kind == LineRowKind.choice) {
        items.add(PlayItem.choice([
          for (final option in children[row.id] ?? const <LineRow>[])
            PlayOption(label: option.text, lines: [for (final l in children[option.id] ?? const <LineRow>[]) toLine(l)]),
        ]));
      } else if (row.kind != LineRowKind.option) {
        items.add(PlayItem.line(toLine(row)));
      }
    }
    parts.add(PlayPart(title: part.displayTitle, items: items));
  }
  return parts;
}

/// Résultat d'un lancement, pour l'écran qui l'a demandé.
enum LaunchResult { opened, permissionDenied }

/// Ouvre la fenêtre flottante et lui envoie l'histoire, côté app.
class OverlayLauncher {
  OverlayLauncher({required this.library, required this.settings}) {
    settings.addListener(_sendSettings);
  }

  final LibraryRepository library;
  final OverlaySettings settings;

  StreamSubscription<Object?>? _sub;
  Map<String, Object?>? _lastLoad;
  var _nextId = DateTime.now().millisecondsSinceEpoch;

  Future<bool> hasPermission() => FlutterOverlayWindow.isPermissionGranted();

  /// Ouvre l'écran système d'autorisation ; vrai une fois accordée.
  Future<bool> requestPermission() async => await FlutterOverlayWindow.requestPermission() ?? false;

  /// Affiche la partie [partIndex] de l'histoire dans la fenêtre flottante.
  ///
  /// [screenWidth] : largeur de l'écran en points, pour la largeur de la fenêtre.
  Future<LaunchResult> launch({
    required int storyId,
    required String storyTitle,
    required int partIndex,
    required double screenWidth,
    bool admin = false,
  }) async {
    if (!await hasPermission()) return LaunchResult.permissionDenied;

    // La fenêtre peut répondre « prête » avant ou après notre envoi : on
    // garde le message pour le renvoyer à ce moment-là.
    _sub ??= FlutterOverlayWindow.overlayListener.listen((message) {
      switch (OverlayMessages.typeOf(message)) {
        case OverlayMessages.ready when _lastLoad != null:
          unawaited(FlutterOverlayWindow.shareData(_lastLoad));
        case OverlayMessages.edited:
          onEdited(message! as Map<Object?, Object?>);
      }
    });

    final parts = await loadPlayParts(library, storyId);
    _lastLoad = OverlayMessages.loadMessage(
      id: _nextId++,
      storyTitle: storyTitle,
      parts: parts,
      startPart: partIndex,
      opacity: settings.opacity,
      fontSize: settings.textSize.fontSize,
      admin: admin,
      speakers: admin ? await library.speakers(storyId) : const [],
    );

    if (!await FlutterOverlayWindow.isActive()) {
      await FlutterOverlayWindow.showOverlay(
        width: (screenWidth - 16).round(),
        height: 120,
        alignment: OverlayAlignment.topLeft,
        startPosition: const OverlayPosition(8, 120),
        flag: OverlayFlag.defaultFlag,
        enableDrag: false,
        positionGravity: PositionGravity.auto,
        overlayTitle: 'LADS Trad',
        overlayContent: 'Traduction de « $storyTitle » affichée',
        visibility: NotificationVisibility.visibilityPublic,
        dismissConfig: const OverlayDismissConfig(
          size: 56,
          bottomMargin: 48,
          backgroundColor: Color(0xEB0B0D14),
          iconColor: InkColors.text,
          borderColor: Color(0x29EEF0F5),
          borderWidth: 1,
          activeBackgroundColor: InkColors.accent,
          activeIconColor: InkColors.bg,
          activeBorderColor: InkColors.accent,
        ),
      );
    }
    await FlutterOverlayWindow.shareData(_lastLoad);
    return LaunchResult.opened;
  }

  /// La fenêtre a enregistré une modification dans la base : les écrans de
  /// l'app se rechargent, et l'histoire gardée pour un redémarrage de la
  /// fenêtre prend le nouveau texte.
  @visibleForTesting
  void onEdited(Map<Object?, Object?> message) {
    library.refresh();
    final load = _lastLoad;
    final id = message['lineId'] as int?;
    final text = message['text'] as String?;
    final kind = message['kind'] as String?;
    if (load == null || id == null || text == null || kind == null) return;
    final speaker = message['speaker'] as String?;
    final playback = Playback([
      for (final p in load['parts']! as List<Object?>) PlayPart.fromJson(p! as Map<Object?, Object?>),
    ])..updateLine(id, text: text, speaker: speaker, kind: kind);
    final speakers = [...(load['speakers'] as List<Object?>? ?? const []).cast<String>()];
    if (speaker != null && !speakers.contains(speaker)) speakers.add(speaker);
    _lastLoad = {...load, 'parts': [for (final p in playback.parts) p.toJson()], 'speakers': speakers};
  }

  /// Réglage changé dans l'app : la fenêtre ouverte le prend en compte tout de suite.
  Future<void> _sendSettings() async {
    try {
      if (!await FlutterOverlayWindow.isActive()) return;
      await FlutterOverlayWindow.shareData(
        OverlayMessages.settingsMessage(opacity: settings.opacity, fontSize: settings.textSize.fontSize),
      );
    } on Object {
      // Fenêtre indisponible (tests, autre plateforme) : rien à mettre à jour.
    }
  }
}
