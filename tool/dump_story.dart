// Affiche la structure d'une histoire importée.
// Usage : dart run tool/dump_story.dart <dossier contenant FR.docx et EN.docx>
import 'dart:io';

import 'package:lads_trad/docx/story_model.dart';
import 'package:lads_trad/docx/story_parser.dart';

void main(List<String> args) {
  final dir = args.isEmpty ? 'test/fixtures/into_the_canvas' : args.first;
  final story = parseStoryDocx(
    fr: File('$dir/FR.docx').readAsBytesSync(),
    en: File('$dir/EN.docx').readAsBytesSync(),
  );
  stdout.writeln('Titre : ${story.title} (${story.subtitle}) · ${story.paragraphCount} paragraphes');
  for (final part in story.parts) {
    stdout.writeln('\n== ${part.title} · ${part.allLines.length} répliques');
    for (final item in part.items) {
      switch (item) {
        case StoryLine():
          stdout.writeln('  ${item.paragraph.toString().padLeft(3)} ${item.kind.name.padRight(9)} ${item.speaker ?? ''} › ${item.text.fr}');
        case Choice():
          stdout.writeln('  ${item.paragraph.toString().padLeft(3)} CHOIX ${item.prompt}');
          for (final o in item.options) {
            stdout.writeln('      option « ${o.label} »');
            for (final l in o.lines) {
              stdout.writeln('        ${l.paragraph} ${l.speaker} › ${l.text}');
            }
          }
      }
    }
  }
  stdout.writeln('\nLignes EN sans traduction (ignorées) : ${story.untranslated.isEmpty ? 'aucune' : ''}');
  for (final l in story.untranslated) {
    stdout.writeln('  $l');
  }
  stdout.writeln('\nÀ vérifier : ${story.warnings.isEmpty ? 'rien' : ''}');
  for (final w in story.warnings) {
    stdout.writeln('  $w');
  }
}
