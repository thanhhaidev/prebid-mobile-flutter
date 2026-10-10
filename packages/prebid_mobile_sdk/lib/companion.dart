/// Building blocks shared by the companion packages
/// (`prebid_mobile_sdk_gam`, `prebid_mobile_sdk_admob`,
/// `prebid_mobile_sdk_max`).
///
/// Not meant for apps, which use
/// `package:prebid_mobile_sdk/prebid_mobile_sdk.dart` and the companion
/// packages' own libraries. It follows semantic versioning like the rest of
/// the package: a breaking change to it comes only with a new major version,
/// so a companion package depending on `prebid_mobile_sdk: ^1.0.0` keeps
/// working with every 1.x release.
library;

export 'src/companion/ad_view_channel.dart';
export 'src/companion/ad_view_state.dart';
export 'src/companion/companion_ad_channel.dart';
export 'src/companion/companion_fullscreen_ad.dart';
