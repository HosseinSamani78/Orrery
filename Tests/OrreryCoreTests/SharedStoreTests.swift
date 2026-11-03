import XCTest
import OrreryCore

final class SharedStoreTests: XCTestCase {
    func testStoreURLPointsAtTheOrreryStoreFile() {
        XCTAssertEqual(SharedStore.storeURL.lastPathComponent, "Orrery.store")
    }

    func testStoreURLFallsBackToTheAppStoreWithoutAnAppGroupContainer() throws {
        try XCTSkipIf(
            FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: SharedStore.appGroupIdentifier) != nil,
            "Running with the App Group container available"
        )

        XCTAssertEqual(SharedStore.storeURL, BoardStore.defaultStoreURL)
    }

    func testChangeSignalReachesAnObserver() {
        let received = expectation(description: "store change signal")
        received.assertForOverFulfill = false
        let observation = StoreChangeSignal.observe { received.fulfill() }

        StoreChangeSignal.post()

        wait(for: [received], timeout: 2)
        observation.cancel()
    }
}
