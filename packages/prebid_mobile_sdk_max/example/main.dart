// A minimal app: Prebid demand competes in AppLovin MAX mediation for a banner,
// an interstitial and a native ad.
//
// Before running: initialize the AppLovin SDK with your SDK key (for example
// with `AppLovinMAX.initialize` from applovin_max), declare the key in
// AndroidManifest.xml and Info.plist, and add Prebid as a custom network on
// your MAX ad units. Replace the ad unit IDs below with yours.
//
// The full example app is in the repository:
// https://github.com/thanhhaidev/prebid-mobile-flutter/tree/main/example
import 'package:flutter/material.dart';
import 'package:prebid_mobile_sdk/prebid_mobile_sdk.dart';
import 'package:prebid_mobile_sdk_max/prebid_mobile_sdk_max.dart';

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
  late final PrebidMaxInterstitialAd _interstitial = PrebidMaxInterstitialAd(
    configId: 'prebid-demo-display-interstitial-320-480',
    maxAdUnitId: 'YOUR_MAX_INTERSTITIAL_AD_UNIT_ID',
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
      appBar: AppBar(title: const Text('prebid_mobile_sdk_max')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: PrebidMaxBannerAd(
              configId: 'prebid-demo-banner-320-50',
              maxAdUnitId: 'YOUR_MAX_BANNER_AD_UNIT_ID',
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
          PrebidMaxNativeAd(
            configId: 'prebid-demo-banner-native-styles',
            maxAdUnitId: 'YOUR_MAX_NATIVE_AD_UNIT_ID',
            listener: PrebidMaxNativeAdListener(
              onAdLoaded: () => debugPrint('Native loaded'),
              onAdImpression: () => debugPrint('Native impression'),
            ),
          ),
        ],
      ),
    );
  }
}
