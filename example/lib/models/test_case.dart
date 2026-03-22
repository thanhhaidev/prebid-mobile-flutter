import 'demo_ad_format.dart';

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
  final int width;
  final int height;

  const TestCase({
    required this.title,
    required this.configId,
    this.storedResponse,
    required this.format,
    this.width = 320,
    this.height = 50,
  });
}
