// Passe toutes les histoires d'un dossier au parseur et résume le résultat.
// Usage : dart run tool/check_all.dart <dossier racine> [--details]
//
// Chaque sous-dossier qui contient FR.docx est une histoire.
import 'dart:io';

import 'package:lads_trad/docx/story_parser.dart';

void main(List<String> args) {
  final root = Directory(args.isEmpty ? '.' : args.first);
  final details = args.contains('--details');
  var stories = 0;
  var withWarnings = 0;

  final dirs = <Directory>[];
  void walk(Directory d) {
    dirs.add(d);
    final List<FileSystemEntity> children;
    try {
      children = d.listSync();
    } on FileSystemException {
      return;
    }
    for (final child in children.whereType<Directory>()) {
      final base = child.path.split(RegExp(r'[\\/]')).last;
      if (base.startsWith('.') || base == 'node_modules') continue;
      walk(child);
    }
  }

  walk(root);
  dirs.sort((a, b) => a.path.compareTo(b.path));
  for (final dir in dirs) {
    final fr = File('${dir.path}${Platform.pathSeparator}FR.docx');
    if (!fr.existsSync()) continue;
    stories++;
    final name = dir.path.substring(root.path.length).replaceAll(r'\', '/');
    try {
      final story = parseStoryDocx(fr.readAsBytesSync());
      final lines = story.parts.fold<int>(0, (n, p) => n + p.allLines.length);
      if (story.warnings.isNotEmpty) withWarnings++;
      stdout.writeln(
        '${story.warnings.isEmpty ? 'OK ' : '!! '} $name : ${story.parts.length} parties, $lines répliques, '
        '${story.warnings.length} à vérifier',
      );
      if (details) {
        for (final w in story.warnings) {
          stdout.writeln('      $w');
        }
      }
    } on Object catch (e) {
      withWarnings++;
      stdout.writeln('ERR $name : $e');
    }
  }
  stdout.writeln('\n$stories histoires, $withWarnings avec quelque chose à vérifier.');
}
