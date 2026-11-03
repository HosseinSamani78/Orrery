import OrreryCore
import SwiftUI

/// Why the paywall appeared. The same sheet serves a blocked action and the menu item.
enum UpgradeReason: String, Identifiable {
    case timers
    case boards
    case manual

    var id: String { rawValue }

    var message: String {
        switch self {
        case .timers: "The free version runs \(FreeLimits.timers) timers at once."
        case .boards: "The free version keeps \(FreeLimits.boards) board."
        case .manual: "Unlimited boards and timers, plus widgets on your desktop."
        }
    }
}

struct UpgradeView: View {
    @ObservedObject var pro: ProStore
    let reason: UpgradeReason
    @Environment(\.dismiss) private var dismiss
    @State private var isWorking = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Orrery Pro", systemImage: "sparkles")
                .font(.title2.bold())
            Text(reason.message)
            Text("One purchase unlocks everything, on every Mac signed in to your Apple ID.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let product = pro.product {
                Button {
                    Task {
                        isWorking = true
                        errorMessage = nil
                        do {
                            _ = try await pro.purchase()
                        } catch {
                            errorMessage = error.localizedDescription
                        }
                        isWorking = false
                    }
                } label: {
                    Text("Buy Pro — \(product.displayPrice)")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isWorking || pro.isPurchasing)
            } else {
                Text("Orrery Pro is not available right now.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack {
                Button("Restore Purchases") {
                    Task { await pro.restore() }
                }
                Spacer()
                Button("Close") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
        }
        .padding(20)
        .frame(width: 360)
        .task { await pro.load() }
        .onChange(of: pro.tier) { _, tier in
            if tier == .pro { dismiss() }
        }
    }
}
