import 'package:flutter/foundation.dart';

/// Mode admin, réservé à la traductrice.
///
/// Pour l'instant, un appui long sur « Bibliothèque » l'active ou le
/// désactive, sans connexion. À l'étape 6, il sera lié à la session Supabase
/// de l'uid admin.
final adminMode = ValueNotifier<bool>(false);
