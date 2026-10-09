// A minimal app: initialize Prebid, then show a banner, an interstitial and a
// native ad rendered by Prebid. The config IDs are Prebid's public test
// setup, which always returns test bids.
//
// The full example app, with every ad format and integration, is in the
// repository: https://github.com/thanhhaidev/prebid-mobile-flutter/tree/main/example
import 'package:flutter/material.dart';
import 'package:prebid_mobile_sdk/prebid_mobile_sdk.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Await initialization before loading any ad.
  await PrebidMobile.initializeSdk(
    prebidServerUrl: 'https://prebid-server-test-j.prebid.org/openrtb2/auction',
    accountId: '0689a263-318d-448b-a3d4-b02e8a709d9d',
    completion: (status, error) => debugPrint('Prebid: $status $error'),
  );
  // Consent signals, if you don't use a consent management platform.
  await PrebidTargeting.setSubjectToGDPR(false);

  runApp(const MaterialApp(home: ExamplePage()));
}

class ExamplePage extends StatefulWidget {
  const ExamplePage({super.key});

  @override
  State<ExamplePage> createState() => _ExamplePageState();
}

class _ExamplePageState extends State<ExamplePage> {
  late final PrebidInterstitialAd _interstitial = PrebidInterstitialAd(
    configId: 'prebid-demo-display-interstitial-320-480',
    listener: PrebidInterstitialAdListener(
      onAdLoaded: () => _interstitial.show(),
      onAdFailed: (error) => debugPrint('Interstitial failed: $error'),
    ),
  );

  var _nativeLoaded = false;
  late final PrebidNativeAd _native = PrebidNativeAd(
    configId: 'prebid-demo-banner-native-styles',
    listener: PrebidNativeAdListener(
      onAdLoaded: (response) => setState(() => _nativeLoaded = true),
      onAdImpression: () => debugPrint('Native impression'),
    ),
  )..loadAd();

  @override
  void dispose() {
    _interstitial.destroy();
    _native.destroy();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('prebid_mobile_sdk')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: PrebidBannerAd(
              configId: 'prebid-demo-banner-320-50',
              width: 320,
              height: 50,
              listener: PrebidBannerAdListener(
                onAdLoaded: () => debugPrint('Banner loaded'),
                onAdFailed: (error) => debugPrint('Banner failed: $error'),
              ),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _interstitial.loadAd,
            child: const Text('Show an interstitial'),
          ),
          const SizedBox(height: 24),
          if (_nativeLoaded) PrebidNativeAdView(ad: _native),
        ],
      ),
    );
  }
}
