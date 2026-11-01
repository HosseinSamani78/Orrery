import XCTest
import OrreryCore

final class TimerFocusTests: XCTestCase {
    private let a = UUID(), b = UUID(), c = UUID()
    private var ids: [UUID] { [a, b, c] }

    func testNavigationWrapsInBothDirections() {
        var focus = TimerFocus(selectedID: a)

        focus.move(by: 1, through: ids)
        XCTAssertEqual(focus.selectedID, b)
        focus.move(by: 1, through: ids)
        focus.move(by: 1, through: ids)
        XCTAssertEqual(focus.selectedID, a)

        focus.move(by: -1, through: ids)
        XCTAssertEqual(focus.selectedID, c)
    }

    func testUnknownSelectionFallsBackToAnEnd() {
        var focus = TimerFocus(selectedID: UUID())

        focus.move(by: 1, through: ids)
        XCTAssertEqual(focus.selectedID, a)

        focus.select(UUID())
        focus.move(by: -1, through: ids)
        XCTAssertEqual(focus.selectedID, c)
    }

    func testEmptyBoardClearsTheSelection() {
        var focus = TimerFocus(selectedID: a)

        focus.move(by: 1, through: [])
        XCTAssertNil(focus.selectedID)
    }

    func testZeroStepKeepsAKnownSelectionAndRepairsADeadOne() {
        var focus = TimerFocus(selectedID: b)
        focus.move(by: 0, through: ids)
        XCTAssertEqual(focus.selectedID, b)

        focus.select(UUID())
        focus.move(by: 0, through: ids)
        XCTAssertEqual(focus.selectedID, a)
    }
}
