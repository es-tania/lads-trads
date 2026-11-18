import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

/// Images copiées dans le stockage de l'app : couvertures des histoires et
/// images des personnages.
class ImageFiles {
  ImageFiles(this.dir);

  final Directory dir;

  /// Copie [bytes] dans [dir] et renvoie le chemin du fichier.
  ///
  /// Le nom commence par [prefix] et se termine par l'heure : une nouvelle
  /// image ne réutilise jamais celle en cache. L'extension vient de
  /// [fileName] (`.png` s'il n'en a pas).
  Future<String> save(Uint8List bytes, String fileName, {required String prefix}) async {
    await dir.create(recursive: true);
    final ext = p.extension(fileName).toLowerCase();
    final file = File(p.join(
      dir.path,
      '${prefix}_${DateTime.now().millisecondsSinceEpoch}${ext.isEmpty ? '.png' : ext}',
    ));
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  /// Efface le fichier, s'il existe encore.
  Future<void> delete(String? path) async {
    if (path == null) return;
    try {
      await File(path).delete();
    } on FileSystemException {
      // Déjà absent : rien à faire.
    }
  }
}
