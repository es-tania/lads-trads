import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../theme/ink.dart';
import '../widgets/markup_field.dart';
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
      theme: InkTheme.dark.copyWith(scaffoldBackgroundColor: InkColors.transparent),
      color: InkColors.transparent,
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

  /// Largeur demandée au système avec [_reportedHeight].
  int _reportedWidth = 0;
  ({double x, double y})? _windowPosition;

  /// Mode admin : un crayon permet de corriger la réplique affichée.
  bool _admin = false;

  /// Personnages de l'histoire, proposés pour corriger qui parle.
  List<String> _speakers = const [];

  /// Réplique en cours de modification, `null` en lecture.
  PlayLine? _editing;
  final _editText = MarkupController();

  /// Personnage choisi pendant la modification (`null` : narration).
  String? _editSpeaker;

  /// Saisie d'un nom (« + Autre », ou « ✎ Renommer »), `null` si fermée.
  TextEditingController? _newSpeaker;

  /// Le champ ci-dessus renomme le personnage choisi (sinon il en ajoute un).
  var _renaming = false;

  /// Histoire affichée, pour renommer un personnage partout dedans.
  int? _storyId;

  /// Liste des personnages dépliée : repliée, seul le personnage choisi est
  /// visible, pour garder la fenêtre basse.
  var _speakersOpen = false;
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
      // La largeur vient de changer, peut-être sans la hauteur : on la redemande.
      if (_reportedHeight > 0 && !_bubble) _requestSize(_reportedHeight);
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
    _newSpeaker?.dispose();
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
          _speakers = [for (final s in message['speakers'] as List<Object?>? ?? const []) s! as String];
          _storyId = message['storyId'] as int?;
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

  /// La fenêtre prend la hauteur de son contenu, et la largeur de l'écran.
  void _onContentHeight(double height) {
    if (_bubble) return;
    final h = height.ceil();
    if ((h - _reportedHeight).abs() <= 1 && _reportedWidth == _windowWidth) return;
    _requestSize(h);
  }

  void _requestSize(int height) {
    _reportedHeight = height;
    _reportedWidth = _windowWidth;
    unawaited(_applySize(height));
  }

  /// Au premier lancement, le service système peut ne pas être prêt quand
  /// la fenêtre demande sa taille : on réessaie, sinon elle resterait à sa
  /// taille de création.
  Future<void> _applySize(int height, {int attempt = 0}) async {
    try {
      await host.resize(_windowWidth, height, drag: false);
      await _declareGrip();
    } on Object {
      if (attempt >= 10 || !mounted) {
        _reportedHeight = 0;
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 300));
      if (mounted && !_bubble && _reportedHeight == height) await _applySize(height, attempt: attempt + 1);
    }
  }

  // ── Modification pendant la lecture (mode admin) ──────────────────────

  Future<void> _startEditing(PlayLine line) async {
    HapticFeedback.selectionClick();
    setState(() {
      _editing = line;
      _editError = null;
      _editText.markup = line.text;
      _editSpeaker = line.isNarration ? null : line.speaker;
      _speakersOpen = false;
      _closeNewSpeaker();
    });
    // Le temps de la modification, la fenêtre reçoit le clavier.
    await host.setKeyboard(true);
  }

  Future<void> _stopEditing() async {
    setState(() {
      _editing = null;
      _savingEdit = false;
      _closeNewSpeaker();
    });
    await host.setKeyboard(false);
  }

  void _closeNewSpeaker() {
    _newSpeaker?.dispose();
    _newSpeaker = null;
    _renaming = false;
  }

  /// « + Autre » : un champ pour un personnage absent de la liste.
  void _openNewSpeaker() => setState(() {
        _closeNewSpeaker();
        _newSpeaker = TextEditingController();
      });

  /// « ✎ Renommer » : le même champ, prérempli avec le personnage choisi.
  void _openRename() => setState(() {
        _closeNewSpeaker();
        _newSpeaker = TextEditingController(text: _editSpeaker);
        _renaming = true;
      });

  Future<void> _confirmNewSpeaker() async {
    final name = _newSpeaker?.text.trim() ?? '';
    if (name.isEmpty) return;
    if (_renaming) return _renameSpeaker(name);
    setState(() {
      if (!_speakers.contains(name)) _speakers = [..._speakers, name];
      _editSpeaker = name;
      _speakersOpen = false;
      _closeNewSpeaker();
    });
  }

  /// Corrige le nom du personnage choisi dans toutes les répliques de
  /// l'histoire.
  Future<void> _renameSpeaker(String to) async {
    final from = _editSpeaker;
    final storyId = _storyId;
    if (from == null || storyId == null || to == from) {
      setState(_closeNewSpeaker);
      return;
    }
    try {
      await host.renameSpeaker(storyId, from: from, to: to).timeout(const Duration(seconds: 8));
    } on Object catch (e) {
      if (mounted) setState(() => _editError = 'Renommage impossible : $e');
      return;
    }
    if (!mounted) return;
    setState(() {
      _playback?.renameSpeaker(from, to);
      _speakers = [for (final s in _speakers) if (s != from && s != to) s, to];
      _editSpeaker = to;
      _speakersOpen = false;
      _editError = null;
      _closeNewSpeaker();
    });
  }

  Future<void> _saveEditing() async {
    final line = _editing;
    final text = _editText.markup.trim();
    if (line?.id == null || text.isEmpty || _savingEdit) return;
    setState(() {
      _savingEdit = true;
      _editError = null;
    });
    try {
      // Une écriture ne prend qu'un instant : au-delà, on le dit plutôt que
      // de laisser « Enregistrement… » affiché indéfiniment.
      final speaker = _editSpeaker;
      final kind = await host.saveLine(line!.id!, text: text, speaker: speaker).timeout(const Duration(seconds: 8));
      _playback?.updateLine(line.id!, text: text, speaker: speaker, kind: kind);
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
                          speakers: [
                            ..._speakers,
                            if (editing.speaker != null && !_speakers.contains(editing.speaker)) editing.speaker!,
                          ],
                          speaker: _editSpeaker,
                          speakersOpen: _speakersOpen,
                          onToggleSpeakers: () => setState(() {
                            _speakersOpen = !_speakersOpen;
                            if (!_speakersOpen) _closeNewSpeaker();
                          }),
                          onSpeaker: (s) => setState(() {
                            _editSpeaker = s;
                            _speakersOpen = false;
                            _closeNewSpeaker();
                          }),
                          newSpeaker: _newSpeaker,
                          renaming: _renaming,
                          onRename: _storyId == null ? null : _openRename,
                          onOther: _openNewSpeaker,
                          onConfirmOther: _confirmNewSpeaker,
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
    required this.speakers,
    required this.speaker,
    required this.speakersOpen,
    required this.onToggleSpeakers,
    required this.onSpeaker,
    required this.newSpeaker,
    required this.renaming,
    required this.onRename,
    required this.onOther,
    required this.onConfirmOther,
    required this.controller,
    required this.fontSize,
    required this.error,
    required this.saving,
    required this.onCancel,
    required this.onSave,
  });

  final List<String> speakers;

  /// Personnage choisi, `null` pour une narration.
  final String? speaker;

  /// Liste des personnages dépliée (sinon : seulement le personnage choisi).
  final bool speakersOpen;
  final VoidCallback onToggleSpeakers;
  final ValueChanged<String?> onSpeaker;

  /// Champ « + Autre » (ou « ✎ Renommer ») ouvert, ou `null`.
  final TextEditingController? newSpeaker;
  final bool renaming;

  /// Renommer le personnage choisi dans toute l'histoire (`null` : impossible).
  final VoidCallback? onRename;
  final VoidCallback onOther;
  final VoidCallback onConfirmOther;
  final MarkupController controller;
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
          speaker == null ? 'Modifier · narration' : 'Modifier · $speaker',
          style: TextStyle(
            fontSize: 12,
            height: 16 / 12,
            fontWeight: FontWeight.w500,
            color: speaker == null ? InkColors.textMuted : InkColors.forSpeaker(speaker!),
          ),
        ),
        const SizedBox(height: 6),
        // Qui parle : replié, une seule puce (le personnage choisi) qui
        // déplie la liste ; déplié, toutes les puces, qui passent à la ligne.
        if (!speakersOpen)
          Align(
            alignment: Alignment.centerLeft,
            child: _SpeakerChip(
              label: speaker ?? 'Narration',
              dot: speaker == null ? null : InkColors.forSpeaker(speaker!),
              selected: true,
              trailing: Icons.expand_more_rounded,
              semanticsLabel: 'Changer de personnage',
              onTap: onToggleSpeakers,
            ),
          )
        else
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final name in speakers)
                _SpeakerChip(label: name, dot: InkColors.forSpeaker(name), selected: name == speaker, onTap: () => onSpeaker(name)),
              _SpeakerChip(label: 'Narration', selected: speaker == null, onTap: () => onSpeaker(null)),
              _SpeakerChip(label: '+ Autre', selected: newSpeaker != null && !renaming, dashed: true, onTap: onOther),
              if (speaker != null && onRename != null)
                _SpeakerChip(label: '✎ Renommer', selected: renaming, dashed: true, onTap: onRename!),
              _SpeakerChip(
                label: '',
                selected: false,
                trailing: Icons.expand_less_rounded,
                semanticsLabel: 'Replier la liste',
                onTap: onToggleSpeakers,
              ),
            ],
          ),
        if (newSpeaker != null) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: newSpeaker,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => onConfirmOther(),
                  style: const TextStyle(fontSize: 14),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: renaming ? 'Nouveau nom (toute l\'histoire)' : 'Nom du personnage',
                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    fillColor: InkColors.surface,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              ListenableBuilder(
                listenable: newSpeaker!,
                builder: (context, _) => TextButton(
                  onPressed: newSpeaker!.text.trim().isEmpty ? null : onConfirmOther,
                  style: TextButton.styleFrom(minimumSize: const Size(44, 32), padding: const EdgeInsets.symmetric(horizontal: 10)),
                  child: const Text('OK'),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 6),
        MarkupField(
          controller: controller,
          compact: true,
          autofocus: newSpeaker == null,
          minLines: 2,
          maxLines: 5,
          style: InkText.dialogue.copyWith(fontSize: fontSize),
          decoration: const InputDecoration(
            isDense: true,
            contentPadding: EdgeInsets.all(8),
            fillColor: InkColors.surface,
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 4),
          Text(error!, style: const TextStyle(fontSize: 12, color: InkColors.error)),
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

/// Puce d'un personnage dans la fenêtre (choix de qui parle).
class _SpeakerChip extends StatelessWidget {
  const _SpeakerChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.dot,
    this.dashed = false,
    this.trailing,
    this.semanticsLabel,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? dot;
  final bool dashed;

  /// Flèche pour déplier ou replier la liste.
  final IconData? trailing;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      label: semanticsLabel,
      // Le libellé dit l'action (« Changer de personnage ») : on ne le mêle
      // pas au nom affiché.
      excludeSemantics: semanticsLabel != null,
      child: Material(
        color: selected ? InkColors.raised : InkColors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: selected ? InkColors.accent : (dashed ? InkColors.borderStrong : InkColors.borderSoft)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: Container(
            height: 30,
            // Un nom très long est coupé (« Petit garçon (audio uniq… »).
            constraints: const BoxConstraints(maxWidth: 170),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (dot != null) ...[
                  Container(width: 6, height: 6, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                ],
                if (label.isNotEmpty)
                  Flexible(
                    child: Tooltip(
                      message: label,
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, color: selected ? InkColors.text : InkColors.textMuted),
                      ),
                    ),
                  ),
                if (trailing != null) ...[
                  if (label.isNotEmpty) const SizedBox(width: 2),
                  Icon(trailing, size: 16, color: InkColors.textMuted),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LineText extends StatelessWidget {
  const _LineText({required this.line, required this.fontSize});

  final PlayLine line;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return MarkupText(
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
              side: BorderSide(color: picked == i ? InkColors.accent : InkColors.borderSoft),
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
            color: InkColors.overlayBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: InkColors.borderSoft),
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
