# Modifications pour LADS Trad

Copie de [flutter_overlay_window](https://pub.dev/packages/flutter_overlay_window) 1.0.2
(licence MIT, voir LICENSE), modifiée pour la fenêtre de traduction :

- **Glissement depuis une poignée** : `FlutterOverlayWindow.setDragHandle(...)` déclare
  une zone de la fenêtre. Un appui qui commence dans cette zone fait glisser la fenêtre
  nativement (coordonnées d'écran réelles, pas de tremblement), même si `enableDrag` est
  faux. Ce glissement n'affiche pas la cible de fermeture et n'aimante pas la fenêtre au
  bord : seule la bulle peut être fermée en la glissant sur le ×.
- Fichiers touchés : `OverlayService.java` (`onTouch`, `isInDragHandle`, méthode
  `setDragHandle`) et `lib/src/overlay_window.dart`.
