import 'playback.dart';

/// Messages échangés entre l'app et la fenêtre flottante (en JSON).
///
/// App → fenêtre : [loadMessage] (une histoire à afficher), [settingsMessage].
/// Fenêtre → app : [readyMessage], envoyé au démarrage de la fenêtre pour
/// recevoir l'histoire si elle est arrivée trop tôt ; [editedMessage], après
/// une modification enregistrée pendant la lecture.
abstract final class OverlayMessages {
  static const ready = 'ready';
  static const load = 'load';
  static const settings = 'settings';
  static const edited = 'edited';
  static const renamed = 'renamed';

  /// Un personnage renommé dans toute l'histoire, depuis la fenêtre.
  static Map<String, Object?> renamedMessage({required String from, required String to}) =>
      {'type': renamed, 'from': from, 'to': to};

  /// [speaker] `null` : la ligne est devenue une narration.
  static Map<String, Object?> editedMessage({
    required int lineId,
    required String text,
    required String? speaker,
    required String kind,
  }) =>
      {'type': edited, 'lineId': lineId, 'text': text, 'speaker': speaker, 'kind': kind};

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
    bool admin = false,
    List<String> speakers = const [],
    int? storyId,
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
        // Mode admin : la traductrice peut corriger une réplique en lisant.
        'admin': admin,
        // Personnages de l'histoire, proposés pour corriger qui parle.
        'speakers': speakers,
        // Pour renommer un personnage dans toute l'histoire.
        'storyId': storyId,
      };

  static String? typeOf(Object? message) =>
      message is Map ? message['type'] as String? : null;
}
