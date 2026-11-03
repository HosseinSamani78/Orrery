import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// A Board as shared in a `.orreryboard` file: setup only, no run state, so the recipient
/// starts from a clean board.
public struct BoardDocument: Codable, Equatable, Sendable {
    public static let fileExtension = "orreryboard"
    public static let contentType = UTType(exportedAs: "com.orrery.board", conformingTo: .json)
    public static let currentVersion = 1

    /// The deep link a QR code carries. Orrery opens `orrery://import?board=…` as an import.
    public static let shareScheme = "orrery"
    public static let shareHost = "import"
    static let shareQueryItem = "board"
    /// QR version 40 at correction level L holds 2953 bytes, the most any QR code can carry.
    public static let maxQRPayloadBytes = 2953

    public var version: Int
    public var name: String
    public var phases: [String]
    public var timers: [PresetTimer]

    public init(name: String, phases: [String] = [], timers: [PresetTimer] = []) {
        version = Self.currentVersion
        self.name = name
        self.phases = phases
        self.timers = timers
    }

    public init(board: Board) {
        self.init(
            name: board.name,
            phases: board.phases.sorted { $0.order < $1.order }.map(\.name),
            timers: board.timers.map {
                PresetTimer(name: $0.name, type: $0.type, duration: $0.duration)
            }
        )
    }
}

public enum BoardDocumentError: Error, Equatable {
    case unsupportedVersion(Int)
    case invalidTimerDuration
    case boardTooLargeForQRCode(Int)
    case invalidShareLink
    case qrCodeGenerationFailed
}

extension BoardDocument {
    /// The link a QR code carries. base64url is unreserved, so the payload needs no
    /// percent-encoding and stays inside a QR code's capacity.
    public func shareURL() throws -> URL {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let payload = try encoder.encode(self).base64URLEncodedString()
        guard payload.utf8.count <= Self.maxQRPayloadBytes else {
            throw BoardDocumentError.boardTooLargeForQRCode(payload.utf8.count)
        }
        var components = URLComponents()
        components.scheme = Self.shareScheme
        components.host = Self.shareHost
        components.queryItems = [URLQueryItem(name: Self.shareQueryItem, value: payload)]
        guard let url = components.url else { throw BoardDocumentError.invalidShareLink }
        return url
    }

    public init(shareURL url: URL) throws {
        guard url.scheme == Self.shareScheme,
              url.host == Self.shareHost,
              let payload = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                  .queryItems?.first(where: { $0.name == Self.shareQueryItem })?.value,
              let data = Data(base64URLEncoded: payload) else {
            throw BoardDocumentError.invalidShareLink
        }
        do {
            self = try JSONDecoder().decode(Self.self, from: data)
        } catch {
            throw BoardDocumentError.invalidShareLink
        }
    }

    /// A PNG of this board's link, sized `scale` pixels per QR module so it stays sharp when printed.
    public func qrPNGData(scale: CGFloat = 10) throws -> Data {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(try shareURL().absoluteString.utf8)
        filter.correctionLevel = "L"
        guard let code = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: scale, y: scale)),
              let image = CIContext().createCGImage(code, from: code.extent) else {
            throw BoardDocumentError.qrCodeGenerationFailed
        }
        let png = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            png, UTType.png.identifier as CFString, 1, nil
        ) else {
            throw BoardDocumentError.qrCodeGenerationFailed
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw BoardDocumentError.qrCodeGenerationFailed
        }
        return png as Data
    }
}

extension Data {
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    init?(base64URLEncoded string: String) {
        var base64 = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        base64 += String(repeating: "=", count: (4 - base64.count % 4) % 4)
        self.init(base64Encoded: base64)
    }
}

extension BoardStore {
    public func exportData(for board: Board) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(BoardDocument(board: board))
    }

    /// Imports a shared Board as a new idle Board. Unknown versions and invalid durations are
    /// rejected before a timer is built, so a bad file cannot trap the app.
    @discardableResult
    public func importBoard(from data: Data) throws -> Board {
        try importBoard(from: JSONDecoder().decode(BoardDocument.self, from: data))
    }

    @discardableResult
    public func importBoard(from document: BoardDocument) throws -> Board {
        guard document.version == BoardDocument.currentVersion else {
            throw BoardDocumentError.unsupportedVersion(document.version)
        }
        guard document.timers.allSatisfy({ $0.duration > 0 }) else {
            throw BoardDocumentError.invalidTimerDuration
        }
        return try createBoard(named: document.name, phases: document.phases, timers: document.timers)
    }
}

extension BoardDocumentError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .unsupportedVersion(let version):
            "This board was made with a newer version of Orrery (file version \(version))."
        case .invalidTimerDuration:
            "This board file contains a timer with an invalid duration."
        case .boardTooLargeForQRCode(let bytes):
            "This board is too large for a QR code (\(bytes) bytes). Share it as a file instead."
        case .invalidShareLink:
            "This board link is not a valid Orrery board."
        case .qrCodeGenerationFailed:
            "The QR code could not be generated."
        }
    }
}
