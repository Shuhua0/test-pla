import SwiftUI

@main
struct PlannerTestApp: App {
    @StateObject private var planner = Planner()
    var body: some Scene {
        WindowGroup {
            ContentView().environmentObject(planner)
        }
    }
}
