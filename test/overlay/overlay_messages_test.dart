import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lads_trad/overlay/overlay_messages.dart';
import 'package:lads_trad/overlay/playback.dart';

/// Comme sur le canal entre l'app et la fenêtre : le message passe en JSON.
Map<Object?, Object?> overTheWire(Map<String, Object?> message) =>
    jsonDecode(jsonEncode(message)) as Map<Object?, Object?>;

void main() {
  test("typeOf lit le type d'un message, ou rien", () {
    expect(OverlayMessages.typeOf(overTheWire(OverlayMessages.readyMessage())), OverlayMessages.ready);
    expect(OverlayMessages.typeOf('texte'), isNull);
    expect(OverlayMessages.typeOf(null), isNull);
  });

  test("l'histoire envoyée se relit à l'identique", () {
    const parts = [
      PlayPart(title: 'ÉPISODE 1', items: [
        PlayItem.line(PlayLine(kind: 'dialogue', text: 'Bonjour', speaker: 'Rafayel', id: 4)),
        PlayItem.choice([
          PlayOption(label: 'Oui', lines: [PlayLine(kind: 'narration', text: 'Il sourit.')]),
        ]),
      ]),
    ];
    final message = overTheWire(OverlayMessages.loadMessage(
      id: 2,
      storyTitle: 'Into the Canvas',
      parts: parts,
      startPart: 0,
      opacity: 0.8,
      fontSize: 15,
      admin: true,
      speakers: ['Rafayel', 'Moi'],
      storyId: 9,
    ));

    expect(OverlayMessages.typeOf(message), OverlayMessages.load);
    expect(message['title'], 'Into the Canvas');
    expect(message['admin'], isTrue);
    expect(message['speakers'], ['Rafayel', 'Moi']);
    expect(message['storyId'], 9);

    final back = [for (final p in message['parts']! as List<Object?>) PlayPart.fromJson(p! as Map<Object?, Object?>)];
    expect(jsonEncode([for (final p in back) p.toJson()]), jsonEncode([for (final p in parts) p.toJson()]));
  });

  test('une modification passe le personnage, ou null pour une narration', () {
    final message = overTheWire(
      OverlayMessages.editedMessage(lineId: 3, text: 'Salut', speaker: null, kind: 'narration'),
    );
    expect(OverlayMessages.typeOf(message), OverlayMessages.edited);
    expect(message['lineId'], 3);
    expect(message['speaker'], isNull);
    expect(message['kind'], 'narration');
  });

  test("un renommage passe l'ancien et le nouveau nom", () {
    final message = overTheWire(OverlayMessages.renamedMessage(from: '??', to: 'Caleb'));
    expect(OverlayMessages.typeOf(message), OverlayMessages.renamed);
    expect([message['from'], message['to']], ['??', 'Caleb']);
  });
}
