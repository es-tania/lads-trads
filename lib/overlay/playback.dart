/// Déroulé d'une histoire dans la fenêtre flottante : réplique par réplique,
/// partie après partie, avec les choix et leurs branches.
///
/// Code pur (sans Flutter) : il est partagé entre l'app et la fenêtre, et
/// testé sans téléphone.
library;

/// Une réplique telle qu'envoyée à la fenêtre.
class PlayLine {
  const PlayLine({required this.kind, required this.text, this.speaker, this.id});

  /// Identifiant de la ligne en base, pour la modifier pendant la lecture.
  final int? id;

  /// « dialogue », « thought » ou « narration ».
  final String kind;
  final String text;
  final String? speaker;

  bool get isNarration => kind == 'narration';
  bool get isThought => kind == 'thought';

  Map<String, Object?> toJson() => {'k': kind, 't': text, if (speaker != null) 's': speaker, if (id != null) 'i': id};

  static PlayLine fromJson(Map<Object?, Object?> json) => PlayLine(
        kind: json['k']! as String,
        text: json['t']! as String,
        speaker: json['s'] as String?,
        id: json['i'] as int?,
      );

  PlayLine copyWith({required String text, required String? speaker, required String kind}) =>
      PlayLine(kind: kind, text: text, speaker: speaker, id: id);
}

class PlayOption {
  const PlayOption({required this.label, required this.lines});

  final String label;
  final List<PlayLine> lines;

  Map<String, Object?> toJson() => {'label': label, 'lines': [for (final l in lines) l.toJson()]};

  static PlayOption fromJson(Map<Object?, Object?> json) => PlayOption(
        label: json['label']! as String,
        lines: [for (final l in json['lines']! as List<Object?>) PlayLine.fromJson(l! as Map<Object?, Object?>)],
      );
}

/// Élément du tronc d'une partie : une réplique ou un choix.
class PlayItem {
  const PlayItem.line(PlayLine this.line) : options = null;
  const PlayItem.choice(List<PlayOption> this.options) : line = null;

  final PlayLine? line;
  final List<PlayOption>? options;

  bool get isChoice => options != null;

  Map<String, Object?> toJson() => isChoice
      ? {'choice': [for (final o in options!) o.toJson()]}
      : line!.toJson();

  static PlayItem fromJson(Map<Object?, Object?> json) => json.containsKey('choice')
      ? PlayItem.choice([for (final o in json['choice']! as List<Object?>) PlayOption.fromJson(o! as Map<Object?, Object?>)])
      : PlayItem.line(PlayLine.fromJson(json));
}

class PlayPart {
  const PlayPart({required this.title, required this.items});

  final String title;
  final List<PlayItem> items;

  Map<String, Object?> toJson() => {'title': title, 'items': [for (final i in items) i.toJson()]};

  static PlayPart fromJson(Map<Object?, Object?> json) => PlayPart(
        title: json['title']! as String,
        items: [for (final i in json['items']! as List<Object?>) PlayItem.fromJson(i! as Map<Object?, Object?>)],
      );
}

/// Une étape affichée dans la fenêtre : une réplique, ou un choix à faire.
class PlayStep {
  const PlayStep._({required this.itemIndex, this.line, this.optionIndex, this.choiceOptions});

  /// Indice de l'élément du tronc auquel appartient l'étape.
  final int itemIndex;

  /// Réplique affichée (`null` pour une étape de choix).
  final PlayLine? line;

  /// Pour une réplique de branche : l'option dont elle fait partie.
  final int? optionIndex;

  /// Pour une étape de choix : les options proposées.
  final List<PlayOption>? choiceOptions;

  bool get isChoice => choiceOptions != null;
}

/// Position de lecture dans une histoire.
///
/// Les choix déjà faits sont retenus : en revenant en arrière puis en
/// avançant, on retrouve la même branche. « Changer de branche » ramène au
/// choix et oublie la réponse.
class Playback {
  Playback(List<PlayPart> parts, {int part = 0})
      : parts = List.of(parts),
        _part = part.clamp(0, parts.isEmpty ? 0 : parts.length - 1);

  final List<PlayPart> parts;
  int _part;
  int _index = 0;

  /// Réponse choisie pour chaque choix : (partie, élément) → option.
  final _picks = <(int, int), int>{};

  int get partIndex => _part;
  PlayPart get part => parts[_part];
  bool get isEmpty => parts.isEmpty || parts.every((p) => p.items.isEmpty);

  /// Étapes de la partie en cours, selon les choix faits.
  List<PlayStep> get steps => _stepsFor(_part);

  PlayStep? get current {
    final s = steps;
    return s.isEmpty ? null : s[_index.clamp(0, s.length - 1)];
  }

  /// Réponse choisie pour le choix affiché (ou celui de la branche en cours).
  int? get pickedOption {
    final step = current;
    if (step == null) return null;
    return step.isChoice ? _picks[(_part, step.itemIndex)] : step.optionIndex;
  }

  /// Lettre de la branche en cours (« A », « B »…), `null` hors branche.
  String? get branchLetter {
    final option = current?.optionIndex;
    return option == null ? null : String.fromCharCode(65 + option);
  }

  bool get canGoBack => _index > 0 || _part > 0;

  /// On ne passe pas un choix sans avoir répondu.
  bool get canGoForward {
    final step = current;
    if (step == null) return false;
    if (step.isChoice && pickedOption == null) return false;
    return _index < steps.length - 1 || _part < parts.length - 1;
  }

  /// Vrai sur la première étape d'une partie (pour annoncer son titre).
  bool get atPartStart => _index == 0;

  void next() {
    if (!canGoForward) return;
    if (_index < steps.length - 1) {
      _index++;
    } else {
      _part++;
      _index = 0;
    }
  }

  void previous() {
    if (_index > 0) {
      _index--;
    } else if (_part > 0) {
      _part--;
      _index = steps.length - 1;
    }
  }

  /// Répond au choix affiché et passe à la première réplique de la branche.
  void pick(int option) {
    final step = current;
    if (step == null || !step.isChoice) return;
    _picks[(_part, step.itemIndex)] = option;
    next();
  }

  /// Revient au choix de la branche en cours et oublie la réponse.
  void changeBranch() {
    final step = current;
    if (step == null || step.optionIndex == null) return;
    _picks.remove((_part, step.itemIndex));
    _index = steps.indexWhere((s) => s.isChoice && s.itemIndex == step.itemIndex);
  }

  /// Remplace le texte et le personnage de la ligne [id] partout où elle
  /// apparaît, sans changer la position de lecture. [kind] : son nouveau type
  /// (« dialogue », « thought » ou « narration »).
  void updateLine(int id, {required String text, required String? speaker, required String kind}) {
    PlayLine fix(PlayLine l) => l.id == id ? l.copyWith(text: text, speaker: speaker, kind: kind) : l;
    for (final (p, part) in parts.indexed) {
      parts[p] = PlayPart(title: part.title, items: [
        for (final item in part.items)
          item.isChoice
              ? PlayItem.choice([
                  for (final o in item.options!) PlayOption(label: o.label, lines: [for (final l in o.lines) fix(l)]),
                ])
              : PlayItem.line(fix(item.line!)),
      ]);
    }
  }

  /// Remplace le nom d'un personnage dans toutes ses répliques.
  void renameSpeaker(String from, String to) {
    PlayLine fix(PlayLine l) => l.speaker == from ? l.copyWith(text: l.text, speaker: to, kind: l.kind) : l;
    for (final (p, part) in parts.indexed) {
      parts[p] = PlayPart(title: part.title, items: [
        for (final item in part.items)
          item.isChoice
              ? PlayItem.choice([
                  for (final o in item.options!) PlayOption(label: o.label, lines: [for (final l in o.lines) fix(l)]),
                ])
              : PlayItem.line(fix(item.line!)),
      ]);
    }
  }

  /// Numéro de la réplique affichée et nombre de répliques de la partie
  /// (« L.012/022 »). Un choix sans réponse compte sa première option.
  (int, int) get counter {
    final s = steps;
    var number = 0;
    for (var i = 0; i <= _index && i < s.length; i++) {
      if (!s[i].isChoice) number++;
    }
    var total = 0;
    for (final (i, item) in part.items.indexed) {
      if (!item.isChoice) {
        total++;
      } else {
        final options = item.options!;
        final picked = _picks[(_part, i)];
        total += picked != null ? options[picked].lines.length : (options.isEmpty ? 0 : options.first.lines.length);
      }
    }
    return (number == 0 ? 1 : number, total);
  }

  List<PlayStep> _stepsFor(int partIndex) {
    if (parts.isEmpty) return const [];
    final steps = <PlayStep>[];
    for (final (i, item) in parts[partIndex].items.indexed) {
      if (!item.isChoice) {
        steps.add(PlayStep._(itemIndex: i, line: item.line));
        continue;
      }
      steps.add(PlayStep._(itemIndex: i, choiceOptions: item.options));
      final picked = _picks[(partIndex, i)];
      if (picked != null) {
        for (final line in item.options![picked].lines) {
          steps.add(PlayStep._(itemIndex: i, line: line, optionIndex: picked));
        }
      }
    }
    return steps;
  }
}
