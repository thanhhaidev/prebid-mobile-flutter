import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart' show MobileAds;
import 'package:prebid_mobile_sdk/prebid_mobile_sdk.dart';

import '../demo/demo_screen.dart' show DemoScaffold;
import '../platform/pending_api.dart';
import '../theme/app_theme.dart';

/// Utilities → "Versions" — the original `VersionInfoFragment`: a 3-row
/// table of the Prebid SDK, GAM (Google Mobile Ads, initialized first) and
/// OMSDK versions.
class VersionsPage extends StatefulWidget {
  const VersionsPage({super.key});

  @override
  State<VersionsPage> createState() => _VersionsPageState();
}

class _VersionsPageState extends State<VersionsPage> {
  String? _prebid;
  String? _gam;
  String? _omsdk;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prebid = await _safe(PrebidMobile.getSdkVersion);
    if (mounted) setState(() => _prebid = prebid);
    final gam = await _safe(() async {
      await MobileAds.instance.initialize();
      return MobileAds.instance.getVersionString();
    });
    if (mounted) setState(() => _gam = gam);
    final omsdk = await _safe(PendingApi.getOmsdkVersion);
    if (mounted) setState(() => _omsdk = omsdk);
  }

  static Future<String> _safe(Future<String?> Function() f) async {
    try {
      return await f() ?? 'unavailable';
    } catch (e) {
      return 'error: $e';
    }
  }

  @override
  Widget build(BuildContext context) {
    return DemoScaffold(
      title: 'Versions',
      progressOverlay: false,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _row(context, 'Prebid Rendering:', _prebid),
          _row(context, 'GAM:', _gam),
          _row(context, 'OMSDK:', _omsdk),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, String label, String? value) {
    final c = DemoColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.border)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontVariations: [FontVariation.weight(600)],
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value ?? '…',
              style: AppFonts.monoStyle(color: c.codeFg),
            ),
          ),
        ],
      ),
    );
  }
}
