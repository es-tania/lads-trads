import 'playback.dart';

/// Messages échangés entre l'app et la fenêtre flottante (en JSON).
///
/// App → fenêtre : [loadMessage] (une histoire à afficher), [settingsMessage].
/// Fenêtre → app : [readyMessage], envoyé au démarrage de la fenêtre pour
/// recevoir l'histoire si elle est arrivée trop tôt.
abstract final class OverlayMessages {
  static const ready = 'ready';
  static const load = 'load';
  static const settings = 'settings';

  static Map<String, Object?> readyMessage() => {'type': ready};

  static Map<String, Object?> settingsMessage({required double opacity, required double fontSize}) =>
      {'type': settings, 'opacity': opacity, 'fontSize': fontSize};

  static Map<String, Object?> loadMessage({
    required int id,
    required String storyTitle,
    required List<PlayPart> parts,
    required int startPart,
    required double opacity,
    required double fontSize,
  }) =>
      {
        'type': load,
        // Un nouvel identifiant à chaque lancement : la fenêtre ignore un
        // message déjà reçu (il peut arriver deux fois, voir [ready]).
        'id': id,
        'title': storyTitle,
        'parts': [for (final p in parts) p.toJson()],
        'startPart': startPart,
        'opacity': opacity,
        'fontSize': fontSize,
      };

  static String? typeOf(Object? message) =>
      message is Map ? message['type'] as String? : null;
}
