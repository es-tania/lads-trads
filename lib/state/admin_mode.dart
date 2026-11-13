import 'package:flutter/foundation.dart';

/// Mode admin, réservé à la traductrice.
///
/// Étape 1 : un appui long sur « Bibliothèque » l'active ou le désactive,
/// sans connexion. Étape 6 : il sera lié à la session Supabase de l'uid admin.
final adminMode = ValueNotifier<bool>(false);
