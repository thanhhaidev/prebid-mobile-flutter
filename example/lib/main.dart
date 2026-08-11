import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart' show MobileAds;
import 'package:prebid_mobile_sdk/prebid_mobile_sdk.dart';

import 'pages/examples_page.dart';
import 'pages/utilities_page.dart';
import 'utils/app_settings.dart';
import 'utils/logger.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppSettings.init();
  // Initialize the Google Mobile Ads SDK once at startup so the "GAM
  // Coordination" demo can render Ad Manager ad views. Prebid runs the auction
  // and hands its targeting keywords to this SDK for rendering.
  await MobileAds.instance.initialize();
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
  @override
  void initState() {
    super.initState();
    PrebidDemoApp.darkModeNotifier.addListener(_onDarkModeChanged);
  }

  @override
  void dispose() {
    PrebidDemoApp.darkModeNotifier.removeListener(_onDarkModeChanged);
    super.dispose();
  }

  void _onDarkModeChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final darkMode = PrebidDemoApp.darkModeNotifier.value;
    final brightness = darkMode ? Brightness.dark : Brightness.light;

    return MaterialApp(
      title: 'Prebid Rendering Flutter Demo',
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
      home: const RootShell(),
    );
  }
}

/// Root shell with a persistent bottom navigation bar (Examples / Utilities).
///
/// Each tab hosts its own [Navigator] so pushing a detail page keeps the
/// bottom bar visible, matching the Prebid reference app.
class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _index = 0;
  final _navKeys = [GlobalKey<NavigatorState>(), GlobalKey<NavigatorState>()];

  String _sdkStatus = 'Initializing...';
  bool _sdkReady = false;
  final _log = PrebidDemoLogger.instance;

  @override
  void initState() {
    super.initState();
    _initSdk();
  }

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
        if (!mounted) return;
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

  Widget _tabNavigator(int index, Widget root) {
    return Navigator(
      key: _navKeys[index],
      onGenerateRoute: (settings) =>
          MaterialPageRoute(builder: (_) => root, settings: settings),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        final nav = _navKeys[_index].currentState;
        if (nav != null && nav.canPop()) {
          nav.pop();
        } else {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        body: Column(
          children: [
            // SDK status strip — only while initializing or on failure.
            if (!_sdkReady)
              SafeArea(
                bottom: false,
                child: Container(
                  width: double.infinity,
                  color: _sdkStatus.startsWith('❌')
                      ? const Color(0xFFFFEBEE)
                      : const Color(0xFFFFF3E0),
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text(
                    _sdkStatus,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
            Expanded(
              child: IndexedStack(
                index: _index,
                children: [
                  _tabNavigator(0, const ExamplesPage()),
                  _tabNavigator(1, const UtilitiesPage()),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.list), label: 'Examples'),
            NavigationDestination(
              icon: Icon(Icons.info_outline),
              label: 'Utilities',
            ),
          ],
        ),
      ),
    );
  }
}
