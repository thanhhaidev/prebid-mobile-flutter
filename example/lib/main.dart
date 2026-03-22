import 'package:flutter/material.dart';
import 'package:prebid_mobile_sdk/prebid_mobile_sdk.dart';

import 'pages/examples_page.dart';
import 'utils/app_settings.dart';
import 'utils/logger.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppSettings.init();
  runApp(const PrebidDemoApp());
}

class PrebidDemoApp extends StatefulWidget {
  const PrebidDemoApp({super.key});

  /// Public notifier for dark mode toggling from settings page.
  static final ValueNotifier<bool> darkModeNotifier = ValueNotifier(
    AppSettings.darkMode,
  );

  @override
  State<PrebidDemoApp> createState() => _PrebidDemoAppState();
}

class _PrebidDemoAppState extends State<PrebidDemoApp> {
  String _sdkStatus = 'Initializing...';
  bool _sdkReady = false;
  final _log = PrebidDemoLogger.instance;

  static const _pluginVersion = '0.0.1';

  @override
  void initState() {
    super.initState();
    PrebidDemoApp.darkModeNotifier.addListener(_onDarkModeChanged);
    _initSdk();
  }

  @override
  void dispose() {
    PrebidDemoApp.darkModeNotifier.removeListener(_onDarkModeChanged);
    super.dispose();
  }

  void _onDarkModeChanged() => setState(() {});

  Future<void> _initSdk() async {
    _log.log('SDK', 'Configuring Prebid Mobile...');
    await PrebidMobile.setPbsDebug(AppSettings.pbsDebug);
    await PrebidMobile.setLogLevel(PrebidLogLevel.debug);
    await PrebidMobile.setShareGeoLocation(AppSettings.shareGeo);

    final serverUrl = AppSettings.serverUrl;
    final accountId = AppSettings.accountId;
    _log.log('SDK', 'Initializing SDK: server=$serverUrl account=$accountId');
    await PrebidMobile.initializeSdk(
      prebidServerUrl: serverUrl,
      accountId: accountId,
      completion: (status, error) {
        setState(() {
          _sdkReady =
              status == InitializationStatus.succeeded ||
              status == InitializationStatus.serverStatusWarning;
          _sdkStatus = switch (status) {
            InitializationStatus.succeeded => '✅ SDK Ready',
            InitializationStatus.serverStatusWarning => '⚠️ Ready (warning)',
            InitializationStatus.failed => '❌ Failed: ${error ?? "unknown"}',
          };
        });
        _log.log(
          'SDK',
          'Init result: $_sdkStatus',
          level: _sdkReady ? LogLevel.info : LogLevel.error,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final darkMode = PrebidDemoApp.darkModeNotifier.value;
    final brightness = darkMode ? Brightness.dark : Brightness.light;

    return MaterialApp(
      title: 'Prebid Flutter Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0068B5),
          brightness: brightness,
        ),
        useMaterial3: true,
        brightness: brightness,
        appBarTheme: AppBarTheme(
          backgroundColor: darkMode
              ? const Color(0xFF1A1A2E)
              : const Color(0xFF0068B5),
          foregroundColor: Colors.white,
          centerTitle: true,
        ),
      ),
      home: Scaffold(
        body: Column(
          children: [
            // SDK status bar
            SafeArea(
              bottom: false,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 6,
                  horizontal: 16,
                ),
                color: _sdkReady
                    ? (darkMode
                          ? const Color(0xFF1B3A1B)
                          : const Color(0xFFE8F5E9))
                    : (darkMode
                          ? const Color(0xFF3A2E1B)
                          : const Color(0xFFFFF3E0)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (!_sdkReady && _sdkStatus == 'Initializing...')
                      const Padding(
                        padding: EdgeInsets.only(right: 8),
                        child: SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(strokeWidth: 1.5),
                        ),
                      ),
                    Flexible(
                      child: Text(
                        _sdkStatus,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'v$_pluginVersion',
                      style: TextStyle(
                        fontSize: 10,
                        color: darkMode
                            ? Colors.grey.shade400
                            : Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Expanded(child: ExamplesPage()),
          ],
        ),
      ),
    );
  }
}
