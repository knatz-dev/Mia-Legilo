import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'settings_model.dart';

/// The appearance currently in effect, so a settings save recolours the app
/// without a restart.
final appearanceProvider = StateProvider<AppearanceSettings>(
  (ref) => const AppearanceSettings(),
);
