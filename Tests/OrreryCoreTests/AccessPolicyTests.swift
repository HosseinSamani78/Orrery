import XCTest
import OrreryCore

final class AccessPolicyTests: XCTestCase {
    func testFreeTierStopsAtItsCeilings() {
        XCTAssertTrue(AccessPolicy.free.canAddBoard(existing: 0))
        XCTAssertFalse(AccessPolicy.free.canAddBoard(existing: 1))

        XCTAssertTrue(AccessPolicy.free.canAddTimer(existing: FreeLimits.timers - 1))
        XCTAssertFalse(AccessPolicy.free.canAddTimer(existing: FreeLimits.timers))
    }

    func testProTierHasNoCeilings() {
        XCTAssertTrue(AccessPolicy.pro.canAddBoard(existing: 500))
        XCTAssertTrue(AccessPolicy.pro.canAddTimer(existing: 500))
    }

    func testWidgetsAreProOnly() {
        XCTAssertFalse(AccessPolicy.free.widgetsEnabled)
        XCTAssertTrue(AccessPolicy.pro.widgetsEnabled)
    }
}
