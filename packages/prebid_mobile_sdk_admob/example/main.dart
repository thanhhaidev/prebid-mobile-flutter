// A minimal app: Prebid demand competes in AdMob mediation for a banner,
// an interstitial and a native ad.
//
// Before running: add your AdMob app ID to AndroidManifest.xml and Info.plist,
// initialize Google Mobile Ads (for example with
// `MobileAds.instance.initialize()` from google_mobile_ads), and add Prebid as
// a custom event on your AdMob ad units. The banner and interstitial IDs below
// are Google's test ad units.
//
// The full example app is in the repository:
// https://github.com/thanhhaidev/prebid-mobile-flutter/tree/main/example
import 'package:flutter/material.dart';
import 'package:prebid_mobile_sdk/prebid_mobile_sdk.dart';
import 'package:prebid_mobile_sdk_admob/prebid_mobile_sdk_admob.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PrebidMobile.initializeSdk(
    prebidServerUrl: 'https://prebid-server-test-j.prebid.org/openrtb2/auction',
    accountId: '0689a263-318d-448b-a3d4-b02e8a709d9d',
  );
  runApp(const MaterialApp(home: ExamplePage()));
}

class ExamplePage extends StatefulWidget {
  const ExamplePage({super.key});

  @override
  State<ExamplePage> createState() => _ExamplePageState();
}

class _ExamplePageState extends State<ExamplePage> {
  late final PrebidAdMobInterstitialAd _interstitial =
      PrebidAdMobInterstitialAd(
        configId: 'prebid-demo-display-interstitial-320-480',
        adMobAdUnitId: 'ca-app-pub-3940256099942544/1033173712',
        listener: PrebidInterstitialAdListener(
          onAdLoaded: () => _interstitial.show(),
          onAdFailed: (error) => debugPrint('Interstitial failed: $error'),
        ),
      );

  @override
  void dispose() {
    _interstitial.destroy();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('prebid_mobile_sdk_admob')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: PrebidAdMobBannerAd(
              configId: 'prebid-demo-banner-320-50',
              adMobAdUnitId: 'ca-app-pub-3940256099942544/6300978111',
              width: 320,
              height: 50,
              listener: PrebidBannerAdListener(
                onAdLoaded: () => debugPrint('Banner loaded'),
                onAdImpression: () => debugPrint('Banner impression'),
              ),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _interstitial.loadAd,
            child: const Text('Show an interstitial'),
          ),
          const SizedBox(height: 24),
          PrebidAdMobNativeAd(
            configId: 'prebid-demo-banner-native-styles',
            adMobAdUnitId: 'YOUR_ADMOB_NATIVE_AD_UNIT_ID',
            listener: PrebidAdMobNativeAdListener(
              onAdLoaded: () => debugPrint('Native loaded'),
              onAdImpression: () => debugPrint('Native impression'),
            ),
          ),
        ],
      ),
    );
  }
}
