import Flutter
import PrebidMobile
import XCTest

@testable import prebid_mobile_sdk

// Unit tests of the core plugin's native side: the conversions between the
// Pigeon types and Prebid iOS. Run them with
// `xcodebuild test -workspace Runner.xcworkspace -scheme Runner` from
// example/ios (CI: .github/workflows/flutter_ci.yml). `@testable import`
// works because the plugins build with testability in Debug (the Pods
// project's default).

class PigeonConversionsTests: XCTestCase {
    func testResultCodesUseTheDartNames() {
        XCTAssertEqual(ResultCode.prebidDemandFetchSuccess.dartCode, "prebidDemandFetchSuccess")
        XCTAssertEqual(ResultCode.prebidDemandNoBids.dartCode, "prebidDemandNoBids")
        XCTAssertEqual(ResultCode.prebidServerURLInvalid.dartCode, "prebidServerURLInvalid")
        XCTAssertEqual(ResultCode.prebidDemandTimedOut.dartCode, "prebidDemandTimedOut")
    }

    func testBothSdkMisuseCodesShareOneDartName() {
        XCTAssertEqual(ResultCode.prebidSDKMisuse.dartCode, "prebidSDKMisuse")
        XCTAssertEqual(ResultCode.prebidSDKMisusePreviousFetchNotCompletedYet.dartCode, "prebidSDKMisuse")
    }

    func testTitleAssetDefaultsTo90CharactersAndSendsItsExt() {
        let title = NativeAssetConfig(assetType: "title", required_: true, ext: #"{"k":1}"#).makePrebidAsset()
        XCTAssertEqual(
            nativeRequestJSON(assets: [title!]).assets,
            [["required": 1, "title": ["len": 90, "ext": ["k": 1]] as [String: Any]]]
        )
    }

    func testImageAssetSendsItsSizesTypeAndMimes() {
        let image = NativeAssetConfig(
            assetType: "image",
            required_: false,
            imageType: 3,
            imageWidth: 1200,
            imageHeight: 627,
            imageWidthMin: 300,
            imageHeightMin: 157,
            imageMimes: ["image/png", nil],
            // Prebid iOS has no asset-level ext: dropped.
            assetExt: #"{"a":1}"#
        ).makePrebidAsset()
        XCTAssertEqual(
            nativeRequestJSON(assets: [image!]).assets,
            [
                [
                    "required": 0,
                    "img": ["type": 3, "w": 1200, "h": 627, "wmin": 300, "hmin": 157, "mimes": ["image/png"]]
                        as [String: Any],
                ]
            ]
        )
    }

    func testDataAssetSendsItsTypeAndLength() {
        let data = NativeAssetConfig(assetType: "data", required_: true, dataType: 2, dataLength: 140)
            .makePrebidAsset()
        XCTAssertEqual(
            nativeRequestJSON(assets: [data!]).assets,
            [["required": 1, "data": ["type": 2, "len": 140]]]
        )
    }

    func testAssetsOfAnUnknownTypeAreDropped() {
        XCTAssertNil(NativeAssetConfig(assetType: "video", required_: true).makePrebidAsset())
        XCTAssertNil(NativeAssetConfig(assetType: "data", required_: true, dataType: 99).makePrebidAsset())
        XCTAssertNil(NativeAssetConfig(assetType: "data", required_: true).makePrebidAsset())
    }

    func testInvalidExtJsonIsIgnored() {
        let title = NativeAssetConfig(assetType: "title", required_: false, titleLength: 25, ext: "not json")
            .makePrebidAsset()
        XCTAssertEqual(nativeRequestJSON(assets: [title!]).assets, [["required": 0, "title": ["len": 25]]])
    }

    func testTrackerSendsItsEventAndMethods() {
        let tracker = NativeEventTrackerConfig(eventType: 1, methods: [1, 2], ext: #"{"t":"x"}"#).makePrebidTracker()
        XCTAssertEqual(nativeRequestJSON(trackers: [tracker]).trackers, [["event": 1, "methods": [1, 2]]])
    }

    func testImpOrtbAddsThePbAdSlotToTheImpExtData() {
        XCTAssertEqual(
            jsonObject(impOrtb(#"{"ext":{"data":{"k":"v"}},"bidfloor":1}"#, pbAdSlot: "/slot")) as NSDictionary?,
            ["ext": ["data": ["k": "v", "pbadslot": "/slot"]], "bidfloor": 1]
        )
        XCTAssertEqual(
            jsonObject(impOrtb(nil, pbAdSlot: "/slot")) as NSDictionary?,
            ["ext": ["data": ["pbadslot": "/slot"]]]
        )
    }

    func testImpOrtbKeepsAPbAdSlotTheJsonSets() {
        XCTAssertEqual(
            jsonObject(impOrtb(#"{"ext":{"data":{"pbadslot":"/own"}}}"#, pbAdSlot: "/slot")) as NSDictionary?,
            ["ext": ["data": ["pbadslot": "/own"]]]
        )
    }

    func testImpOrtbWithoutAPbAdSlotReturnsTheJsonUnchanged() {
        XCTAssertEqual(impOrtb("not json", pbAdSlot: nil), "not json")
        XCTAssertNil(impOrtb(nil, pbAdSlot: nil))
    }

    func testAdFormatSetKeepsKnownNames() {
        XCTAssertEqual(adFormatSet(["banner", "video", "native"]), [AdFormat.banner, AdFormat.video])
        XCTAssertNil(adFormatSet(["native"]))
        XCTAssertNil(adFormatSet(nil))
    }

    func testVideoParametersConfigSetsEveryParameter() {
        let vp = VideoParametersConfig(
            mimes: ["video/mp4"],
            protocols: [2, 3],
            playbackMethods: [1],
            placement: 3,
            maxDuration: 30,
            minDuration: 5,
            api: [1, nil, 2],
            plcmt: 4,
            startDelay: -1,
            linearity: 1,
            skippable: true,
            battr: [13],
            minBitrate: 300,
            maxBitrate: 1500,
            width: 640,
            height: 480
        ).makeVideoParameters()
        XCTAssertEqual(vp.mimes, ["video/mp4"])
        XCTAssertEqual(vp.protocols?.map(\.value), [2, 3])
        XCTAssertEqual(vp.playbackMethod?.map(\.value), [1])
        XCTAssertEqual(vp.placement?.value, 3)
        XCTAssertEqual(vp.maxDuration?.value, 30)
        XCTAssertEqual(vp.minDuration?.value, 5)
        XCTAssertEqual(vp.api?.map(\.value), [1, 2])
        XCTAssertEqual(vp.plcmnt?.value, 4)
        XCTAssertEqual(vp.startDelay?.value, -1)
        XCTAssertEqual(vp.linearity?.value, 1)
        XCTAssertEqual(vp.isSkippable, true)
        XCTAssertEqual(vp.battr?.map(\.value), [13])
        XCTAssertEqual(vp.minBitrate?.value, 300)
        XCTAssertEqual(vp.maxBitrate?.value, 1500)
        XCTAssertEqual(vp.adSize, CGSize(width: 640, height: 480))
    }

    func testVideoParametersConfigLeavesAbsentParametersUnset() {
        let vp = VideoParametersConfig(mimes: ["video/mp4"], width: 640).makeVideoParameters()
        XCTAssertNil(vp.protocols)
        XCTAssertNil(vp.placement)
        XCTAssertNil(vp.maxDuration)
        XCTAssertNil(vp.isSkippable)
        XCTAssertNil(vp.adSize)
    }

    func testVideoParametersPayloadSetsTheParametersItHas() {
        let vp = VideoParameters(mimes: [])
        applyVideoParameters(
            [
                "mimes": ["video/mp4"], "protocols": [2], "maxDuration": 30, "skippable": false, "width": 320,
                "height": 50,
            ],
            to: vp
        )
        XCTAssertEqual(vp.mimes, ["video/mp4"])
        XCTAssertEqual(vp.protocols?.map(\.value), [2])
        XCTAssertEqual(vp.maxDuration?.value, 30)
        XCTAssertEqual(vp.isSkippable, false)
        XCTAssertEqual(vp.adSize, CGSize(width: 320, height: 50))
        XCTAssertNil(vp.placement)
    }

    func testFullscreenMinSizeNeedsBothPercentages() {
        XCTAssertEqual(
            FullscreenControlsConfig(minWidthPercentage: 50, minHeightPercentage: 40).minSizePercentage,
            CGSize(width: 50, height: 40)
        )
        XCTAssertNil(FullscreenControlsConfig(minWidthPercentage: 50).minSizePercentage)
    }
}

/// The external user IDs through the host API: Pigeon data to Prebid's
/// `ExternalUserId` and back.
class ExternalUserIdsTests: XCTestCase {
    private let api = PrebidMobileHostApiImpl(
        eventFlutterApi: PrebidEventFlutterApi(binaryMessenger: SilentMessenger()),
        releaseAds: {}
    )

    override func tearDown() {
        Targeting.shared.setExternalUserIds([])
        super.tearDown()
    }

    func testExternalUserIdsRoundTripEveryField() throws {
        let ids = [
            ExternalUserIdData(
                source: "uidapi.com",
                uids: [
                    UserUniqueIdData(id: "uid2-abc", atype: 3, ext: ["rtiPartner": "UID2"]),
                    UserUniqueIdData(id: "uid2-def", atype: 1),
                ],
                ext: ["segment": "a"],
                inserter: "inserter.com",
                matcher: "matcher.com",
                mm: 2
            ),
            ExternalUserIdData(source: "sharedid.org", uids: [UserUniqueIdData(id: "shared-xyz", atype: 1)]),
        ]

        try api.setExternalUserIds(userIds: ids)

        XCTAssertEqual(try api.getExternalUserIds(), ids)
    }

    func testSetExternalUserIdsDropsNullKeysAndValuesFromTheExts() throws {
        try api.setExternalUserIds(userIds: [
            ExternalUserIdData(
                source: "id5-sync.com",
                uids: [UserUniqueIdData(id: "id5", atype: 1, ext: ["k": "v", "gone": nil])],
                ext: ["k": "v", nil: "gone"]
            )
        ])

        let id = try XCTUnwrap(api.getExternalUserIds().first)
        XCTAssertEqual(id.ext?.count, 1)
        XCTAssertEqual(id.ext?["k"] as? String, "v")
        let uid = try XCTUnwrap(id.uids.first ?? nil)
        XCTAssertEqual(uid.ext?.count, 1)
        XCTAssertEqual(uid.ext?["k"] as? String, "v")
    }

    func testClearExternalUserIdsRemovesEveryId() throws {
        try api.setExternalUserIds(userIds: [
            ExternalUserIdData(source: "a.com", uids: [UserUniqueIdData(id: "1", atype: 1)])
        ])

        try api.clearExternalUserIds()

        XCTAssertEqual(try api.getExternalUserIds(), [])
    }
}

/// A messenger for Pigeon Flutter APIs that never send in these tests.
private final class SilentMessenger: NSObject, FlutterBinaryMessenger {
    func send(onChannel channel: String, message: Data?) {}

    func send(onChannel channel: String, message: Data?, binaryReply callback: FlutterBinaryReply?) {}

    func setMessageHandlerOnChannel(
        _ channel: String,
        binaryMessageHandler handler: FlutterBinaryMessageHandler?
    ) -> FlutterBinaryMessengerConnection { 0 }

    func cleanUpConnection(_ connection: FlutterBinaryMessengerConnection) {}
}
