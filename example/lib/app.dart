import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'pages/examples_page.dart';
import 'pages/utilities_page.dart';
import 'services/app_settings.dart';
import 'theme/app_theme.dart';

/// The app: docs-website light / dark themes and the [RootShell].
class PrebidDemoApp extends StatelessWidget {
  const PrebidDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppSettings.themeModeNotifier,
      builder: (context, mode, _) => MaterialApp(
        title: kAppTitle,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: mode,
        home: const RootShell(),
      ),
    );
  }
}

/// Bottom tabs of the shell, in order.
enum RootTab {
  examples('Examples', Icons.list),
  utilities('Utilities', Icons.info_outline);

  const RootTab(this.label, this.icon);

  final String label;
  final IconData icon;

  Widget buildRoot() => switch (this) {
    RootTab.examples => const ExamplesPage(),
    RootTab.utilities => const UtilitiesPage(),
  };
}

/// The original `MainActivity` shell (spec §1.0): one navigator above an
/// always-visible bottom navigation bar (Examples / Utilities, labels always
/// shown). Selecting a tab — or re-selecting the current one — replaces the
/// whole stack with that tab's root: tab stacks are not preserved, and the
/// open demo is disposed (its ad destroyed). Each page brings its own
/// centered-title app bar; sub-pages get the Up arrow from the navigator.
class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  RootTab _tab = RootTab.examples;

  static Route<void> _rootRoute(RootTab tab) => PageRouteBuilder<void>(
    settings: RouteSettings(name: tab.name),
    pageBuilder: (_, _, _) => tab.buildRoot(),
    transitionDuration: Duration.zero,
    reverseTransitionDuration: Duration.zero,
  );

  void _select(RootTab tab) {
    setState(() => _tab = tab);
    _navigatorKey.currentState?.pushAndRemoveUntil(
      _rootRoute(tab),
      (_) => false,
    );
  }

  /// System back: pop a sub-screen; from the Utilities root go to the
  /// Examples root (the graph start); from the Examples root leave the app.
  void _onBack() {
    final nav = _navigatorKey.currentState;
    if (nav != null && nav.canPop()) {
      nav.pop();
    } else if (_tab != RootTab.examples) {
      _select(RootTab.examples);
    } else {
      SystemNavigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onBack();
      },
      child: Scaffold(
        body: Navigator(
          key: _navigatorKey,
          onGenerateInitialRoutes: (_, _) => [_rootRoute(RootTab.examples)],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _tab.index,
          onDestinationSelected: (i) => _select(RootTab.values[i]),
          destinations: [
            for (final t in RootTab.values)
              NavigationDestination(icon: Icon(t.icon), label: t.label),
          ],
        ),
      ),
    );
  }
}
