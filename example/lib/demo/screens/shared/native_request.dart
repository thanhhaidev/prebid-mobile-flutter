import 'package:prebid_mobile_sdk/prebid_mobile_sdk.dart';

/// The original's standard native request (`configureNativeAdUnit`, spec
/// §1.2): title 90 · icon 20x20 (min 20x20) · main image 200x200 (min
/// 200x200) · sponsored 90 · description · call to action, all required.
const kStandardNativeAssets = <NativeAsset>[
  NativeAsset.title(required: true),
  NativeAsset.image(
    imageType: NativeImageType.icon,
    width: 20,
    height: 20,
    widthMin: 20,
    heightMin: 20,
    required: true,
  ),
  NativeAsset.image(
    width: 200,
    height: 200,
    widthMin: 200,
    heightMin: 200,
    required: true,
  ),
  NativeAsset.data(
    dataType: NativeDataType.sponsored,
    length: 90,
    required: true,
  ),
  NativeAsset.data(dataType: NativeDataType.desc, required: true),
  NativeAsset.data(dataType: NativeDataType.ctaText, required: true),
];

/// Impression tracker with image + JS methods (most screens).
const kStandardNativeTrackers = <NativeEventTracker>[
  NativeEventTracker(
    eventType: NativeEventType.impression,
    methods: [NativeEventTrackingMethod.image, NativeEventTrackingMethod.js],
  ),
];

/// Image-only impression tracker (GAM Original native banner / multiformat).
const kImageOnlyNativeTrackers = <NativeEventTracker>[
  NativeEventTracker(
    eventType: NativeEventType.impression,
    methods: [NativeEventTrackingMethod.image],
  ),
];

/// Context SOCIAL_CENTRIC / GENERAL_SOCIAL, placement CONTENT_FEED.
const kNativeContext = NativeContextType.socialCentric;
const kNativeContextSubType = NativeContextSubType.social;
const kNativePlacement = NativePlacementType.inFeed;

/// The video parameters of the original multiformat requests (mp4 only).
const kMp4Video = VideoParameters(mimes: ['video/mp4']);
