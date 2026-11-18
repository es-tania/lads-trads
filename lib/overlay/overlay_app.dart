import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../theme/ink.dart';
import '../widgets/markup_field.dart';
import '../widgets/size_reporter.dart';
import 'keyboard_avoider.dart';
import 'overlay_host.dart';
import 'overlay_messages.dart';
import 'playback.dart';
import 'view/edit_view.dart';
import 'view/overlay_window.dart';
import 'view/step_view.dart';

/// Marge entre la fenêtre et les bords de l'écran.
const _margin = 8.0;

/// Taille de la bulle réduite.
const _bubbleWidth = 64;
const _bubbleHeight = 56;

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
  late final KeyboardAvoider _keyboard;
  int get _windowWidth => (_screenWidth - 2 * _margin).round();

  @override
  void initState() {
    super.initState();
    _sub = host.messages.listen(_onMessage);
    _keyboard = KeyboardAvoider(host);
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
      await host.setDragHandle(overlayGripArea);
    } on Object {
      // Service pas encore prêt : ce sera fait au prochain appel.
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    unawaited(_keyboard.stop());
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
    // Le temps de la modification, la fenêtre reçoit le clavier et reste
    // au-dessus de lui.
    await host.setKeyboard(true);
    _keyboard.start();
  }

  Future<void> _stopEditing() async {
    setState(() {
      _editing = null;
      _savingEdit = false;
      _closeNewSpeaker();
    });
    await _keyboard.stop();
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
    if (_bubble) return OverlayBubble(playback: _playback, onTap: _expand);

    final playback = _playback;
    final editing = _editing;
    final reading = editing == null;
    return Align(
      alignment: Alignment.topLeft,
      child: OverflowBox(
        alignment: Alignment.topLeft,
        minHeight: 0,
        maxHeight: double.infinity,
        child: SizeReporter(
          onHeight: _onContentHeight,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: _maxHeight),
            child: OverlayWindow(
              opacity: _opacity,
              onMinimize: _minimize,
              onPrevious: reading && playback != null && playback.canGoBack ? () => setState(playback.previous) : null,
              onNext: reading && playback != null && playback.canGoForward ? () => setState(playback.next) : null,
              child: playback == null || playback.isEmpty
                  ? const OverlayWaiting()
                  : !reading
                      ? OverlayEditView(
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
                      : OverlayStepView(
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
