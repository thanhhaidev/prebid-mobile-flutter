/// Types of native ad assets.
enum NativeAssetType {
  /// Title text asset.
  title,

  /// Image asset (icon or main image).
  image,

  /// Data asset (sponsored, description, CTA, etc.).
  data,
}

/// Types of native image assets.
enum NativeImageType {
  /// Small icon image (e.g., app icon).
  icon(1),

  /// Main image of the ad.
  main(3),

  /// Custom image type.
  custom(500);

  const NativeImageType(this.value);
  final int value;
}

/// Types of native data assets (OpenRTB spec).
enum NativeDataType {
  /// Sponsored By message.
  sponsored(1),

  /// Description text.
  desc(2),

  /// Rating of the product.
  rating(3),

  /// Number of likes.
  likes(4),

  /// Number of downloads.
  downloads(5),

  /// Price of the product.
  price(6),

  /// Sale price.
  salePrice(7),

  /// Phone number.
  phone(8),

  /// Address.
  address(9),

  /// Additional description.
  desc2(10),

  /// Display URL.
  displayUrl(11),

  /// Call to action text.
  ctaText(12),

  /// Custom data type.
  custom(500);

  const NativeDataType(this.value);
  final int value;
}

/// Types of native events to track.
enum NativeEventType {
  /// Impression event.
  impression(1),

  /// 50% viewable impression.
  viewable50(2),

  /// 100% viewable impression.
  viewable100(3),

  /// 50% viewable video impression.
  viewableVideo50(4),

  /// Custom event.
  custom(500);

  const NativeEventType(this.value);
  final int value;
}

/// Tracking methods for native events.
enum NativeEventTrackingMethod {
  /// Image pixel tracking.
  image(1),

  /// JavaScript tracking.
  js(2),

  /// Custom tracking method.
  custom(500);

  const NativeEventTrackingMethod(this.value);
  final int value;
}

/// Context type for native ads.
enum NativeContextType {
  /// Content-centric context (news, articles).
  contentCentric(1),

  /// Social-centric context (social networks).
  socialCentric(2),

  /// Product context (product pages).
  product(3),

  /// Custom context.
  custom(500);

  const NativeContextType(this.value);
  final int value;
}

/// Placement type for native ads.
enum NativePlacementType {
  /// In the feed of content.
  inFeed(1),

  /// In the atomic unit of the content.
  atomicUnit(2),

  /// Outside the core content.
  outsideContent(3),

  /// Recommendation widget.
  recommendation(4),

  /// Custom placement.
  custom(500);

  const NativePlacementType(this.value);
  final int value;
}
