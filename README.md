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
6. Passage sur Supabase :
   - 6a. Histoires, dossiers et personnages en ligne ; lecture par l'app.
   - 6b. Brouillons : une histoire n'est visible des joueurs qu'une fois publiée.
   - 6c. Publication programmée : date et heure de mise en ligne choisies par l'admin.
7. Préparation à la publication :
   - 7a. Page d'accueil : sorties récentes, et d'autres choses plus tard.
   - 7b. Tri des histoires d'un dossier : date de sortie, ordre alphabétique, ordre du jeu.
   - 7c. Tuto au premier lancement, avec l'explication de la permission d'affichage par-dessus les autres applis.
   - 7d. Paramètres : réglages de la fenêtre, revoir le tuto, aide, à propos, version.
   - 7e. À propos et mentions : traductrice, avertissement d'app de fan non officielle, licences.
   - 7f. Politique de confidentialité (page web + lien dans l'app).
   - 7g. Icône et écran de démarrage.
8. (v2) Synchronisation par capture d'écran et OCR.
