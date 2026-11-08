import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject var app: HookLink
    @State private var showLog = false

    var body: some View {
        NavigationSplitView {
            List(Step.allCases, selection: Binding(get: { app.step }, set: { if let s = $0, !app.busy { app.step = s } })) { s in
                Label(s.title, systemImage: icon(s)).tag(s)
            }
            .navigationSplitViewColumnWidth(min: 190, ideal: 210)
        } detail: {
            VStack(spacing: 0) {
                if app.engineUpdate != nil || app.appUpdate != nil || !app.updateMessage.isEmpty { UpdateBanner(); Divider() }
                ScrollView { page.padding(28).frame(maxWidth: 680, alignment: .leading).frame(maxWidth: .infinity, alignment: .leading) }
                Divider()
                HStack {
                    Button(showLog ? "Hide details" : "Show details") { showLog.toggle() }.buttonStyle(.link)
                    Spacer()
                    if app.step != .welcome { Button("Back") { app.step = Step(rawValue: app.step.rawValue - 1)! }.disabled(app.busy) }
                    if app.step != .done { Button("Next") { app.step = Step(rawValue: app.step.rawValue + 1)! }.keyboardShortcut(.defaultAction).disabled(app.busy || !canGoOn) }
                }.padding(12)
                if showLog { LogView().frame(height: 180) }
            }
        }
        .frame(minWidth: 860, minHeight: 600)
        .task { await app.checkForUpdates() }   // at every launch: quiet when offline
    }

    var canGoOn: Bool {
        switch app.step {
        case .mac: return app.macReady
        case .game: return app.gameChosen
        case .build: return app.buildOK
        case .copy: return app.copyOK
        default: return true
        }
    }

    @ViewBuilder var page: some View {
        switch app.step {
        case .welcome: WelcomePage()
        case .mac: MacPage()
        case .game: GamePage()
        case .phoneModel: PhonePage()
        case .build: BuildPage()
        case .install: InstallPage()
        case .copy: CopyPage()
        case .done: DonePage()
        }
    }

    func icon(_ s: Step) -> String {
        switch s {
        case .welcome: return "hand.wave"
        case .mac: return "laptopcomputer"
        case .game: return "opticaldiscdrive"
        case .phoneModel: return "iphone"
        case .build: return "hammer"
        case .install: return "square.and.arrow.down"
        case .copy: return "cable.connector"
        case .done: return "gamecontroller"
        }
    }
}

struct PageTitle: View {
    let title: String, subtitle: String
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.largeTitle.bold())
            Text(subtitle).foregroundStyle(.secondary)
        }.padding(.bottom, 18)
    }
}

struct WelcomePage: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            PageTitle(title: "HookLink", subtitle: "Build The Legend of Zelda: Ocarina of Time (Nintendo Switch 2 Edition) for your iPhone, from your own copy of the game.")
            Text("HookLink walks you through it:").font(.headline)
            VStack(alignment: .leading, spacing: 8) {
                Label("Checks your Mac has what the build needs", systemImage: "1.circle")
                Label("Builds the iPhone app from your game file (.nup)", systemImage: "2.circle")
                Label("Tells you how to install it with your sideloading tool", systemImage: "3.circle")
                Label("Copies your game files to the phone over a cable", systemImage: "4.circle")
            }
            GroupBox {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Your game stays yours").font(.headline)
                    Text("HookLink contains no game files, keys or built apps. Everything it makes comes from your own copy and stays on your Mac and your phone. Never share those files.")
                }.frame(maxWidth: .infinity, alignment: .leading).padding(4)
            }
            Text("You need: a Mac with Apple silicon, Xcode 27.2, about 80 GB free, a cable for your iPhone, and your game at update v131072. The first build takes a few hours.")
                .foregroundStyle(.secondary)
            Text("HookLink is a fan-made tool, not affiliated with or endorsed by Nintendo.").font(.footnote).foregroundStyle(.secondary)
        }
    }
}

struct MacPage: View {
    @EnvironmentObject var app: HookLink
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PageTitle(title: "Check your Mac", subtitle: "HookLink looks for the tools the build needs and can install most of them for you.")
            if app.checks.isEmpty { ProgressView().task { await app.runChecks() } }
            ForEach(app.checks) { c in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: c.state == .ok ? "checkmark.circle.fill" : c.state == .warn ? "exclamationmark.triangle.fill" : c.state == .missing ? "xmark.circle.fill" : "circle")
                        .foregroundStyle(c.state == .ok ? .green : c.state == .warn ? .orange : c.state == .missing ? .red : .secondary)
                    VStack(alignment: .leading) { Text(c.name).bold(); Text(c.detail).font(.callout).foregroundStyle(.secondary).textSelection(.enabled) }
                }
            }
            HStack {
                Button("Check again") { Task { await app.runChecks() } }.disabled(app.busy)
                if app.checks.contains(where: { $0.state == .missing }) {
                    Button("Install tools") { Task { await app.installTools() } }.buttonStyle(.borderedProminent).disabled(app.busy)
                }
                if app.busy { ProgressView().controlSize(.small) }
            }.padding(.top, 8)
            HStack {
                Text("Build folder:").bold()
                Text(app.folder.path).textSelection(.enabled).foregroundStyle(.secondary)
                Button("Change…") { pickFolder() }.disabled(app.busy)
            }.padding(.top, 8)
        }
    }
    func pickFolder() {
        let p = NSOpenPanel(); p.canChooseDirectories = true; p.canChooseFiles = false; p.canCreateDirectories = true
        p.message = "Choose a folder on a drive with about 80 GB free"
        if p.runModal() == .OK, let u = p.url { app.folderPath = u.path; Task { await app.runChecks() } }
    }
}

struct GamePage: View {
    @EnvironmentObject var app: HookLink
    @State private var dropTarget = false
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            PageTitle(title: "Choose your game", subtitle: "Your own dump of Ocarina of Time (Nintendo Switch 2 Edition), as a .nup file, with update v131072.")
            RoundedRectangle(cornerRadius: 12).strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [6]))
                .foregroundStyle(dropTarget ? Color.accentColor : .secondary)
                .frame(height: 140)
                .overlay {
                    VStack(spacing: 8) {
                        Image(systemName: app.gameChosen ? "checkmark.circle.fill" : "arrow.down.doc").font(.largeTitle).foregroundStyle(app.gameChosen ? .green : .secondary)
                        Text(app.gameChosen ? (app.nupPath as NSString).lastPathComponent : "Drop your .nup here").bold()
                        Button("Choose…") { pick() }
                    }
                }
                .onDrop(of: [.fileURL], isTargeted: $dropTarget) { items in
                    _ = items.first?.loadObject(ofClass: URL.self) { url, _ in if let url { Task { @MainActor in app.chooseGame(url) } } }
                    return true
                }
            Text("HookLink checks the game when the build starts and stops if it is not the supported version.").font(.callout).foregroundStyle(.secondary)
        }
    }
    func pick() {
        let p = NSOpenPanel(); p.canChooseFiles = true; p.canChooseDirectories = true; p.allowsMultipleSelection = false
        p.message = "Choose your game's .nup file"
        if p.runModal() == .OK, let u = p.url { app.chooseGame(u) }
    }
}

struct PhonePage: View {
    @EnvironmentObject var app: HookLink
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            PageTitle(title: "Choose your iPhone", subtitle: "The app is built for your iPhone's graphics chip, so it starts quickly and runs smoothly.")
            Picker("", selection: $app.gpu) {
                ForEach(PhoneModel.all) { m in
                    Text(m.name + (m.tested ? "  (tested)" : "  (not tested yet)")).tag(m.id)
                }
            }.pickerStyle(.radioGroup).labelsHidden()
            if let m = PhoneModel.all.first(where: { $0.id == app.gpu }), !m.tested {
                Text("This model has not been tested yet. It should work; please report how it runs.").foregroundStyle(.orange)
            }
            Text("Other iPhones are not supported yet: the game needs a recent iPhone's memory and graphics.").font(.callout).foregroundStyle(.secondary)
        }
    }
}

struct BuildPage: View {
    @EnvironmentObject var app: HookLink
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            PageTitle(title: "Build", subtitle: "HookLink builds the iPhone app from your game. The first build takes a few hours; you can keep using your Mac.")
            if app.buildOK {
                Label("The app is ready", systemImage: "checkmark.seal.fill").font(.title2).foregroundStyle(.green)
                HStack { Text(app.ipa.path).textSelection(.enabled).foregroundStyle(.secondary); Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([app.ipa]) } }
            } else if app.busy {
                Text("Step \(app.stageIndex) of \(app.stageCount): \(app.stageName)").font(.headline)
                if let f = app.stageFraction { ProgressView(value: f) } else { ProgressView().progressViewStyle(.linear) }
                if !app.stageETA.isEmpty { Text("About \(app.stageETA) left in this step").foregroundStyle(.secondary) }
                Button("Stop") { app.cancel() }
            } else {
                Button("Start the build") { Task { await app.build() } }.buttonStyle(.borderedProminent).controlSize(.large)
                    .disabled(!app.gameChosen)
            }
            if !app.buildError.isEmpty { Text(app.buildError).foregroundStyle(.red) }
            if !app.damagedFiles.isEmpty {
                Text("Your dump has \(app.damagedFiles.count) damaged file(s). The build goes on; those textures may look wrong in the game. Dumping the game again fixes it.").foregroundStyle(.orange)
            }
            Text("Keep your Mac plugged in. It will not sleep while HookLink builds.").font(.callout).foregroundStyle(.secondary)
        }
    }
}

struct InstallPage: View {
    @EnvironmentObject var app: HookLink
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            PageTitle(title: "Install", subtitle: "Install the app on your iPhone with your sideloading tool (for example iLoader, Sideloadly or AltStore).")
            VStack(alignment: .leading, spacing: 10) {
                Label("Open your sideloading tool and sign in with your Apple Account.", systemImage: "1.circle")
                Label("Choose HookLink-OcarinaOfTime.ipa from your build folder.", systemImage: "2.circle")
                Label("If it offers Increased Memory Limit, turn it on.", systemImage: "3.circle")
                Label("Install it. Updating later? Install over the old one; your saves and game files stay.", systemImage: "4.circle")
                Label("Don't open the game yet: it needs its game files first.", systemImage: "5.circle")
            }
            Button("Show the app in Finder") { NSWorkspace.shared.activateFileViewerSelecting([app.ipa]) }
            Text("Your phone needs Developer Mode on (Settings → Privacy & Security → Developer Mode) for the next step.").font(.callout).foregroundStyle(.secondary)
        }
    }
}

struct CopyPage: View {
    @EnvironmentObject var app: HookLink
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            PageTitle(title: "Copy game files", subtitle: "Plug your iPhone into this Mac with a cable, unlock it, and tap Trust if it asks.")
            HStack {
                Button("Find my iPhone") { Task { await app.findDevices() } }.disabled(app.busy)
                if app.busy && app.copyStatus.isEmpty { ProgressView().controlSize(.small) }
            }
            if app.devices.isEmpty {
                Text("No iPhone found yet.").foregroundStyle(.secondary)
            } else {
                Picker("iPhone", selection: $app.device) { ForEach(app.devices) { d in Text("\(d.name) (\(d.model))").tag(Optional(d)) } }
                    .frame(maxWidth: 420)
                if let d = app.device {
                    if !d.developerMode { Text("Turn on Developer Mode: Settings → Privacy & Security → Developer Mode, then restart the phone.").foregroundStyle(.orange) }
                    if app.bundleID.isEmpty {
                        Text("The game is not installed on this iPhone yet. Install it first (previous step), then click Find my iPhone again.").foregroundStyle(.orange)
                    } else {
                        Label("Game found on \(d.name)", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                        Button("Copy game files to my iPhone") { Task { await app.copyToPhone() } }.buttonStyle(.borderedProminent).controlSize(.large).disabled(app.busy)
                    }
                }
            }
            ForEach(Array(app.copyStatus.enumerated()), id: \.offset) { _, s in Text(s) }
            if app.busy && !app.copyStatus.isEmpty { ProgressView().progressViewStyle(.linear) }
            Text("This copies the game files from your own dump and the iPhone resolution file made from them. You only do this once per phone.").font(.callout).foregroundStyle(.secondary)
        }
    }
}

struct DonePage: View {
    @EnvironmentObject var app: HookLink
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            PageTitle(title: "Play", subtitle: "Open the game on your iPhone.")
            VStack(alignment: .leading, spacing: 8) {
                Text("• The first start shows \"Preparing shaders\" and can take a few minutes. Later starts take seconds.")
                Text("• A new area can stutter the first time you enter it. The next start prepares it, and it runs smoothly after that.")
                Text("• The phone gets warm in long sessions; it runs best unplugged and not in a case.")
            }
            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Something wrong?").font(.headline)
                    Text("Plug in your iPhone and click Get game log. It saves the game's log on your Desktop; attach it to an issue on HookLink's GitHub page with your iPhone model and where you were in the game. The log holds no game files.")
                    HStack {
                        Button("Get game log") { Task { await app.fetchLog() } }.disabled(app.busy)
                        Link("Report a problem", destination: URL(string: "https://github.com/dsi-hub/HookLink/issues/new/choose")!)
                        Link("Discord", destination: URL(string: "https://discord.gg/bSrN5kEScg")!)
                        if app.busy { ProgressView().controlSize(.small) }
                    }
                    if !app.logStatus.isEmpty { Text(app.logStatus).foregroundStyle(.secondary) }
                }.frame(maxWidth: .infinity, alignment: .leading).padding(4)
            }
        }
    }
}

struct LogView: View {
    @EnvironmentObject var app: HookLink
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 1) {
                    ForEach(Array(app.log.enumerated()), id: \.offset) { i, l in Text(l).font(.system(.caption, design: .monospaced)).textSelection(.enabled).id(i) }
                }.padding(8)
            }
            .background(Color(nsColor: .textBackgroundColor))
            .onChange(of: app.log.count) { _, n in proxy.scrollTo(n - 1, anchor: .bottom) }
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject var app: HookLink
    var body: some View {
        Form {
            TextField("Engine folder (for development)", text: $app.enginePathSetting)
            Text("Leave empty to use the engine HookLink downloads.").font(.caption).foregroundStyle(.secondary)
        }.padding(20).frame(width: 520)
    }
}
