import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart' as gma;
import 'package:webview_flutter/webview_flutter.dart';

import '../../demo_screen.dart';

/// T — "SDK Testing: Prebid Universal Creative" (`PrebidUniversalCreative
/// Testing(Gam)Fragment`).
///
/// - WebView: an IP address field and **Open URL**, which loads
///   `http://<ip>` in a JavaScript-enabled WebView (a local PUC test page).
/// - GAM: the GAM test ad unit (300x250) loaded on open, without Prebid; a
///   load error shows `Error loading GAM ad: <msg>`.
class PucTestingScreen extends DemoScreen {
  const PucTestingScreen({super.key, required super.item});

  @override
  State<PucTestingScreen> createState() => _PucTestingScreenState();
}

class _PucTestingScreenState extends DemoScreenState<PucTestingScreen> {
  static const _prompt = "Please enter IP address (f.e. '192.168.0.10:9876')";

  final _ip = TextEditingController();
  WebViewController? _web;
  gma.AdManagerBannerAd? _gam;
  bool _gamLoaded = false;

  bool get _isGam => item.adUnitId != null;

  @override
  Future<void> startAd() async {
    if (!_isGam) return;
    final ad = _gam = gma.AdManagerBannerAd(
      adUnitId: item.adUnitId!,
      sizes: const [gma.AdSize.mediumRectangle],
      request: const gma.AdManagerAdRequest(),
      listener: gma.AdManagerBannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _gamLoaded = true);
        },
        onAdFailedToLoad: (ad, e) {
          ad.dispose();
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error loading GAM ad: ${e.message}')),
          );
        },
      ),
    );
    await ad.load();
  }

  void _open() {
    final ip = _ip.text.trim();
    if (ip.isEmpty) return;
    setState(() {
      _web = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..loadRequest(Uri.parse('http://$ip'));
    });
  }

  @override
  void destroyAd() {
    _gam?.dispose();
    _ip.dispose();
  }

  @override
  Widget buildDemo(BuildContext context) {
    final gam = _gam;
    final web = _web;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(_prompt),
          const SizedBox(height: 12),
          if (_isGam) ...[
            if (gam != null && _gamLoaded)
              Center(
                child: SizedBox(
                  width: 300,
                  height: 250,
                  child: gma.AdWidget(ad: gam),
                ),
              ),
          ] else ...[
            TextField(
              controller: _ip,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(hintText: '192.168.0.10:9876'),
            ),
            const SizedBox(height: 12),
            DemoButton('Open URL', onPressed: _open),
            const SizedBox(height: 12),
            if (web != null) Expanded(child: WebViewWidget(controller: web)),
          ],
        ],
      ),
    );
  }
}
