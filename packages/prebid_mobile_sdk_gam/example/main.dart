// A minimal app: Prebid runs the auction and Google Ad Manager renders a
// banner, an interstitial and a native ad. The IDs are Prebid's public test
// setup.
//
// Before running: add your Ad Manager app ID to AndroidManifest.xml and
// Info.plist, and initialize Google Mobile Ads (for example with
// `MobileAds.instance.initialize()` from google_mobile_ads). The full example
// app is in the repository:
// https://github.com/thanhhaidev/prebid-mobile-flutter/tree/main/example
import 'package:flutter/material.dart';
import 'package:prebid_mobile_sdk/prebid_mobile_sdk.dart';
import 'package:prebid_mobile_sdk_gam/prebid_mobile_sdk_gam.dart';

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
  late final PrebidGamInterstitialAd _interstitial = PrebidGamInterstitialAd(
    configId: 'prebid-demo-display-interstitial-320-480',
    gamAdUnitId: '/21808260008/prebid_oxb_html_interstitial',
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
      appBar: AppBar(title: const Text('prebid_mobile_sdk_gam')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: PrebidGamBannerAd(
              configId: 'prebid-demo-banner-320-50',
              gamAdUnitId: '/21808260008/prebid_oxb_320x50_banner',
              width: 320,
              height: 50,
              listener: PrebidBannerAdListener(
                onAdLoaded: () => debugPrint('GAM banner loaded'),
              ),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _interstitial.loadAd,
            child: const Text('Show an interstitial'),
          ),
          const SizedBox(height: 24),
          PrebidGamNativeAd(
            configId: 'prebid-demo-banner-native-styles',
            gamAdUnitId: '/21808260008/apollo_custom_template_native_ad_unit',
            customFormatId: '11934135',
            listener: PrebidGamNativeAdListener(
              onNativeAdLoaded: () => debugPrint('Prebid native rendered'),
              onPrimaryAdWinCustom: () => debugPrint('GAM native won'),
            ),
          ),
        ],
      ),
    );
  }
}
