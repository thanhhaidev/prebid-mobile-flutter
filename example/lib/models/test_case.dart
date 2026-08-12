import 'demo_ad_format.dart';
import 'demo_integration.dart';

/// A single test case in the demo app.
///
/// Maps to Prebid iOS demo's `IntegrationCase` struct.
class TestCase {
  final String title;
  final String configId;

  /// Stored auction response ID. If null, the SDK uses the configId directly
  /// against the Prebid Server without a predetermined response.
  final String? storedResponse;
  final DemoAdFormat format;

  /// Integration approach — controls the integration-type filter chip and which
  /// detail page the case opens. Defaults to Prebid Rendering / in-app bidding.
  final DemoIntegration integration;

  /// Ad-server ad unit id for mediated/served integrations: a GAM ad unit path
  /// (`/21808260008/...`), an AdMob unit (`ca-app-pub-.../...`), or a MAX ad
  /// unit id. `null` for pure In-App rendering (no primary ad server).
  final String? adUnitId;

  final int width;
  final int height;

  const TestCase({
    required this.title,
    required this.configId,
    this.storedResponse,
    required this.format,
    this.integration = DemoIntegration.inApp,
    this.adUnitId,
    this.width = 320,
    this.height = 50,
  });
}
