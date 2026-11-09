import SwiftUI

@main
struct HookLinkApp: App {
    @StateObject private var app = HookLink()

    init() {
        // Command-line checks of the phone steps, for testing and support (the window isn't opened):
        //   HookLink --backup-saves            HookLink --restore-saves <backup folder>
        let args = CommandLine.arguments
        if let i = args.firstIndex(where: { $0 == "--backup-saves" || $0 == "--restore-saves" }) {
            let restore = args[i] == "--restore-saves", from = i + 1 < args.count ? args[i + 1] : nil
            Task { @MainActor in
                let h = HookLink()
                if restore, let from { await h.restoreSaves(from: URL(fileURLWithPath: from)) } else { await h.backupSaves("backup") }
                print(h.saveStatus); exit(h.saveStatus.hasPrefix("✓") ? 0 : 1)
            }
            RunLoop.main.run()
        }
    }
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
