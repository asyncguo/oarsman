import SwiftUI

@main
struct HotkeyServiceApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    private let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.viewContext)
        }

        Settings {
            EmptyView()
        }
    }
}
