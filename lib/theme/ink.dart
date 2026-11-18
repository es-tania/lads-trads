import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

/// Couleurs du thème « ink » (maquette validée).
abstract final class InkColors {
  // Fonds, du plus profond au plus élevé.
  static const bg = Color(0xFF0B0D14);
  static const surface = Color(0xFF11141C);
  static const raised = Color(0xFF1A1E28);

  /// Barre du bas de l'éditeur, plus sombre que le fond.
  static const sunken = Color(0xFF07080D);

  /// Fond de la fenêtre flottante et de sa bulle (fond à 92 %).
  static const overlayBg = Color(0xEB0B0D14);

  /// Assombrit l'écran derrière un panneau du bas.
  static const barrier = Color(0x99050610);

  /// Assombrit l'image autour du cadre de recadrage (fond à 62 %).
  static const cropShade = Color(0x9E0B0D14);

  static const transparent = Color(0x00000000);

  // Bordures fines.
  static const border = Color(0x14EEF0F5); // rgba(238,240,245,0.08)
  static const borderSoft = Color(0x1AEEF0F5); // 0.10, panneaux, fenêtre flottante, contour des images
  static const borderStrong = Color(0x29EEF0F5); // 0.16, puces actives et pointillés
  static const borderDashed = Color(0x33EEF0F5); // 0.20, cercle vide d'un personnage

  /// Poignée en haut des panneaux.
  static const grabber = Color(0xFF2A2F3C);

  /// Trait sur le texte barré d'une réplique supprimée.
  static const strike = Color(0x4DEEF0F5);

  // Textes.
  static const text = Color(0xFFEEF0F5);
  static const textMuted = Color(0xFFA3A9B8);
  static const textFaint = Color(0xFF7A8296);

  // Accent corail.
  static const accent = Color(0xFFF2946B);

  /// Contour de la réplique choisie dans l'éditeur (accent à 50 %).
  static const accentSoft = Color(0x80F2946B);

  /// Messages d'erreur.
  static const error = Color(0xFFF28B82);

  /// Actions qui suppriment.
  static const danger = Color(0xFFE5484D);
  static const dangerBorder = Color(0x4DE5484D);

  // Personnages.
  static const rafayel = Color(0xFFF2A0B8);
  static const moi = Color(0xFFB8C4FF);
  static const autre = Color(0xFF8FD3C4);

  static Color forSpeaker(String name) => switch (name.trim().toLowerCase()) {
        'rafayel' => rafayel,
        'moi' => moi,
        _ => autre,
      };
}

/// Familles de polices, intégrées à l'app (voir assets/fonts).
abstract final class InkFonts {
  static const ui = 'InstrumentSans';
  static const display = 'Figtree';
  static const mono = 'JetBrainsMono';
}

/// Espacements récurrents.
abstract final class InkSpacing {
  /// Marges d'un bouton serré contre un autre, pour que son texte tienne
  /// sur une ligne (le thème en met 24 de chaque côté).
  static const compactButton = EdgeInsets.symmetric(horizontal: 12);
}

/// Styles de texte récurrents de la maquette.
abstract final class InkText {
  /// Libellé d'un champ, légende.
  static const label = TextStyle(fontSize: 13, color: InkColors.textMuted);

  /// Indication discrète (« Aucune image pour l'instant »…).
  static const hint = TextStyle(fontSize: 13, color: InkColors.textFaint);

  /// Message d'erreur sous un champ.
  static const error = TextStyle(fontSize: 13, color: InkColors.error);

  /// Texte d'un bouton, en taille normale et en petit.
  static const button = TextStyle(fontFamily: InkFonts.ui, fontSize: 15);
  static const buttonSmall = TextStyle(fontFamily: InkFonts.ui, fontSize: 14);

  static const screenTitle = TextStyle(
    fontFamily: InkFonts.display,
    fontSize: 30,
    height: 1.1,
    fontWeight: FontWeight.w600,
    color: InkColors.text,
  );

  static const eyebrow = TextStyle(
    fontFamily: InkFonts.ui,
    fontSize: 13,
    color: InkColors.textMuted,
  );

  static const sectionLabel = TextStyle(
    fontFamily: InkFonts.ui,
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: InkColors.textMuted,
  );

  static const row = TextStyle(
    fontFamily: InkFonts.ui,
    fontSize: 15,
    fontWeight: FontWeight.w500,
    color: InkColors.text,
  );

  static const body = TextStyle(
    fontFamily: InkFonts.ui,
    fontSize: 15,
    height: 1.4,
    color: InkColors.textMuted,
  );

  /// Compteurs (L.012/022, nombre d'histoires…).
  static const count = TextStyle(
    fontFamily: InkFonts.mono,
    fontSize: 12,
    color: InkColors.textFaint,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// Texte d'une réplique (overlay, éditeur).
  static const dialogue = TextStyle(
    fontFamily: InkFonts.display,
    fontSize: 15,
    height: 1.35,
    color: InkColors.text,
  );
}

abstract final class InkTheme {
  static const _overlayStyle = SystemUiOverlayStyle(
    statusBarColor: Color(0x00000000),
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: InkColors.bg,
    systemNavigationBarIconBrightness: Brightness.light,
  );

  static SystemUiOverlayStyle get systemUi => _overlayStyle;

  static ThemeData get dark {
    const scheme = ColorScheme.dark(
      primary: InkColors.text,
      onPrimary: InkColors.bg,
      secondary: InkColors.accent,
      onSecondary: InkColors.bg,
      surface: InkColors.bg,
      onSurface: InkColors.text,
      surfaceContainerLowest: InkColors.bg,
      surfaceContainerLow: InkColors.surface,
      surfaceContainer: InkColors.surface,
      surfaceContainerHigh: InkColors.raised,
      surfaceContainerHighest: InkColors.raised,
      onSurfaceVariant: InkColors.textMuted,
      outline: InkColors.borderStrong,
      outlineVariant: InkColors.border,
      error: InkColors.error,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      fontFamily: InkFonts.ui,
      scaffoldBackgroundColor: InkColors.bg,
      splashFactory: InkSparkle.splashFactory,
      dividerColor: InkColors.border,
    );

    final shape10 = RoundedRectangleBorder(borderRadius: BorderRadius.circular(10));

    return base.copyWith(
      textTheme: base.textTheme.apply(
        bodyColor: InkColors.text,
        displayColor: InkColors.text,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: InkColors.bg,
        foregroundColor: InkColors.textMuted,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: _overlayStyle,
      ),
      dividerTheme: const DividerThemeData(color: InkColors.border, thickness: 1, space: 1),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: InkColors.text,
          foregroundColor: InkColors.bg,
          minimumSize: const Size(44, 48),
          shape: shape10,
          textStyle: const TextStyle(
            fontFamily: InkFonts.ui,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          backgroundColor: InkColors.surface,
          foregroundColor: InkColors.text,
          minimumSize: const Size(44, 44),
          side: const BorderSide(color: InkColors.border),
          shape: shape10,
          textStyle: const TextStyle(fontFamily: InkFonts.ui, fontSize: 14),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: InkColors.textMuted,
          minimumSize: const Size(44, 44),
          shape: shape10,
          textStyle: const TextStyle(fontFamily: InkFonts.ui, fontSize: 13),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: InkColors.textMuted,
          minimumSize: const Size(44, 44),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: InkColors.raised,
        contentTextStyle: TextStyle(fontFamily: InkFonts.ui, fontSize: 14, color: InkColors.text),
        behavior: SnackBarBehavior.floating,
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: InkColors.accent,
        thumbColor: InkColors.accent,
        inactiveTrackColor: InkColors.raised,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? InkColors.bg : InkColors.textFaint,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? InkColors.accent : InkColors.raised,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: InkColors.surface,
        hintStyle: const TextStyle(color: InkColors.textFaint),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: InkColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: InkColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: InkColors.accent),
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {TargetPlatform.android: FadeForwardsPageTransitionsBuilder()},
      ),
    );
  }
}
