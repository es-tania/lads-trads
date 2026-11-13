import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../theme/ink.dart';
import 'overlay_host.dart';
import 'overlay_messages.dart';
import 'playback.dart';

/// Marge entre la fenêtre et les bords de l'écran.
const _margin = 8.0;

/// Taille de la bulle réduite.
const _bubbleWidth = 64;
const _bubbleHeight = 56;

/// Zone de la poignée dans la fenêtre (en points) : un peu plus grande que
/// l'icône, pour l'attraper facilement au doigt.
const _gripArea = Rect.fromLTWH(0, 0, 46, 40);

/// Application affichée dans la fenêtre flottante, au-dessus du jeu.
///
/// Elle tourne dans un moteur Flutter séparé de l'app : elle reçoit
/// l'histoire par message ([OverlayMessages.loadMessage]).
class OverlayApp extends StatelessWidget {
  const OverlayApp({super.key, required this.host});

  final OverlayHost host;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: InkTheme.dark.copyWith(scaffoldBackgroundColor: const Color(0x00000000)),
      color: const Color(0x00000000),
      home: Material(type: MaterialType.transparency, child: OverlayScreen(host: host)),
    );
  }
}

class OverlayScreen extends StatefulWidget {
  const OverlayScreen({super.key, required this.host});

  final OverlayHost host;

  @override
  State<OverlayScreen> createState() => _OverlayScreenState();
}

class _OverlayScreenState extends State<OverlayScreen> {
  StreamSubscription<Object?>? _sub;
  int? _loadedId;
  Playback? _playback;
  double _opacity = 0.85;
  double _fontSize = 15;

  bool _bubble = false;
  double _screenWidth = 360;
  double _maxHeight = 320;
  int _reportedHeight = 0;
  ({double x, double y})? _windowPosition;

  /// Mode admin : un crayon permet de corriger la réplique affichée.
  bool _admin = false;

  /// Réplique en cours de modification, `null` en lecture.
  PlayLine? _editing;
  final _editText = TextEditingController();
  String? _editError;
  var _savingEdit = false;

  OverlayHost get host => widget.host;
  int get _windowWidth => (_screenWidth - 2 * _margin).round();

  @override
  void initState() {
    super.initState();
    _sub = host.messages.listen(_onMessage);
    unawaited(_init());
  }

  Future<void> _init() async {
    final screen = await host.screenSize();
    if (screen != null && mounted) {
      setState(() {
        _screenWidth = screen.width;
        _maxHeight = math.max(160, screen.height * 0.45);
      });
    }
    await _declareGrip();
    // Sans attendre la réponse, qui ne vient jamais (voir [OverlayHost.send]).
    unawaited(host.send(OverlayMessages.readyMessage()));
  }

  /// La poignée est déplacée par le système, qui connaît la vraie position
  /// du doigt à l'écran (un calcul côté Flutter fait trembler la fenêtre).
  ///
  /// Redéclarée à chaque chargement, redimensionnement et réouverture : le
  /// service système est recréé à chaque ouverture de la fenêtre, alors que
  /// cette app-ci (son moteur Flutter) reste en vie entre deux ouvertures.
  Future<void> _declareGrip() async {
    try {
      await host.setDragHandle(_gripArea);
    } on Object {
      // Service pas encore prêt : ce sera fait au prochain appel.
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _editText.dispose();
    super.dispose();
  }

  void _onMessage(Object? message) {
    if (message is! Map) return;
    switch (OverlayMessages.typeOf(message)) {
      case OverlayMessages.load:
        final id = message['id'] as int?;
        if (id != null && id == _loadedId) return;
        final parts = [
          for (final p in message['parts']! as List<Object?>) PlayPart.fromJson(p! as Map<Object?, Object?>),
        ];
        if (_editing != null) unawaited(_stopEditing());
        setState(() {
          _loadedId = id;
          _playback = Playback(parts, part: (message['startPart'] as int?) ?? 0);
          _admin = message['admin'] == true;
          _applySettings(message);
          _reportedHeight = 0;
        });
        unawaited(_declareGrip());
        if (_bubble) unawaited(_expand());
      case OverlayMessages.settings:
        setState(() => _applySettings(message));
    }
  }

  void _applySettings(Map<Object?, Object?> message) {
    _opacity = ((message['opacity'] as num?) ?? _opacity).toDouble();
    _fontSize = ((message['fontSize'] as num?) ?? _fontSize).toDouble();
  }

  /// La fenêtre prend la hauteur de son contenu.
  void _onContentHeight(double height) {
    if (_bubble) return;
    final h = height.ceil();
    if ((h - _reportedHeight).abs() <= 1) return;
    _reportedHeight = h;
    unawaited(host.resize(_windowWidth, h, drag: false).then((_) => _declareGrip()));
  }

  // ── Modification pendant la lecture (mode admin) ──────────────────────

  Future<void> _startEditing(PlayLine line) async {
    HapticFeedback.selectionClick();
    setState(() {
      _editing = line;
      _editError = null;
      _editText.text = line.text;
    });
    // Le temps de la modification, la fenêtre reçoit le clavier.
    await host.setKeyboard(true);
  }

  Future<void> _stopEditing() async {
    setState(() {
      _editing = null;
      _savingEdit = false;
    });
    await host.setKeyboard(false);
  }

  Future<void> _saveEditing() async {
    final line = _editing;
    final text = _editText.text.trim();
    if (line?.id == null || text.isEmpty || _savingEdit) return;
    setState(() {
      _savingEdit = true;
      _editError = null;
    });
    try {
      // Une écriture ne prend qu'un instant : au-delà, on le dit plutôt que
      // de laisser « Enregistrement… » affiché indéfiniment.
      await host.saveLineText(line!.id!, text).timeout(const Duration(seconds: 8));
      _playback?.updateText(line.id!, text);
      await _stopEditing();
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _savingEdit = false;
        _editError = e is TimeoutException
            ? "L'enregistrement ne répond pas. Réessaie."
            : 'Enregistrement impossible : $e';
      });
    }
  }

  Future<void> _minimize() async {
    if (_editing != null) await _stopEditing();
    HapticFeedback.selectionClick();
    _windowPosition = await host.position();
    setState(() => _bubble = true);
    await host.resize(_bubbleWidth, _bubbleHeight, drag: true);
    await host.move(_screenWidth - _bubbleWidth, _windowPosition?.y ?? 200);
  }

  Future<void> _expand() async {
    HapticFeedback.selectionClick();
    setState(() => _bubble = false);
    await host.resize(_windowWidth, math.max(_reportedHeight, 80), drag: false);
    final p = _windowPosition;
    await host.move(_margin, p?.y ?? 120);
    await _declareGrip();
  }

  // ── Affichage ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_bubble) return _Bubble(playback: _playback, onTap: _expand);

    final playback = _playback;
    final editing = _editing;
    final reading = editing == null;
    return Align(
      alignment: Alignment.topLeft,
      child: OverflowBox(
        alignment: Alignment.topLeft,
        minHeight: 0,
        maxHeight: double.infinity,
        child: _SizeReporter(
          onHeight: _onContentHeight,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: _maxHeight),
            child: _Window(
              opacity: _opacity,
              onMinimize: _minimize,
              onPrevious: reading && playback != null && playback.canGoBack ? () => setState(playback.previous) : null,
              onNext: reading && playback != null && playback.canGoForward ? () => setState(playback.next) : null,
              child: playback == null || playback.isEmpty
                  ? const _Waiting()
                  : !reading
                      ? _EditView(
                          line: editing,
                          controller: _editText,
                          fontSize: _fontSize,
                          error: _editError,
                          saving: _savingEdit,
                          onCancel: _stopEditing,
                          onSave: _saveEditing,
                        )
                      : _StepView(
                          playback: playback,
                          fontSize: _fontSize,
                          onPick: (i) => setState(() => playback.pick(i)),
                          onChangeBranch: () => setState(playback.changeBranch),
                          onEdit: _admin ? _startEditing : null,
                        ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Cadre de la fenêtre : poignée et ‹ à gauche, « — » et › à droite.
class _Window extends StatelessWidget {
  const _Window({
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
        border: Border.all(color: const Color(0x1AEEF0F5)),
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
                    // zone [_gripArea] : ici, seulement le dessin.
                    Semantics(
                      label: 'Déplacer la fenêtre',
                      child: const SizedBox(
                        width: 34,
                        height: 28,
                        child: Icon(Icons.drag_indicator_rounded, size: 18, color: InkColors.textFaint),
                      ),
                    ),
                    _NavButton(icon: Icons.chevron_left_rounded, label: 'Réplique précédente', onPressed: onPrevious),
                  ],
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(4, 8, 4, 10),
                child: child,
              ),
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
                    _NavButton(icon: Icons.chevron_right_rounded, label: 'Réplique suivante', onPressed: onNext, primary: true),
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

class _NavButton extends StatelessWidget {
  const _NavButton({required this.icon, required this.label, required this.onPressed, this.primary = false});

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
            side: primary ? BorderSide.none : const BorderSide(color: Color(0x1AEEF0F5)),
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

class _Waiting extends StatelessWidget {
  const _Waiting();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Text('Chargement de la traduction…', style: TextStyle(fontSize: 13, color: InkColors.textMuted)),
    );
  }
}

/// Contenu central : une réplique, ou un choix à faire.
class _StepView extends StatelessWidget {
  const _StepView({
    required this.playback,
    required this.fontSize,
    required this.onPick,
    required this.onChangeBranch,
    this.onEdit,
  });

  final Playback playback;
  final double fontSize;
  final ValueChanged<int> onPick;
  final VoidCallback onChangeBranch;

  /// Mode admin : corriger la réplique affichée.
  final ValueChanged<PlayLine>? onEdit;

  @override
  Widget build(BuildContext context) {
    final step = playback.current!;
    final (number, total) = playback.counter;
    final counter = 'L.${_pad(number)}/${_pad(total)}';
    final partTitle = _partTitle(playback.part.title);
    final showPart = playback.atPartStart || step.isChoice;

    final header = <Widget>[
      if (!step.isChoice && step.line!.speaker != null)
        Text(
          step.line!.speaker!,
          style: TextStyle(fontSize: 12, height: 16 / 12, fontWeight: FontWeight.w500, color: InkColors.forSpeaker(step.line!.speaker!)),
        ),
      if (playback.branchLetter != null)
        Text('branche ${playback.branchLetter}', style: const TextStyle(fontSize: 12, height: 16 / 12, color: InkColors.textFaint)),
      Text(
        showPart && partTitle.isNotEmpty ? '$partTitle · $counter' : counter,
        style: InkText.count.copyWith(fontSize: 11, height: 16 / 11),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(child: Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.end, children: header)),
            if (playback.branchLetter != null)
              GestureDetector(
                onTap: onChangeBranch,
                behavior: HitTestBehavior.opaque,
                child: const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Text('Changer de branche', style: TextStyle(fontSize: 12, height: 16 / 12, color: InkColors.accent)),
                ),
              ),
            if (onEdit != null && !step.isChoice && step.line!.id != null)
              Semantics(
                button: true,
                label: 'Modifier la réplique',
                child: GestureDetector(
                  onTap: () => onEdit!(step.line!),
                  behavior: HitTestBehavior.opaque,
                  child: const Padding(
                    padding: EdgeInsets.only(left: 12, right: 2),
                    child: Icon(Icons.edit_outlined, size: 14, color: InkColors.textFaint),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 2),
        if (step.isChoice) _ChoiceView(options: step.choiceOptions!, picked: playback.pickedOption, onPick: onPick)
        else _LineText(line: step.line!, fontSize: fontSize),
      ],
    );
  }

  static String _pad(int n) => n.toString().padLeft(3, '0');

  /// « KINDLED » → « Kindled ».
  static String _partTitle(String title) {
    final letters = title.replaceAll(RegExp(r'[^\p{L}]', unicode: true), '');
    if (letters.isEmpty || letters != letters.toUpperCase()) return title;
    final lower = title.toLowerCase();
    return lower[0].toUpperCase() + lower.substring(1);
  }
}

/// Correction de la réplique affichée, sans quitter le jeu.
class _EditView extends StatelessWidget {
  const _EditView({
    required this.line,
    required this.controller,
    required this.fontSize,
    required this.error,
    required this.saving,
    required this.onCancel,
    required this.onSave,
  });

  final PlayLine line;
  final TextEditingController controller;
  final double fontSize;
  final String? error;
  final bool saving;
  final VoidCallback onCancel;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          line.speaker == null ? 'Modifier la narration' : 'Modifier · ${line.speaker}',
          style: TextStyle(
            fontSize: 12,
            height: 16 / 12,
            fontWeight: FontWeight.w500,
            color: line.speaker == null ? InkColors.textMuted : InkColors.forSpeaker(line.speaker!),
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          autofocus: true,
          minLines: 2,
          maxLines: 5,
          textCapitalization: TextCapitalization.sentences,
          style: InkText.dialogue.copyWith(fontSize: fontSize),
          decoration: const InputDecoration(
            isDense: true,
            contentPadding: EdgeInsets.all(8),
            fillColor: InkColors.surface,
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 4),
          Text(error!, style: const TextStyle(fontSize: 12, color: Color(0xFFF28B82))),
        ],
        const SizedBox(height: 6),
        // Wrap : les deux boutons passent à la ligne si la fenêtre est étroite.
        Wrap(
          alignment: WrapAlignment.end,
          spacing: 4,
          children: [
            TextButton(
              onPressed: saving ? null : onCancel,
              style: TextButton.styleFrom(minimumSize: const Size(44, 32), padding: const EdgeInsets.symmetric(horizontal: 10)),
              child: const Text('Annuler'),
            ),
            ListenableBuilder(
              listenable: controller,
              builder: (context, _) => FilledButton(
                onPressed: saving || controller.text.trim().isEmpty ? null : onSave,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(44, 32),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  textStyle: const TextStyle(fontFamily: InkFonts.ui, fontSize: 13, fontWeight: FontWeight.w500),
                ),
                child: Text(saving ? 'Enregistrement…' : 'Enregistrer'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _LineText extends StatelessWidget {
  const _LineText({required this.line, required this.fontSize});

  final PlayLine line;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Text(
      line.text,
      style: InkText.dialogue.copyWith(
        fontSize: fontSize,
        color: line.isNarration ? InkColors.textMuted : InkColors.text,
        fontStyle: line.isThought ? FontStyle.italic : FontStyle.normal,
      ),
    );
  }
}

class _ChoiceView extends StatelessWidget {
  const _ChoiceView({required this.options, required this.picked, required this.onPick});

  final List<PlayOption> options;
  final int? picked;
  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Quel choix as-tu fait ?', style: TextStyle(fontSize: 13, color: InkColors.textMuted)),
        const SizedBox(height: 8),
        for (final (i, option) in options.indexed) ...[
          if (i > 0) const SizedBox(height: 6),
          Material(
            color: InkColors.raised,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: picked == i ? InkColors.accent : const Color(0x1AEEF0F5)),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () {
                HapticFeedback.selectionClick();
                onPick(i);
              },
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 40),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: Row(
                    children: [
                      Text(String.fromCharCode(65 + i), style: InkText.count.copyWith(color: InkColors.textMuted)),
                      const SizedBox(width: 10),
                      Expanded(child: Text(option.label, style: const TextStyle(fontFamily: InkFonts.display, fontSize: 15))),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Bulle réduite : touche pour rouvrir, glisse sur le × pour fermer
/// (géré par le système : déplacement, aimantation au bord, cible ×).
class _Bubble extends StatelessWidget {
  const _Bubble({required this.playback, required this.onTap});

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
            color: const Color(0xEB0B0D14),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0x1AEEF0F5)),
          ),
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('FR', style: TextStyle(fontSize: 13, height: 16 / 13, fontWeight: FontWeight.w500)),
              if (number != null)
                Text(
                  'L.${number.toString().padLeft(3, '0')}',
                  style: InkText.count.copyWith(fontSize: 11, height: 16 / 11, color: InkColors.textMuted),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Signale la hauteur de son enfant après chaque mise en page.
class _SizeReporter extends SingleChildRenderObjectWidget {
  const _SizeReporter({required this.onHeight, required super.child});

  final ValueChanged<double> onHeight;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderSizeReporter(onHeight);

  @override
  void updateRenderObject(BuildContext context, _RenderSizeReporter renderObject) {
    renderObject.onHeight = onHeight;
  }
}

class _RenderSizeReporter extends RenderProxyBox {
  _RenderSizeReporter(this.onHeight);

  ValueChanged<double> onHeight;
  double? _last;

  @override
  void performLayout() {
    super.performLayout();
    final h = size.height;
    if (h != _last) {
      _last = h;
      // Après la mise en page : on ne peut pas changer l'état pendant.
      WidgetsBinding.instance.addPostFrameCallback((_) => onHeight(h));
    }
  }
}
