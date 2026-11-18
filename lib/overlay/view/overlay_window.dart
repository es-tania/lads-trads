/// Cadre de la fenêtre flottante : poignée, boutons, bulle réduite.
library;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../text/line_labels.dart';
import '../../theme/ink.dart';
import '../playback.dart';

/// Zone de la poignée dans la fenêtre (en points) : un peu plus grande que
/// l'icône, pour l'attraper facilement au doigt.
const overlayGripArea = Rect.fromLTWH(0, 0, 46, 40);

/// Cadre de la fenêtre : poignée et ‹ à gauche, « — » et › à droite.
class OverlayWindow extends StatelessWidget {
  const OverlayWindow({
    super.key,
    required this.opacity,
    required this.onMinimize,
    required this.onPrevious,
    required this.onNext,
    required this.child,
  });

  final double opacity;
  final VoidCallback onMinimize;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: InkColors.bg.withValues(alpha: opacity),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: InkColors.borderSoft),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 42,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 0, 4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Le glissement lui-même est fait par le système, dans la
                    // zone [overlayGripArea] : ici, seulement le dessin.
                    Semantics(
                      label: 'Déplacer la fenêtre',
                      child: const SizedBox(
                        width: 34,
                        height: 28,
                        child: Icon(Icons.drag_indicator_rounded, size: 18, color: InkColors.textFaint),
                      ),
                    ),
                    OverlayNavButton(
                      icon: Icons.chevron_left_rounded,
                      label: 'Réplique précédente',
                      onPressed: onPrevious,
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(4, 8, 4, 10), child: child),
            ),
            SizedBox(
              width: 42,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 4, 4, 4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Semantics(
                      button: true,
                      label: 'Réduire',
                      child: InkWell(
                        borderRadius: BorderRadius.circular(6),
                        onTap: onMinimize,
                        child: const SizedBox(
                          width: 34,
                          height: 28,
                          child: Icon(Icons.remove_rounded, size: 16, color: InkColors.textFaint),
                        ),
                      ),
                    ),
                    OverlayNavButton(
                      icon: Icons.chevron_right_rounded,
                      label: 'Réplique suivante',
                      onPressed: onNext,
                      primary: true,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class OverlayNavButton extends StatelessWidget {
  const OverlayNavButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.primary = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: Opacity(
        opacity: enabled ? 1 : 0.35,
        child: Material(
          color: primary ? InkColors.text : InkColors.raised,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: primary ? BorderSide.none : const BorderSide(color: InkColors.borderSoft),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: onPressed == null
                ? null
                : () {
                    HapticFeedback.selectionClick();
                    onPressed!();
                  },
            child: SizedBox(
              width: 34,
              height: 34,
              child: Icon(icon, size: 18, color: primary ? InkColors.bg : InkColors.text),
            ),
          ),
        ),
      ),
    );
  }
}

class OverlayWaiting extends StatelessWidget {
  const OverlayWaiting({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Text('Chargement de la traduction…', style: InkText.label),
    );
  }
}

/// Bulle réduite : touche pour rouvrir, glisse sur le × pour fermer
/// (géré par le système : déplacement, aimantation au bord, cible ×).
class OverlayBubble extends StatelessWidget {
  const OverlayBubble({super.key, required this.playback, required this.onTap});

  final Playback? playback;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final number = playback == null || playback!.isEmpty ? null : playback!.counter.$1;
    return Semantics(
      button: true,
      label: number == null ? 'Rouvrir la traduction' : 'Rouvrir la traduction, réplique $number',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: InkColors.overlayBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: InkColors.borderSoft),
          ),
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'FR',
                style: TextStyle(fontSize: 13, height: 16 / 13, fontWeight: FontWeight.w500),
              ),
              if (number != null)
                Text(
                  lineLabel(number),
                  style: InkText.count.copyWith(fontSize: 11, height: 16 / 11, color: InkColors.textMuted),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
