import PrebidMobile
import XCTest

@testable import prebid_mobile_sdk_gam

// Unit tests of the companions' channel argument parsing
// (PrebidRequests.swift). The GAM, AdMob and MAX copies are identical
// (tool/check_copies.sh), so the GAM one stands for the three. The values
// mirror what Flutter's standard codec sends: NSNumber for a Dart int or
// double, String for `jsonEncode` output.

class PrebidRequestsTests: XCTestCase {
  func testIntValueReadsAnyNumber() {
    XCTAssertEqual(intValue(NSNumber(value: 7)), 7)
    XCTAssertEqual(intValue(NSNumber(value: 9.9)), 9)
    XCTAssertNil(intValue("7"))
    XCTAssertNil(intValue(nil))
  }

  func testJsonDictionaryParsesAJsonObjectString() {
    XCTAssertEqual(jsonDictionary(#"{"k":1,"n":{"a":"b"}}"#) as NSDictionary?, ["k": 1, "n": ["a": "b"]])
    XCTAssertNil(jsonDictionary("not json"))
    XCTAssertNil(jsonDictionary("[1]"))
    XCTAssertNil(jsonDictionary(["k": 1]))
    XCTAssertNil(jsonDictionary(nil))
  }

  func testNativeAssetsAreNilWithoutAList() {
    XCTAssertNil(nativeAssetsFrom(nil))
    XCTAssertNil(nativeAssetsFrom(["assetType": "title"] as [String: Any]))
  }

  func testNativeAssetsBuildATitleWithItsLengthAndExt() {
    let assets = nativeAssetsFrom([
      ["assetType": "title", "required": true, "titleLength": NSNumber(value: 25), "ext": #"{"k":1}"#],
    ] as [[String: Any]])
    XCTAssertEqual(
      nativeRequestJSON(assets: assets).assets,
      [["required": 1, "title": ["len": 25, "ext": ["k": 1]] as [String: Any]]]
    )
  }

  func testNativeTitleDefaultsTo90CharactersAndOptional() {
    let assets = nativeAssetsFrom([["assetType": "title"]] as [[String: Any]])
    XCTAssertEqual(nativeRequestJSON(assets: assets).assets, [["required": 0, "title": ["len": 90]]])
  }

  func testNativeAssetsBuildAnImageWithItsSizesTypeAndMimes() {
    let assets = nativeAssetsFrom([
      [
        "assetType": "image",
        "required": true,
        "imageType": NSNumber(value: 3),
        "imageWidth": NSNumber(value: 1200),
        "imageHeight": NSNumber(value: 627),
        "imageWidthMin": NSNumber(value: 300),
        "imageHeightMin": NSNumber(value: 157),
        "imageMimes": ["image/png", "image/jpeg"],
        // Prebid iOS has no asset-level ext: dropped.
        "assetExt": #"{"a":1}"#,
      ],
    ] as [[String: Any]])
    XCTAssertEqual(
      nativeRequestJSON(assets: assets).assets,
      [[
        "required": 1,
        "img": [
          "type": 3, "w": 1200, "h": 627, "wmin": 300, "hmin": 157, "mimes": ["image/png", "image/jpeg"],
        ] as [String: Any],
      ]]
    )
  }

  func testNativeAssetsBuildADataAssetWithItsTypeAndLength() {
    let assets = nativeAssetsFrom([
      ["assetType": "data", "dataType": NSNumber(value: 12), "dataLength": NSNumber(value: 15), "ext": #"{"d":2}"#],
    ] as [[String: Any]])
    XCTAssertEqual(
      nativeRequestJSON(assets: assets).assets,
      [["required": 0, "data": ["type": 12, "len": 15, "ext": ["d": 2]] as [String: Any]]]
    )
  }

  func testNativeAssetsSkipUnknownTypesAndDataWithoutAKnownType() {
    let assets = nativeAssetsFrom([
      ["assetType": "video"],
      ["assetType": "data"],
      ["assetType": "data", "dataType": NSNumber(value: 99)],
      ["assetType": "data", "dataType": NSNumber(value: 1)],
    ] as [[String: Any]])
    XCTAssertEqual(nativeRequestJSON(assets: assets).assets, [["required": 0, "data": ["type": 1]]])
  }

  func testNativeAssetsIgnoreAnInvalidExt() {
    let assets = nativeAssetsFrom([["assetType": "title", "ext": "{oops"]] as [[String: Any]])
    XCTAssertEqual(nativeRequestJSON(assets: assets).assets, [["required": 0, "title": ["len": 90]]])
  }

  func testNativeTrackersSendTheirEventAndMethods() {
    let trackers = nativeTrackersFrom([
      ["eventType": NSNumber(value: 1), "methods": [NSNumber(value: 1), NSNumber(value: 2)], "ext": #"{"t":"x"}"#],
      ["eventType": NSNumber(value: 2)],
    ] as [[String: Any]])
    XCTAssertEqual(
      nativeRequestJSON(trackers: trackers).trackers,
      [["event": 1, "methods": [1, 2]], ["event": 2, "methods": [Int]()]]
    )
  }

  func testNativeTrackersSkipTrackersWithoutAnEventType() {
    XCTAssertEqual(nativeTrackersFrom([["methods": [NSNumber(value: 1)]]] as [[String: Any]])?.count, 0)
    XCTAssertNil(nativeTrackersFrom(nil))
  }

  func testVideoParametersPayloadSetsEveryParameter() {
    let vp = VideoParameters(mimes: ["video/3gpp"])
    applyVideoParameters(
      [
        "mimes": ["video/mp4"],
        "protocols": [NSNumber(value: 2), NSNumber(value: 3)],
        "playbackMethods": [NSNumber(value: 1)],
        "api": [NSNumber(value: 2)],
        "placement": NSNumber(value: 3),
        "plcmt": NSNumber(value: 4),
        "startDelay": NSNumber(value: -1),
        "linearity": NSNumber(value: 1),
        "battr": [NSNumber(value: 13)],
        "skippable": true,
        "maxDuration": NSNumber(value: 30),
        "minDuration": NSNumber(value: 5),
        "maxBitrate": NSNumber(value: 1500),
        "minBitrate": NSNumber(value: 300),
      ] as [String: Any],
      to: vp
    )
    XCTAssertEqual(vp.mimes, ["video/mp4"])
    XCTAssertEqual(vp.protocols?.map(\.value), [2, 3])
    XCTAssertEqual(vp.playbackMethod?.map(\.value), [1])
    XCTAssertEqual(vp.api?.map(\.value), [2])
    XCTAssertEqual(vp.placement?.value, 3)
    XCTAssertEqual(vp.plcmnt?.value, 4)
    XCTAssertEqual(vp.startDelay?.value, -1)
    XCTAssertEqual(vp.linearity?.value, 1)
    XCTAssertEqual(vp.battr?.map(\.value), [13])
    XCTAssertEqual(vp.isSkippable, true)
    XCTAssertEqual(vp.maxDuration?.value, 30)
    XCTAssertEqual(vp.minDuration?.value, 5)
    XCTAssertEqual(vp.maxBitrate?.value, 1500)
    XCTAssertEqual(vp.minBitrate?.value, 300)
  }

  func testVideoParametersPayloadKeepsTheDefaultsForAbsentKeys() {
    let vp = VideoParameters(mimes: ["video/3gpp"])
    applyVideoParameters(["mimes": [String](), "maxDuration": NSNumber(value: 30)] as [String: Any], to: vp)
    XCTAssertEqual(vp.mimes, ["video/3gpp"])
    XCTAssertEqual(vp.maxDuration?.value, 30)
    XCTAssertNil(vp.protocols)
    XCTAssertNil(vp.isSkippable)

    applyVideoParameters(nil, to: vp)
    XCTAssertEqual(vp.maxDuration?.value, 30)
  }

  func testFullscreenControlsReadEveryControl() throws {
    let controls = try XCTUnwrap(FullscreenControls([
      "closeButtonArea": NSNumber(value: 0.2),
      "closeButtonPosition": "topLeft",
      "skipButtonArea": NSNumber(value: 1),
      "skipButtonPosition": "topRight",
      "skipDelay": NSNumber(value: 5),
      "isMuted": true,
      "isSoundButtonVisible": false,
      "isAutoCloseOnCompletionEnabled": true,
      "supportSKOverlay": false,
      "minWidthPercentage": NSNumber(value: 50),
      "minHeightPercentage": NSNumber(value: 40),
    ] as [String: Any]))
    XCTAssertEqual(controls.closeButtonArea, 0.2)
    XCTAssertEqual(controls.closeButtonPosition, .topLeft)
    XCTAssertEqual(controls.skipButtonArea, 1)
    XCTAssertEqual(controls.skipButtonPosition, .topRight)
    XCTAssertEqual(controls.skipDelay, 5)
    XCTAssertEqual(controls.isMuted, true)
    XCTAssertEqual(controls.isSoundButtonVisible, false)
    XCTAssertEqual(controls.isAutoCloseOnCompletionEnabled, true)
    XCTAssertEqual(controls.supportSKOverlay, false)
    XCTAssertEqual(controls.minSizePercentage, CGSize(width: 50, height: 40))
  }

  func testFullscreenControlsLeaveAbsentOrUnknownControlsUnset() throws {
    let controls = try XCTUnwrap(FullscreenControls([
      "closeButtonPosition": "bottomLeft",
      "minWidthPercentage": NSNumber(value: 50),
    ] as [String: Any]))
    XCTAssertNil(controls.closeButtonPosition)
    XCTAssertNil(controls.closeButtonArea)
    XCTAssertNil(controls.skipDelay)
    XCTAssertNil(controls.isMuted)
    XCTAssertNil(controls.minSizePercentage)
    XCTAssertNil(FullscreenControls(nil))
  }

  func testImpOrtbAddsThePbAdSlotToTheImpExtData() {
    XCTAssertEqual(
      jsonDictionary(impOrtb(#"{"ext":{"data":{"k":"v"}},"bidfloor":1}"#, pbAdSlot: "/slot")) as NSDictionary?,
      ["ext": ["data": ["k": "v", "pbadslot": "/slot"]], "bidfloor": 1]
    )
    XCTAssertEqual(
      jsonDictionary(impOrtb(nil, pbAdSlot: "/slot")) as NSDictionary?,
      ["ext": ["data": ["pbadslot": "/slot"]]]
    )
  }

  func testImpOrtbKeepsAPbAdSlotTheJsonSets() {
    XCTAssertEqual(
      jsonDictionary(impOrtb(#"{"ext":{"data":{"pbadslot":"/own"}}}"#, pbAdSlot: "/slot")) as NSDictionary?,
      ["ext": ["data": ["pbadslot": "/own"]]]
    )
  }

  func testImpOrtbWithoutAPbAdSlotReturnsTheJsonUnchanged() {
    XCTAssertEqual(impOrtb("not json", pbAdSlot: nil), "not json")
    XCTAssertNil(impOrtb(nil, pbAdSlot: nil))
  }
}
