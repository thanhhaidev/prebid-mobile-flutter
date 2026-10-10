import XCTest

@testable import prebid_mobile_sdk

/// Smoke test of the core plugin's native side: the Dart result codes.
class RunnerTests: XCTestCase {
  func testResultCodesUseTheDartNames() {
    XCTAssertEqual(ResultCode.prebidDemandFetchSuccess.dartCode, "prebidDemandFetchSuccess")
    XCTAssertEqual(ResultCode.prebidDemandNoBids.dartCode, "prebidDemandNoBids")
  }
}
