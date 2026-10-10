# Prebid Mobile Flutter

Flutter plugins that bring the Prebid Mobile SDK (Android and iOS) to Flutter apps: a core package for Prebid itself and companion packages that put Prebid demand in front of an ad server (Google Ad Manager, AdMob, AppLovin MAX).

## Language

### Prebid and the auction

**Prebid Server (PBS)**:
The server-side auction service the SDK sends every bid request to; it holds the stored impressions and calls the bidders.
_Avoid_: the server, the exchange, bidder

**Account ID**:
The publisher's account on a Prebid Server, sent with every request.
_Avoid_: publisher ID, app ID

**Config ID**:
The ID of a stored impression on Prebid Server: the impression-level setup (bidders, their parameters) an ad unit requests demand for.
_Avoid_: ad unit ID (that is the ad server's), placement ID, stored request ID

**Stored impression**:
An impression configuration kept on Prebid Server and referenced by a config ID.
_Avoid_: stored request

**Ad unit**:
One placement's demand request: a config ID plus the formats, sizes and signals to ask for. In the Original API it is a class of its own (`PrebidBannerAdUnit` and the rest); in the other integrations the ad object carries it.
_Avoid_: placement, slot

**Auction**:
One request for one ad unit's demand, answered by Prebid Server with the bids and at most one winning bid.
_Avoid_: fetch, demand request

**Bid**:
One bidder's offer for an ad unit: a price, a creative and its metadata.
_Avoid_: ad (an ad is what is shown)

**Winning bid**:
The bid Prebid Server picks for the ad unit; the only one that can be shown.
_Avoid_: top bid, best bid

**Targeting keywords**:
The `hb_*` key-values describing the winning bid (`hb_pb`, `hb_bidder`, `hb_cache_id`, `hb_format`, …) that an ad server matches against Prebid line items.
_Avoid_: custom targeting (the ad server's name for where they go), hb params

**Winning format**:
The format of the winning bid in a multiformat auction: banner, video or native (its `hb_format` keyword).

**Prebid Cache**:
The store that holds a winning bid's creative so that an ad server or a later load can fetch it by its cache ID.

**Prebid Universal Creative**:
The creative on an ad server's Prebid line item that renders the winning bid out of Prebid Cache.
_Avoid_: PUC (spell it out)

**Result code**:
The outcome of an auction or load as one name shared by Android and iOS, e.g. `prebidDemandFetchSuccess`, `prebidDemandNoBids`, `prebidSdkNotInitialized`.
_Avoid_: error code, status

**Stored auction response**:
A canned Prebid Server response, chosen by ID, that replaces the real auction; a testing aid. A **stored bid response** does the same for one bidder.
_Avoid_: mock response

**Auto-refresh**:
Re-running an ad unit's auction on an interval. For a Prebid-rendered banner the new ad replaces the old one; for an Original API ad unit each result is handed to the app to reload its ad server ad.

### Integrations

**Integration**:
The way an app puts Prebid demand on screen: Prebid rendering, the Original API, GAM rendering, or AdMob / MAX mediation.

**Rendering API**:
Prebid's ad units that both run the auction and render the winning creative themselves (Prebid's `BannerView`, `InterstitialAdUnit`, `RewardedAdUnit`). The core's `PrebidBannerAd`, `PrebidInterstitialAd` and `PrebidRewardedAd` are built on it; so are the GAM companion's banner, interstitial and rewarded ads, through event handlers.
_Avoid_: In-App Bidding, Prebid Rendered

**Prebid rendering**:
The integration with no ad server: the Rendering API on its own, plus In-App native.
_Avoid_: standalone, Prebid-only

**Original API**:
The integration where Prebid only runs the auction and returns targeting keywords; the app's ad server renders the winning bid through the Prebid Universal Creative. Its classes are `PrebidBannerAdUnit`, `PrebidInterstitialAdUnit`, `PrebidNativeAdUnit`, `PrebidMultiformatAd` and `PrebidInstreamVideoAd`; GAM native follows the same flow.
_Avoid_: GAM coordination, keyword handoff API, header bidding API

**Ad server**:
The SDK and service that decide between Prebid's winning bid and their own demand: Google Ad Manager (GAM), AdMob or AppLovin MAX.
_Avoid_: primary SDK, mediation platform (for GAM)

**Primary ad win**:
The outcome where the ad server's own ad, not Prebid's bid, renders.
_Avoid_: fallback, no-fill

**Core package**:
`prebid_mobile_sdk`: Prebid itself (configuration, targeting, privacy, Prebid rendering and the Original API), with no ad server SDK.
_Avoid_: main plugin, base package

**Companion package**:
A package that integrates Prebid with one ad server on top of the core package: `prebid_mobile_sdk_gam`, `prebid_mobile_sdk_admob`, `prebid_mobile_sdk_max`.
_Avoid_: adapter, extension, add-on

**Companion library**:
`package:prebid_mobile_sdk/companion.dart`: the part of the core package's API that only companion packages use.
_Avoid_: internal API, shared module

**Event handler**:
Prebid's GAM bridge for the Rendering API: GAM runs its own auction against Prebid's targeting keywords and, when the Prebid line item wins, hands the rendering back to Prebid. Only the GAM companion uses event handlers.
_Avoid_: adapter, mediation adapter

**Mediation adapter**:
Prebid's network adapter inside AdMob or MAX mediation: the ad server calls it as a custom network in its waterfall and it renders the Prebid creative when Prebid wins. Used by the AdMob and MAX companions.
_Avoid_: event handler, custom event (that is AdMob's setup name)

### Native

**Native ad**:
An ad delivered as separate assets (title, images, data) that the app lays out, instead of as a rendered creative.

**Native parameters**:
The native request of an ad (OpenRTB Native 1.2): the assets, event trackers, context, placement and options. Every native ad in every package takes one.
_Avoid_: native config, native request config

**Native asset**:
One element of a native ad, requested by type: a title, an image (main, icon) or a data value (sponsored, description, call to action, rating, …).
_Avoid_: native field, native element

**Event tracker**:
A request for tracking URLs of one event (an impression, viewability) in the native response, with the tracking methods the app accepts.
_Avoid_: impression tracker (that is one kind)

**In-App native**:
A native ad from Prebid with no ad server: Prebid runs the auction and returns the assets, the app shows them in a `PrebidNativeAdView` (a native layout, or its own Flutter layout), and Prebid tracks the impression and clicks. `PrebidNativeAd` is In-App native.
_Avoid_: Prebid native, rendered native

**Custom-format native**:
A GAM native ad of a custom native format the publisher defines in GAM; when it carries Prebid's winning bid, Prebid takes it over and renders the native assets.
_Avoid_: custom-template native, custom native template (GAM's older name)

**Unified native**:
A standard Google Mobile Ads native ad (not a custom format). Prebid looks for its winning bid in it as well; without one, the GAM ad renders.
_Avoid_: GMA native, standard native

### Ad lifecycle

**Impression**:
The moment an ad counts as seen. For In-App native it is measured by the plugin: at least half the ad on screen for one second, including Flutter's own clipping, reported once per ad. Elsewhere it is what the rendering SDK reports (for a GAM Prebid native creative: Prebid's tracker request succeeding).
_Avoid_: impression tracker fired, view

**Destroy**:
The app ending one ad's native lifetime; the Dart object stays usable and a later load starts afresh.
_Avoid_: dispose, release

**Release**:
The plugin dropping every native ad left by a previous Dart isolate after a hot restart, before the new isolate's first ad (`releaseAds` in the core, `releaseAll` on a companion channel).
_Avoid_: destroy, dispose, reset

**Ad ID**:
The number the Dart side gives an ad object (fullscreen ads, native ads, Original API ad units) so that native events reach the right object over a channel that many ads share.
_Avoid_: ad unit ID, view ID

**Channel ID**:
The number a Dart widget gives its platform view before the view exists; the native view names its own method channel after it.
_Avoid_: view ID, platform view ID

**Fullscreen controls**:
How Prebid presents a Prebid-rendered interstitial or rewarded ad: close and skip buttons, sound, auto-close, minimum size and SKOverlay.
_Avoid_: interstitial settings, player options

**Drop bid**:
A testing hook of the AdMob and MAX companions that, with a set probability, throws the Prebid bid away after the auction so the mediation waterfall runs without it.
_Avoid_: filter out uncached bids (that drops bids whose Prebid Cache entry failed)

### Request signals

**ORTB config**:
OpenRTB JSON merged into bid requests. **impOrtbConfig** is merged into one ad unit's `imp`; an ad unit's **globalOrtbConfig** is merged into that ad unit's request; the global ORTB config (`PrebidTargeting.setGlobalOrtbConfig`) is merged into every request.
_Avoid_: ORTB params, OpenRTB settings

**pbAdSlot**:
The Prebid ad slot (`imp.ext.data.pbadslot`): the publisher's name for the slot an ad unit fills, for reporting and targeting.
_Avoid_: ad slot ID, slot name

**GPID**:
The Global Placement ID (`imp.ext.gpid`): an identifier of the placement that stays the same across the supply chain.
_Avoid_: placement ID

**External user ID**:
One OpenRTB `user.eids` entry from an identity module: a source (e.g. `uidapi.com`) with one or more unique IDs.
_Avoid_: EID list, user ID

**Unique ID**:
One identifier within an external user ID, with its agent type (`atype`).
_Avoid_: uid, user ID
