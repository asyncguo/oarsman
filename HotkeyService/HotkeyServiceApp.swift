import SwiftUI

@main
struct HotkeyServiceApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    private let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView(context: persistenceController.viewContext)
                .environment(\.managedObjectContext, persistenceController.viewContext)
        }

        Settings {
            EmptyView()
        }
    }
}
