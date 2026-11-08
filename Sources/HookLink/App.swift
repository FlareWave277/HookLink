import SwiftUI

@main
struct HookLinkApp: App {
    @StateObject private var app = HookLink()
    @State private var sleepBlock: NSObjectProtocol?

    var body: some Scene {
        WindowGroup("HookLink") {
            ContentView()
                .environmentObject(app)
                .onChange(of: app.busy) { _, busy in
                    // Keep the Mac awake while HookLink builds or copies
                    if busy { sleepBlock = ProcessInfo.processInfo.beginActivity(options: [.idleSystemSleepDisabled, .userInitiated], reason: "HookLink is building") }
                    else if let s = sleepBlock { ProcessInfo.processInfo.endActivity(s); sleepBlock = nil }
                }
        }
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Check for Updates…") { Task { await app.checkForUpdates(); if app.engineUpdate == nil && app.appUpdate == nil { app.updateMessage = "HookLink and the game engine are up to date." } } }
            }
        }
        Settings { SettingsView().environmentObject(app) }
    }
}
