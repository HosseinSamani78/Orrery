import AppIntents
import Foundation
import WidgetKit

/// Starts or pauses one timer from a widget button. The change goes through the shared store,
/// so it works the same whether the system runs it in the app or in the widget extension.
public struct ToggleTimerIntent: AppIntent {
    public static let title: LocalizedStringResource = "Start or Pause Timer"
    public static let description = IntentDescription("Starts a timer, or pauses one that is running.")

    @Parameter(title: "Timer")
    public var timerID: String

    public init() {}

    public init(timerID: UUID) {
        self.timerID = timerID.uuidString
    }

    public func perform() async throws -> some IntentResult {
        guard let id = UUID(uuidString: timerID) else { return .result() }
        _ = try BoardStore().toggleTimer(id: id)
        StoreChangeSignal.post()
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
