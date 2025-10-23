import AppKit
import CoreData
import SwiftUI

@MainActor
final class CommandPaletteController: NSObject, ObservableObject, NSPopoverDelegate {
    static let shared = CommandPaletteController()

    @Published private(set) var isPresented: Bool = false

    private let popover: NSPopover
    private weak var statusItem: NSStatusItem?
    private let paletteSize = NSSize(width: 460, height: 360)

    override init() {
        popover = NSPopover()
        super.init()
        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self
        popover.appearance = NSAppearance(named: .darkAqua)
        popover.contentSize = paletteSize
    }

    func attach(statusItem: NSStatusItem) {
        self.statusItem = statusItem
    }

    func toggle() {
        guard let statusItem else { return }
        if isPresented {
            dismiss()
        } else {
            present(from: statusItem)
        }
    }

    func presentPalette() {
        guard let statusItem else { return }
        present(from: statusItem)
    }

    func dismiss() {
        popover.performClose(nil)
        isPresented = false
    }

    private func present(from statusItem: NSStatusItem) {
        guard let button = statusItem.button else { return }

        if let hostingController = popover.contentViewController as? PaletteHostingController {
            hostingController.update(controller: self)
        } else {
            popover.contentViewController = PaletteHostingController(controller: self)
        }

        popover.contentSize = paletteSize
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        isPresented = true
    }

    func popoverDidClose(_ notification: Notification) {
        isPresented = false
    }
}

@MainActor
private final class PaletteHostingController: NSHostingController<AnyView> {
    init(controller: CommandPaletteController) {
        super.init(rootView: Self.makeView(controller: controller))
        preferredContentSize = NSSize(width: 460, height: 360)
    }

    @available(*, unavailable)
    required dynamic init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(controller: CommandPaletteController) {
        rootView = Self.makeView(controller: controller)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.wantsLayer = true
        view.layer?.cornerCurve = .continuous
        view.layer?.cornerRadius = 20
        view.layer?.masksToBounds = false
        view.layer?.backgroundColor = NSColor.clear.cgColor
        view.appearance = NSAppearance(named: .darkAqua)
    }

    private static func makeView(controller: CommandPaletteController) -> AnyView {
        AnyView(
            CommandPaletteView(controller: controller)
                .environment(\.managedObjectContext, PersistenceController.shared.viewContext)
        )
    }
}
