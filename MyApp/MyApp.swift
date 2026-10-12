import SwiftUI

@main
struct MyApp: App {
    @State private var model = HydrationModel()

    var body: some Scene {
        MenuBarExtra("Water Reminder", systemImage: "drop.fill") {
            ContentView(model: model)
        }
        .menuBarExtraStyle(.window)
    }
}
