import CoreImage
import XCTest
import OrreryCore

final class BoardQRCodeTests: XCTestCase {
    private let document = BoardDocument(
        name: "Tea lesson",
        phases: ["Steep", "Rest"],
        timers: [PresetTimer(name: "Tea", type: .countdown, duration: 300)]
    )

    func testShareLinkRoundTripsTheBoard() throws {
        let url = try document.shareURL()

        XCTAssertEqual(url.scheme, BoardDocument.shareScheme)
        XCTAssertEqual(url.host, BoardDocument.shareHost)
        XCTAssertEqual(try BoardDocument(shareURL: url), document)
    }

    func testQRCodeDecodesBackToTheShareLink() throws {
        let png = try document.qrPNGData(scale: 12)
        let image = try XCTUnwrap(CIImage(data: png))
        let detector = try XCTUnwrap(
            CIDetector(
                ofType: CIDetectorTypeQRCode,
                context: CIContext(),
                options: [CIDetectorAccuracy: CIDetectorAccuracyHigh]
            )
        )
        let feature = try XCTUnwrap(detector.features(in: image).first as? CIQRCodeFeature)
        let payload = try XCTUnwrap(feature.messageString)

        XCTAssertEqual(payload, try document.shareURL().absoluteString)
        XCTAssertEqual(try BoardDocument(shareURL: XCTUnwrap(URL(string: payload))), document)
    }

    func testABoardTooLargeForAQRCodeIsRefused() {
        let huge = BoardDocument(name: String(repeating: "a", count: BoardDocument.maxQRPayloadBytes))

        XCTAssertThrowsError(try huge.shareURL()) { error in
            guard case .boardTooLargeForQRCode = error as? BoardDocumentError else {
                return XCTFail("unexpected error \(error)")
            }
        }
    }

    func testForeignLinksAreNotReadAsBoards() {
        let url = URL(string: "\(BoardDocument.shareScheme)://elsewhere?board=abc")!

        XCTAssertThrowsError(try BoardDocument(shareURL: url)) { error in
            XCTAssertEqual(error as? BoardDocumentError, .invalidShareLink)
        }
    }
}
