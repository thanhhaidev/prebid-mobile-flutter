import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'app.dart';
import 'platform/sdk_initializer.dart';
import 'utils/app_settings.dart';

/// Entry point. Structure of the app (see README.md):
///
/// - `app.dart` — MaterialApp + bottom-tab shell,
/// - `theme/` — docs-website palette and fonts,
/// - `data/` — the 187 demo items of the original PrebidInternalTestApp,
/// - `demo/` — demo-screen framework, router and screens,
/// - `pages/` — Examples, Utilities and their sub-pages,
/// - `platform/` — SDK start-up, IAB consent store, pending plugin APIs.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _registerFontLicenses();
  await AppSettings.init();
  // Start-up like the original Application.onCreate; the UI does not wait.
  unawaited(SdkInitializer.run());
  runApp(const PrebidDemoApp());
}

void _registerFontLicenses() {
  LicenseRegistry.addLicense(() async* {
    for (final (family, file) in const [
      ('Rethink Sans', 'assets/fonts/OFL-RethinkSans.txt'),
      ('JetBrains Mono', 'assets/fonts/OFL-JetBrainsMono.txt'),
    ]) {
      yield LicenseEntryWithLineBreaks([
        family,
      ], await rootBundle.loadString(file));
    }
  });
}
