import 'package:mockito/annotations.dart';
import 'package:prebid_mobile_flutter/src/generated/prebid_api.g.dart';

@GenerateMocks([
  PrebidMobileHostApi,
  TargetingHostApi,
  InterstitialAdHostApi,
  RewardedAdHostApi,
  NativeAdHostApi,
  MultiformatAdHostApi,
])
void main() {}
