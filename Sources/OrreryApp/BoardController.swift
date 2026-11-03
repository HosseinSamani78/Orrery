import AppKit
import Combine
import Foundation
import OrreryCore
import WidgetKit

/// Owns the live timers and the keyboard focus for both surfaces. SwiftUI re-reads `store`
/// whenever a published value changes; timer types stay plain, non-observable state machines.
@MainActor
final class BoardController: ObservableObject {
    let store: TimerStore
    let pro: ProStore
    private let boardStore: BoardStore?
    @Published private(set) var focus: TimerFocus
    @Published private(set) var now: Date = .now
    /// Non-nil while the paywall is up, either from a blocked action or the menu item.
    @Published var upgradeReason: UpgradeReason?
    private var changeObserver: StoreChangeSignal.Observation?
    private var openObserver: NSObjectProtocol?
    private var tierObserver: AnyCancellable?
    private var sharePicker: NSSharingServicePicker?

    init(
        store: TimerStore = TimerStore(),
        boardStore: BoardStore? = try? BoardStore(),
        pro: ProStore = ProStore()
    ) {
        self.store = store
        self.pro = pro
        self.boardStore = boardStore
        // Restore the shared store so the app opens with what the widget was showing.
        if let boardStore, let board = try? boardStore.currentBoard() {
            for timer in board.liveTimers where store.timer(id: timer.id) == nil {
                store.add(timer)
            }
        }
        self.focus = TimerFocus(selectedID: store.timers.first?.id)
        self.changeObserver = StoreChangeSignal.observe { [weak self] in
            Task { @MainActor in self?.reloadFromStore() }
        }
        self.tierObserver = pro.$tier.dropFirst().sink { _ in
            // Widgets are gated on the mirrored entitlement, so unlock them right away.
            WidgetCenter.shared.reloadAllTimelines()
        }
        Task { await pro.load() }
        self.openObserver = NotificationCenter.default.addObserver(
            forName: .openBoardDocument,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let url = notification.object as? URL else { return }
            Task { @MainActor in self?.importBoard(from: url) }
        }
    }

    var timers: [any TimerModel] { store.timers }
    var selectedID: UUID? { focus.selectedID }

    /// Advances every timer and republishes the clock so the views redraw.
    func advance(to date: Date) {
        let completed = store.update(at: date)
        now = date
        if !completed.isEmpty {
            persist()
        }
    }

    func select(_ id: UUID) {
        focus.select(id)
    }

    func moveFocus(by step: Int) {
        focus.move(by: step, through: timers.map(\.id))
    }

    @discardableResult
    func perform(_ action: TimerAction) -> Bool {
        if action == .quickStart {
            // Completed timers no longer run, so only live ones count against the free ceiling.
            let active = timers.filter { $0.status != .completed }.count
            guard pro.policy.canAddTimer(existing: active) else {
                upgradeReason = .timers
                return false
            }
            let timer = store.quickStart(at: now)
            focus.select(timer.id)
            persist()
            return true
        }
        // Nothing focused yet: pick the first timer so a shortcut still does something.
        if focus.selectedID == nil {
            focus.move(by: 0, through: timers.map(\.id))
        }
        guard let id = focus.selectedID else { return false }
        let performed = store.perform(action, on: id, at: now)
        // A delete leaves the old id behind; zero-step navigation repairs the selection.
        focus.move(by: 0, through: timers.map(\.id))
        if performed {
            persist()
        }
        return performed
    }

    /// Re-reads snapshots written by the widget, so its start/pause is not clobbered by the next save.
    private func reloadFromStore() {
        guard let boardStore, let board = try? boardStore.currentBoard() else { return }
        store.merge(board.liveTimers)
        focus.move(by: 0, through: timers.map(\.id))
        now = .now
    }

    /// Loads a shared Board — a `.orreryboard` file or an `orrery://import` link — as a new idle
    /// board and makes it the one on screen.
    func importBoard(from url: URL) {
        guard let boardStore else { return }
        let existing = (try? boardStore.boards().count) ?? 0
        guard pro.policy.canAddBoard(existing: existing) else {
            upgradeReason = .boards
            return
        }
        let imported: Board?
        if url.scheme == BoardDocument.shareScheme {
            imported = (try? BoardDocument(shareURL: url))
                .flatMap { try? boardStore.importBoard(from: $0) }
        } else {
            imported = (try? Data(contentsOf: url))
                .flatMap { try? boardStore.importBoard(from: $0) }
        }
        guard let board = imported else { return }
        store.replace(with: board.liveTimers)
        focus = TimerFocus(selectedID: store.timers.first?.id)
        now = .now
        StoreChangeSignal.post()
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Presents the native share sheet (AirDrop, Mail, Messages, Notes) for the current board.
    func shareBoard() {
        guard let board = currentBoard(),
              let data = try? JSONEncoder().encode(BoardDocument(board: board)),
              let anchor = NSApp.keyWindow?.contentView else { return }
        let name = board.name.replacingOccurrences(of: "/", with: "-")
        let url = FileManager.default.temporaryDirectory
            .appending(path: "\(name).\(BoardDocument.fileExtension)")
        do {
            try data.write(to: url)
        } catch {
            NSAlert(error: error).runModal()
            return
        }
        sharePicker = NSSharingServicePicker(items: [url])
        sharePicker?.show(relativeTo: anchor.bounds, of: anchor, preferredEdge: .minY)
    }

    /// The current board as a QR code, or `nil` when there is no board or it is too large for one.
    func qrCodeImage() -> NSImage? {
        guard let board = currentBoard(),
              let png = try? BoardDocument(board: board).qrPNGData() else { return nil }
        return NSImage(data: png)
    }

    func saveQRCode() {
        guard let board = currentBoard(),
              let png = try? BoardDocument(board: board).qrPNGData() else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = "\(board.name).png"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try png.write(to: url)
        } catch {
            NSAlert(error: error).runModal()
        }
    }

    private func currentBoard() -> Board? {
        guard let boardStore else { return nil }
        return try? boardStore.currentBoard()
    }

    /// Asks where to save the current board and writes it as a `.orreryboard` file.
    func exportBoard() {
        guard let boardStore, let board = try? boardStore.currentBoard() else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [BoardDocument.contentType]
        panel.nameFieldStringValue = "\(board.name).\(BoardDocument.fileExtension)"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try boardStore.exportData(for: board).write(to: url)
        } catch {
            NSAlert(error: error).runModal()
        }
    }

    /// Writes the countdown timers to the shared store, then tells the widget to re-read it.
    /// Only called when a run starts, pauses, completes or disappears, never on every tick.
    private func persist() {
        guard let boardStore else { return }
        do {
            let board: Board
            if let existing = try boardStore.currentBoard() {
                board = existing
            } else {
                board = try boardStore.createBoard(named: "Orrery")
            }
            let live = store.timers.compactMap { $0 as? CountdownTimer }
            for timer in live {
                board.record(timer)
            }
            for record in board.timers where !live.contains(where: { $0.id == record.timerID }) {
                board.removeRecord(id: record.timerID)
            }
            try boardStore.save()
            StoreChangeSignal.post()
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            // The widget keeps the last saved state; the next change retries.
        }
    }
}
