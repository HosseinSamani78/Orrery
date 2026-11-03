import SwiftUI

extension View {
    /// Liquid Glass on macOS 26 and later, where the design language exists. Older systems keep
    /// their own window material rather than a hand-rolled imitation.
    @ViewBuilder
    func orreryGlass(cornerRadius: CGFloat = 16) -> some View {
        if #available(macOS 26.0, *) {
            glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
        } else {
            self
        }
    }
}
