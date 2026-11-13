import 'package:material_ui/material_ui.dart';

import '../overlay/overlay_launcher.dart';
import 'library_repository.dart';
import 'overlay_settings.dart';

/// Rend la bibliothèque et les réglages accessibles à tous les écrans.
class Services extends InheritedWidget {
  Services({super.key, required this.library, required this.settings, OverlayLauncher? launcher, required super.child})
      : launcher = launcher ?? OverlayLauncher(library: library, settings: settings);

  final LibraryRepository library;
  final OverlaySettings settings;

  /// Ouvre la fenêtre flottante au-dessus du jeu.
  final OverlayLauncher launcher;

  static Services of(BuildContext context) {
    final services = context.dependOnInheritedWidgetOfExactType<Services>();
    assert(services != null, 'Services absent au-dessus de ce widget.');
    return services!;
  }

  @override
  bool updateShouldNotify(Services oldWidget) =>
      library != oldWidget.library || settings != oldWidget.settings;
}

extension ServicesContext on BuildContext {
  LibraryRepository get library => Services.of(this).library;
  OverlaySettings get overlaySettings => Services.of(this).settings;
  OverlayLauncher get overlayLauncher => Services.of(this).launcher;
}

/// Charge une donnée de la bibliothèque et la recharge à chaque modification.
///
/// [args] : ce dont dépend la requête (un identifiant…). La requête est
/// relancée quand il change, pas à chaque reconstruction de l'écran.
class LibraryQuery<T> extends StatefulWidget {
  const LibraryQuery({super.key, this.args, required this.load, required this.builder});

  final Object? args;
  final Future<T> Function(LibraryRepository library) load;
  final Widget Function(BuildContext context, T data) builder;

  @override
  State<LibraryQuery<T>> createState() => _LibraryQueryState<T>();
}

class _LibraryQueryState<T> extends State<LibraryQuery<T>> {
  LibraryRepository? _library;
  Future<T>? _future;
  T? _last;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final library = context.library;
    if (library != _library) {
      _library?.removeListener(_reload);
      _library = library..addListener(_reload);
      _future = widget.load(library);
    }
  }

  @override
  void didUpdateWidget(LibraryQuery<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.args != widget.args) _future = widget.load(_library!);
  }

  // Accolades obligatoires : une flèche renverrait le Future, ce que
  // setState refuse en mode debug.
  void _reload() => setState(() {
        _future = widget.load(_library!);
      });

  @override
  void dispose() {
    _library?.removeListener(_reload);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Text('Erreur de lecture : ${snapshot.error}'),
          );
        }
        // Pendant un rechargement, on garde l'affichage précédent : pas de clignotement.
        if (snapshot.hasData) _last = snapshot.data;
        final data = snapshot.hasData ? snapshot.data : _last;
        if (data == null) return const SizedBox.shrink();
        return widget.builder(context, data);
      },
    );
  }
}
