import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let commandPaletteController = CommandPaletteController.shared

    func applicationDidFinishLaunching(_ notification: Notification) {
        configureStatusItem()
        commandPaletteController.attach(statusItem: statusItem)
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else { return }

        button.image = menuBarImage()
        button.imagePosition = .imageOnly
        button.target = self
        button.action = #selector(toggleCommandPalette)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.toolTip = "HotkeyService Command Palette"
    }

    private func menuBarImage() -> NSImage? {
        if let namedImage = NSImage(named: "MenuBarIcon") {
            namedImage.isTemplate = true
            return namedImage
        }

        let fallback = NSImage(systemSymbolName: "rectangle.and.text.magnifyingglass", accessibilityDescription: "Command Palette Icon")
        fallback?.isTemplate = true
        return fallback
    }

    @objc private func toggleCommandPalette() {
        commandPaletteController.toggle()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        commandPaletteController.presentPalette()
        return true
    }
}
