import AppKit
import SwiftUI

/// The current Board as a QR code: printed cards, or a quick hand-off to another Mac.
struct BoardQRView: View {
    @ObservedObject var controller: BoardController
    @State private var image: NSImage?

    var body: some View {
        VStack(spacing: 12) {
            if let image {
                Image(nsImage: image)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 240, height: 240)
                    .accessibilityLabel("QR code for the current board")
                Button("Save QR Code…") { controller.saveQRCode() }
            } else {
                ContentUnavailableView {
                    Label("No QR code", systemImage: "qrcode")
                } description: {
                    Text("There is no board, or it is too large for a QR code. Share it as a file instead.")
                }
            }
        }
        .padding()
        .frame(width: 300, height: 340)
        .onAppear { image = controller.qrCodeImage() }
        .onChange(of: controller.timers.count) { image = controller.qrCodeImage() }
    }
}

enum BoardQRWindow {
    static let id = "qr"
}
