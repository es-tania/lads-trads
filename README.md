# LADS Trad

App Android (Flutter) qui affiche les traductions françaises des histoires de
*Love and Deepspace*, réplique par réplique, dans une fenêtre flottante
au-dessus du jeu.

## Lancer l'app

```bash
flutter pub get
flutter run
```

## Organisation

- `lib/theme/ink.dart` : thème sombre « ink » (couleurs, polices, styles).
- `lib/app.dart` : routes et navigation.
- `lib/screens/` : écrans joueur ; `lib/screens/admin/` : écrans admin.
- `assets/fonts/` : Instrument Sans, Figtree et JetBrains Mono (licence SIL OFL).

## Étapes

1. Projet, thème et navigation entre écrans vides.
2. Parseur .docx (FR/EN alignés).
3. Base locale et écrans Bibliothèque, Dossier, Histoire.
4. Fenêtre flottante au-dessus du jeu.
5. Écrans admin : import, fiche, éditeur, export.
6. Passage sur Supabase.
7. (v2) Synchronisation par capture d'écran et OCR.
