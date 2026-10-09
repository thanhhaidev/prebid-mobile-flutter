import 'package:prebid_mobile_sdk/prebid_mobile_sdk.dart';

/// One-line summary of a Prebid fetch-demand result: winning bid price and
/// bidder, format, expiry and the filter-uncached-bids flag.
String bidSummary(PrebidMultiformatBidResponse r) {
  final kw = r.targetingKeywords ?? const {};
  return [
    if (kw['hb_pb'] != null) 'hb_pb=${kw['hb_pb']}',
    if (kw['hb_bidder'] != null) kw['hb_bidder']!,
    if (r.winningFormat != null) r.winningFormat!,
    if (r.exp != null) 'exp=${r.exp!.round()}s',
    if (r.topBidFiltered) 'topBidFiltered',
  ].join(' · ');
}
