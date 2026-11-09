import Foundation
import SwiftUI

/// The one game HookLink builds: The Legend of Zelda: Ocarina of Time (Nintendo Switch 2 Edition), update v131072.
enum Game {
    static let titleID = "0400486024DEC000"
    static let version = "v131072"
    static let bundlePrefix = "org.nxnative.0400486024dec000"
}

/// iPhone models and the GPU each one's pipeline archive is made for.
struct PhoneModel: Identifiable, Hashable {
    let id: String          // GPU architecture for nxnative's --gpu
    let name: String
    let tested: Bool
    static let all: [PhoneModel] = [
        PhoneModel(id: "g19p", name: "iPhone 18 Pro / 18 Pro Max / iPhone Duo (A20 Pro)", tested: true),
        PhoneModel(id: "g18p", name: "iPhone 17, 17 Pro, 17 Pro Max, Air (A19 / A19 Pro)", tested: false),
    ]
}

enum Step: Int, CaseIterable, Identifiable {
    case welcome, mac, game, phoneModel, build, install, copy, done
    var id: Int { rawValue }
    var title: String {
        switch self {
        case .welcome: return "Welcome"
        case .mac: return "Check your Mac"
        case .game: return "Choose your game"
        case .phoneModel: return "Choose your iPhone"
        case .build: return "Build"
        case .install: return "Install"
        case .copy: return "Copy game files"
        case .done: return "Play"
        }
    }
}

struct Check: Identifiable {
    enum State { case unknown, ok, missing, warn }
    let id: String
    let name: String
    var state: State = .unknown
    var detail: String = ""
}

/// A connected iPhone, from devicectl.
struct Device: Identifiable, Hashable {
    let id: String          // devicectl identifier
    let name: String
    let model: String
    let developerMode: Bool
}

@MainActor
final class HookLink: ObservableObject {
    @Published var step: Step = .welcome
    @Published var log: [String] = []
    @Published var busy = false

    // Mac checks
    @Published var checks: [Check] = []

    // Choices
    @AppStorage("nupPath") var nupPath: String = ""
    @AppStorage("folderPath") var folderPath: String = NSHomeDirectory() + "/HookLink"
    @AppStorage("gpu") var gpu: String = "g19p"
    @AppStorage("appName") var appName: String = ""       // the name on the home screen; empty: the game's own
    @AppStorage("appIcon") var appIcon: String = ""       // a PNG or JPEG of the player's choice; empty: the game's own
    @AppStorage("enginePath") var enginePathSetting: String = ""

    // Build
    @Published var stageName = ""
    @Published var stageIndex = 0
    @Published var stageCount = 6
    @Published var stageFraction: Double? = nil
    @Published var stageETA: String = ""
    @Published var buildOK = false
    @Published var buildError = ""
    @Published var damagedFiles: [String] = []

    // Phone
    @Published var devices: [Device] = []
    @Published var device: Device? = nil
    @Published var bundleID: String = ""
    @Published var copyStatus: [String] = []
    @Published var copyOK = false

    // Updates (Updates.swift)
    @Published var engineUpdate: EngineUpdate? = nil
    @Published var appUpdate: AppUpdate? = nil
    @Published var updateMessage = ""
    @AppStorage("lastUpdateCheck") var lastUpdateCheck: Double = 0
    @Published var engineVersion: EngineVersion? = nil
    @Published var saveStatus = ""
    @Published var checkState: CheckState = .never

    @Published var work: WorkProgress? = nil   // the progress card (Progress.swift)

    private var runner: Runner?

    // MARK: Paths

    var support: URL {
        let u = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("HookLink")
        try? FileManager.default.createDirectory(at: u, withIntermediateDirectories: true)
        return u
    }
    /// nxnative with HookLink's changes. HOOKLINK_ENGINE or the Settings field overrides it (for development).
    var engine: URL {
        if let e = ProcessInfo.processInfo.environment["HOOKLINK_ENGINE"], !e.isEmpty { return URL(fileURLWithPath: e) }
        if !enginePathSetting.isEmpty { return URL(fileURLWithPath: enginePathSetting) }
        return support.appendingPathComponent("engine")
    }
    var venvPython: URL { support.appendingPathComponent("venv/bin/python3") }
    var folder: URL { URL(fileURLWithPath: (folderPath as NSString).expandingTildeInPath) }
    var workDir: URL { folder.appendingPathComponent("build") }
    var ipa: URL { folder.appendingPathComponent("HookLink-OcarinaOfTime.ipa") }
    var romfsImage: URL { workDir.appendingPathComponent("extract/\(Game.version)/RomFS.img") }
    var overlayFile: URL { support.appendingPathComponent("overlay/Pack/Bootup.Nin_Ounce_NVN2.pack.zs") }

    /// HookLink's own files (tools, presets): inside the app, or the source tree's Resources when run with `swift run`.
    var resources: URL {
        if let r = Bundle.main.resourceURL, FileManager.default.fileExists(atPath: r.appendingPathComponent("tools").path) { return r }
        if let e = ProcessInfo.processInfo.environment["HOOKLINK_RESOURCES"] { return URL(fileURLWithPath: e) }
        // `swift run` from the source folder: Resources beside the current directory (no build-machine path compiled in)
        return URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("Resources")
    }

    func say(_ s: String) { log.append(s); if log.count > 4000 { log.removeFirst(log.count - 4000) }; workDetail(s) }

    // MARK: Step 1: the Mac

    func runChecks() async {
        busy = true; defer { busy = false; endWork() }
        beginWork("Checking your Mac", steps: 9)
        var cs: [Check] = []
        func add(_ id: String, _ name: String, _ state: Check.State, _ detail: String) {
            cs.append(Check(id: id, name: name, state: state, detail: detail)); workStep(min(cs.count + 1, 9), name)
        }
        workStep(1, "Xcode")

        let xc = await Runner.capture(["xcodebuild", "-version"])
        let xcVer = xc.out.split(separator: "\n").first.map(String.init) ?? ""
        add("xcode", "Xcode", xc.status == 0 ? (xcVer.contains("27.") ? .ok : .warn) : .missing,
            xc.status == 0 ? "\(xcVer) (27.2 is the tested version)" : "Install Xcode 27.2 from developer.apple.com, open it once, then add the iOS platform in Settings → Components.")

        let mt = await Runner.capture(["xcrun", "-sdk", "iphoneos", "metal", "--version"])
        add("metal", "Metal toolchain", mt.status == 0 ? .ok : .missing, mt.status == 0 ? "Installed" : "Click Install tools below (runs: xcodebuild -downloadComponent MetalToolchain).")

        let brew = await Runner.capture(["brew", "--version"])
        add("brew", "Homebrew", brew.status == 0 ? .ok : .missing, brew.status == 0 ? (brew.out.split(separator: "\n").first.map(String.init) ?? "") : "Install it from brew.sh (one command in Terminal), then check again.")

        let py = await findPython()
        add("python", "Python 3.12 or newer", py != nil ? .ok : .missing, py.map { "\($0.version) at \($0.path)" } ?? "Click Install tools below (Homebrew's Python 3.13). The Python macOS comes with is too old.")

        let ios = await Runner.capture(["xcrun", "--sdk", "iphoneos", "--show-sdk-path"])
        add("ios", "Xcode's iOS platform", ios.status == 0 ? .ok : .missing,
            ios.status == 0 ? "Installed" : "Open Xcode → Settings → Components and install the iOS platform, then check again.")

        var tools: [String] = []
        for t in ["xcodegen", "zstd", "glslangValidator"] { if (await Runner.capture(["which", t])).status != 0 { tools.append(t) } }
        add("tools", "Build tools (xcodegen, zstd, glslang)", tools.isEmpty ? .ok : .missing, tools.isEmpty ? "Installed" : "Missing: \(tools.joined(separator: ", ")). Click Install tools below.")

        // The environment must be on a 3.12+ Python and hold the build's packages (an older HookLink could make one on macOS's 3.9)
        let venvCheck = FileManager.default.fileExists(atPath: venvPython.path)
            ? await Runner.capture([venvPython.path, "-c", "import sys, lz4, capstone, zbic; assert sys.version_info >= (3, 12); print('%d.%d' % sys.version_info[:2])"])
            : (status: Int32(1), out: "")
        let venvOK = venvCheck.status == 0
        add("venv", "HookLink's Python packages", venvOK ? .ok : .missing,
            venvOK ? "Ready (Python \(venvCheck.out.trimmingCharacters(in: .whitespacesAndNewlines)))" : "Click Install tools below.")

        let engOK = FileManager.default.fileExists(atPath: engine.appendingPathComponent("scripts/build_ipa_from_nsp.py").path)
        add("engine", "Build engine (nxnative)", engOK ? .ok : .missing, engOK ? engine.path : "Click Install tools below to download it.")

        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let free = (try? folder.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]).volumeAvailableCapacityForImportantUsage) ?? 0
        let gb = Double(free) / 1e9
        add("disk", "Free disk space (80 GB needed)", gb >= 80 ? .ok : (gb >= 60 ? .warn : .missing), String(format: "%.0f GB free in %@", gb, folder.path))

        checks = cs
        await readEngineVersion()
    }
    var macReady: Bool { !checks.isEmpty && !checks.contains { $0.state == .missing } }

    /// A Python of 3.12 or newer: Homebrew's first, newest first, then whatever python3 is on PATH. nil when there is none.
    func findPython() async -> (path: String, version: String)? {
        var candidates = ["/opt/homebrew/bin/python3.14", "/opt/homebrew/bin/python3.13", "/opt/homebrew/bin/python3.12", "/opt/homebrew/bin/python3",
                          "/usr/local/bin/python3.13", "/usr/local/bin/python3.12", "/usr/local/bin/python3"]
        // python.org's installers and uv's managed Pythons, newest first
        let fm = FileManager.default
        let fw = "/Library/Frameworks/Python.framework/Versions"
        for v in ((try? fm.contentsOfDirectory(atPath: fw)) ?? []).sorted(by: >) { candidates.append("\(fw)/\(v)/bin/python3") }
        let uv = NSHomeDirectory() + "/.local/share/uv/python"
        for v in ((try? fm.contentsOfDirectory(atPath: uv)) ?? []).filter({ $0.hasPrefix("cpython-3") }).sorted(by: >) { candidates.append("\(uv)/\(v)/bin/python3") }
        candidates.append("python3")
        for c in candidates {
            if c.hasPrefix("/") && !FileManager.default.isExecutableFile(atPath: c) { continue }
            let r = await Runner.capture([c, "-c", "import sys; print('%d.%d' % sys.version_info[:2])"])
            let v = r.out.trimmingCharacters(in: .whitespacesAndNewlines)
            let parts = v.split(separator: ".").compactMap { Int($0) }
            if r.status == 0, parts.count == 2, parts[0] == 3, parts[1] >= 12 { return (c, "Python " + v) }
        }
        return nil
    }

    /// PATH for the build and the phone copy: HookLink's Python first, so every tool the engine starts with python3 gets the packages
    var toolEnv: [String: String] { ["PATH": support.appendingPathComponent("venv/bin").path + ":" + Runner.path] }

    /// Installs what the checks found missing. Homebrew and Xcode themselves are the player's to install.
    func installTools() async {
        busy = true; defer { busy = false; endWork() }
        let r = Runner(); runner = r
        let missing = Set(checks.filter { $0.state == .missing }.map(\.id))
        beginWork("Installing tools", steps: 5)
        workStep(1, "Metal toolchain")
        if missing.contains("metal") {
            say("$ xcodebuild -downloadComponent MetalToolchain")
            await r.run(["xcodebuild", "-downloadComponent", "MetalToolchain"]) { self.say($0) }
        }
        workStep(2, "Homebrew tools")
        if missing.contains("tools") || missing.contains("python") {
            say("$ brew install xcodegen zstd glslang python@3.13")
            await r.run(["brew", "install", "xcodegen", "zstd", "glslang", "python@3.13"]) { self.say($0) }
        }
        workStep(3, "Python environment")
        // An environment on an old Python (an earlier HookLink used macOS's 3.9) is made again
        if FileManager.default.fileExists(atPath: venvPython.path),
           (await Runner.capture([venvPython.path, "-c", "import sys; assert sys.version_info >= (3, 12)"])).status != 0 {
            say("HookLink's Python environment is on an old Python: making it again")
            try? FileManager.default.removeItem(at: support.appendingPathComponent("venv"))
        }
        if !FileManager.default.fileExists(atPath: venvPython.path) {
            guard let py = await findPython() else { say("No Python 3.12 or newer was found, so HookLink's packages cannot be installed. Check that Homebrew installed python@3.13."); await runChecks(); return }
            say("$ \(py.path) -m venv \(support.appendingPathComponent("venv").path)")
            await r.run([py.path, "-m", "venv", support.appendingPathComponent("venv").path]) { self.say($0) }
        }
        workStep(4, "Python packages")
        say("$ pip install (the build's Python packages)")
        await r.run([venvPython.path, "-m", "pip", "install", "--upgrade", "lz4", "capstone>=5,<6", "fonttools", "nsz", "zbic",
                     "backports.zstd; python_version < '3.14'"]) { self.say($0) }
        workStep(5, "Build engine")
        if !FileManager.default.fileExists(atPath: engine.appendingPathComponent("scripts/build_ipa_from_nsp.py").path) {
            let cfg = Engine.load(from: resources)
            if cfg.repo.isEmpty {
                say("The build engine's download address is not set in this copy of HookLink. Set the engine folder in Settings.")
            } else {
                // With progress, and a watchdog: a download that receives nothing for 60 s is stopped and tried again, up to 3 times
                // (one on the tested Mac stalled at 13 MB of 660 MB for minutes, where the same command took 15 s from a terminal)
                for attempt in 1...3 {
                    try? FileManager.default.removeItem(at: engine)
                    say("$ git clone --depth 1 -b \(cfg.branch) \(cfg.repo)" + (attempt > 1 ? "   (try \(attempt) of 3)" : ""))
                    workStep(5, attempt == 1 ? "Downloading the build engine" : "Downloading the build engine (try \(attempt) of 3)", fraction: 0)
                    let clone = Runner(); runner = clone
                    var last = Date(), stalled = false
                    let watchdog = Task { @MainActor in
                        while !Task.isCancelled {
                            try? await Task.sleep(for: .seconds(5))
                            if Date().timeIntervalSince(last) > 60 { stalled = true; clone.cancel(); break }
                        }
                    }
                    let st = await clone.run(["git", "clone", "--progress", "--depth", "1", "-b", cfg.branch, cfg.repo, engine.path]) { line in
                        last = Date()
                        // "Receiving objects:  45% (1234/2742), 120.00 MiB | 30.00 MiB/s"
                        if let r = line.range(of: #"Receiving objects:\s+(\d+)%"#, options: .regularExpression) {
                            let pct = line[r].split(separator: " ").last.map { String($0.dropLast()) }.flatMap { Double($0) }
                            if let pct { self.workFraction(pct / 100) }
                            self.workDetail(line)
                        } else { self.say(line) }
                    }
                    watchdog.cancel()
                    if st == 0 { break }
                    say(stalled ? "The download stopped receiving data for a minute: trying again." : "The download failed (status \(st)): trying again.")
                    if attempt == 3 { say("The build engine couldn't be downloaded. Check your internet connection and click Install tools again.") }
                }
            }
        }
        await runChecks()
    }

    // MARK: Step 2: the game

    func chooseGame(_ url: URL) {
        nupPath = url.path
    }
    var gameChosen: Bool { !nupPath.isEmpty && FileManager.default.fileExists(atPath: nupPath) }

    // MARK: Step 4: build

    func build() async {
        busy = true; buildOK = false; buildError = ""; damagedFiles = []; smallFilesChecked = false; defer { busy = false; endWork() }
        beginWork("Building the iPhone app", steps: 6)
        try? FileManager.default.createDirectory(at: workDir, withIntermediateDirectories: true)
        var args = [venvPython.path, "-I", engine.appendingPathComponent("scripts/build_ipa_from_nsp.py").path, nupPath,
                    "--platform", "ios", "--romfs", "separate", "--allow-damaged", "--gpu", gpu,
                    "--env-file", resources.appendingPathComponent("presets/iphone.env").path,
                    "--work-dir", workDir.path, "-o", ipa.path, "--progress", "json"]
        let name = appName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty { args += ["--app-name", name] }
        if !appIcon.isEmpty, FileManager.default.fileExists(atPath: appIcon) { args += ["--icon", appIcon] }
        say("$ " + args.joined(separator: " "))
        let r = Runner(); runner = r
        var collectingDamaged = false
        let status = await r.run(args, cwd: engine, env: toolEnv.merging(["DM_ENTITLEMENTS": resources.appendingPathComponent("presets/entitlements.plist").path]) { a, _ in a }) { line in
            guard let data = line.data(using: .utf8), let ev = try? JSONSerialization.jsonObject(with: data) as? [String: Any], let kind = ev["ev"] as? String else {
                self.say(line)
                if collectingDamaged, line.hasPrefix("  ") { self.damagedFiles.append(line.trimmingCharacters(in: .whitespaces)) } else { collectingDamaged = false }
                return
            }
            switch kind {
            case "stage":
                self.stageIndex = ev["k"] as? Int ?? self.stageIndex
                self.stageCount = ev["n"] as? Int ?? self.stageCount
                self.stageName = ev["name"] as? String ?? ""
                self.stageFraction = nil; self.stageETA = ""
                self.work?.stepCount = self.stageCount; self.workStep(self.stageIndex, self.stageName)
                // The update the game is at, from the first stage's name ("unpack v131072"): any other update stops the build
                if self.stageName.hasPrefix("unpack v"), let upd = self.stageName.split(separator: " ").last.map(String.init), upd != Game.version {
                    self.buildError = "This game is at update \(upd). HookLink supports only update \(Game.version). Update the game on your Switch 2, dump it again, and try again."
                    r.cancel()
                }
                self.say("[\(self.stageIndex)/\(self.stageCount)] \(self.stageName)")
            case "progress":
                self.stageFraction = ev["frac"] as? Double
                if let eta = ev["eta"] as? Double { self.stageETA = HookLink.hms(eta) } else { self.stageETA = "" }
                self.workFraction(self.stageFraction, eta: self.stageETA)
                if let note = ev["note"] as? String, !note.isEmpty { self.workDetail(note) }
                else if let d = ev["done"] as? Int, let t = ev["total"] as? Int { self.workDetail("\(d) of \(t) \(ev["unit"] as? String ?? "")") }
            case "stage_end":
                let ok = ev["ok"] as? Bool ?? true
                self.say("\(ok ? "✓" : "✗") \(ev["name"] as? String ?? ""): \(ev["summary"] as? String ?? "")")
            case "say":
                let msg = ev["msg"] as? String ?? ""
                self.say(msg)
                if msg.contains("whose bytes do not start as their names promise") {
                    collectingDamaged = true
                    self.damagedFiles = msg.split(separator: "\n").dropFirst().map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty && !$0.hasPrefix("packed") }
                }
            case "game":
                let text = String(decoding: data, as: UTF8.self)
                // Only the title here: this event's "version" is the display version ("1.0"), not the update; the update is checked at the unpack stage below
                let title = (ev["title_id"] as? String ?? text).uppercased()
                if !title.contains(Game.titleID) {
                    self.buildError = "This is not Ocarina of Time (Nintendo Switch 2 Edition, \(Game.titleID)). HookLink builds only that game."
                    r.cancel()
                }
            default: self.say(line)
            }
        }
        if status != 0, buildError.isEmpty, let hint = HookLink.plainError(log.suffix(200)) { buildError = hint }
        if status == 0 && FileManager.default.fileExists(atPath: ipa.path) {
            buildOK = true; stageFraction = 1; say("Done: \(ipa.path)")
        } else if buildError.isEmpty {
            buildError = "The build stopped (status \(status)). The last lines of the log say why."
        }
    }

    // MARK: Step 6: the phone

    func findDevices() async {
        busy = true; defer { busy = false }
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("hooklink-devices.json")
        _ = await Runner.capture(["xcrun", "devicectl", "list", "devices", "--json-output", tmp.path])
        var found: [Device] = []
        if let data = try? Data(contentsOf: tmp), let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let result = root["result"] as? [String: Any], let list = result["devices"] as? [[String: Any]] {
            for d in list {
                let hw = d["hardwareProperties"] as? [String: Any] ?? [:]
                let dp = d["deviceProperties"] as? [String: Any] ?? [:]
                let cp = d["connectionProperties"] as? [String: Any] ?? [:]
                guard (hw["platform"] as? String) == "iOS" else { continue }
                if let tunnel = cp["tunnelState"] as? String, tunnel == "unavailable" { continue }
                found.append(Device(id: d["identifier"] as? String ?? "", name: dp["name"] as? String ?? "iPhone",
                                    model: hw["marketingName"] as? String ?? (hw["productType"] as? String ?? ""),
                                    developerMode: (dp["developerModeStatus"] as? String) == "enabled"))
            }
        }
        devices = found
        if device == nil || !found.contains(where: { $0.id == device?.id }) { device = found.first }
        if let d = device { await findApp(on: d) }
    }

    /// The installed HookLink game's bundle ID: sideloading tools add their own suffix to it.
    func findApp(on d: Device) async {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("hooklink-apps.json")
        _ = await Runner.capture(["xcrun", "devicectl", "device", "info", "apps", "--device", d.id, "--json-output", tmp.path])
        bundleID = ""
        if let data = try? Data(contentsOf: tmp), let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let result = root["result"] as? [String: Any], let apps = result["apps"] as? [[String: Any]] {
            for a in apps { if let b = a["bundleIdentifier"] as? String, b.lowercased().hasPrefix(Game.bundlePrefix) { bundleID = b; break } }
        }
    }

    /// Copies the game files and the resolution file to the phone, then checks them. viaFinder: the player copied the game files
    /// with Finder (see prepareFinderCopy), so this checks they arrived whole instead of copying them, and goes on with the rest.
    /// devicectl's single 24 GB copy dropped part way on the tested iPhone (about 2.5 minutes in, even awake on a new cable); after
    /// two tries HookLink offers the Finder way, which uses another transfer service and the app's file sharing.
    func copyToPhone(viaFinder: Bool = false) async {
        guard let d = device, !bundleID.isEmpty else { return }
        busy = true; copyOK = false; copyStatus = []; defer { busy = false; endWork() }
        beginWork("Copying to your iPhone", steps: 3)
        let r = Runner(); runner = r
        // devicectl device copy to|from, into the game's own Documents folder on the phone
        func dc(_ way: String, _ rest: [String]) -> [String] {
            ["xcrun", "devicectl", "device", "copy", way, "--device", d.id, "--domain-type", "appDataContainer", "--domain-identifier", bundleID] + rest
        }
        let bytes = Int64((try? romfsImage.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        // The phone's saves first, if it has any: the copy writes only game files, but a save is too precious to risk
        if let b = await backupSaves("before copying game files", quiet: true) { copyStatus.append("✓ Your saves were backed up first (\(b.lastPathComponent))") }

        if viaFinder {
            workStep(1, "Checking the game files you copied with Finder")
            let onPhone = await phoneFileSize(d, "romfs.img")
            guard let onPhone, onPhone == bytes, bytes > 0 else {
                copyStatus.append(onPhone == nil
                    ? "✗ romfs.img isn't on the phone yet. Drag it onto the game in Finder's Files tab, wait for Finder to finish, then click Check again."
                    : "✗ romfs.img on the phone is \(HookLink.gb(onPhone ?? 0)), not \(HookLink.gb(bytes)): Finder hasn't finished, or the copy stopped. Wait for Finder's progress to finish (or drag it again and choose Replace), then click Check again.")
                return
            }
            copyStatus.append("✓ Game files are on your iPhone (\(HookLink.gb(bytes)))")
            finderMode = false
        } else {
            copyStatus.append("Copying the game files (about 24 GB). This takes 10 to 20 minutes…")
            var push: Int32 = -1
            for attempt in 1...2 {
                // devicectl reports no progress: estimate it from the image's size at about 35 MB/s (measured over a cable), capped at 95% until done
                workStep(1, attempt == 1 ? "Game files" : "Game files (trying again)", fraction: 0, estimated: true)
                let expect = max(60, Double(bytes) / 35_000_000), t0 = Date()
                let ticker = Task { @MainActor in
                    while !Task.isCancelled {
                        let el = Date().timeIntervalSince(t0)
                        self.workFraction(min(0.95, el / expect), eta: HookLink.hms(max(0, expect - el)))
                        try? await Task.sleep(for: .seconds(1))
                    }
                }
                push = await r.run(["bash", engine.appendingPathComponent("scripts/push_romfs.sh").path, d.id, bundleID, romfsImage.path], cwd: engine, env: toolEnv) { self.say($0) }
                ticker.cancel()
                if push == 0 { break }
                if attempt == 1 { copyStatus.append("The copy stopped part way. Trying once more…") }
            }
            guard push == 0 else {
                copyStatus.append("✗ The game files didn't copy over the cable. Use Copy with Finder instead, below: it uses another way to reach the phone.")
                finderMode = true
                return
            }
            workFraction(1)
            copyStatus.append("✓ Game files copied")
        }

        workStep(2, "Resolution file")
        copyStatus.append("Making the iPhone resolution file from your game…")
        try? FileManager.default.createDirectory(at: overlayFile.deletingLastPathComponent(), withIntermediateDirectories: true)
        let res = await r.run([venvPython.path, "-I", resources.appendingPathComponent("tools/hl_resolution.py").path, engine.path, romfsImage.path, overlayFile.path]) { self.say($0) }
        guard res == 0 else { copyStatus.append("✗ The resolution file could not be made."); return }
        let up = await r.run(dc("to", ["--source", overlayFile.path, "--destination", "Documents/res_overlay/Pack/Bootup.Nin_Ounce_NVN2.pack.zs"])) { self.say($0) }
        guard up == 0 else { copyStatus.append("✗ The resolution file did not copy."); return }

        workStep(3, "Checking")
        // Check: read it back and compare; and the game files' size once more
        let back = FileManager.default.temporaryDirectory.appendingPathComponent("hooklink-check.pack.zs")
        try? FileManager.default.removeItem(at: back)
        _ = await r.run(dc("from", ["--source", "Documents/res_overlay/Pack/Bootup.Nin_Ounce_NVN2.pack.zs", "--destination", back.path])) { self.say($0) }
        let same = (try? Data(contentsOf: back)) == (try? Data(contentsOf: overlayFile))
        copyStatus.append(same ? "✓ Resolution file copied and checked" : "✗ The resolution file on the phone does not match. Try again.")
        let romOK = await phoneFileSize(d, "romfs.img") == bytes
        if !romOK { copyStatus.append("✗ The game files on the phone aren't complete. Copy them again.") }
        if !damagedFiles.isEmpty {
            copyStatus.append("⚠ Your dump has \(damagedFiles.count) damaged file(s). The game may show a missing texture there; dumping the game again fixes it.")
        }
        copyOK = same && romOK
    }

    /// The Finder way: the game files under the name the game reads (romfs.img, as a hard link: no extra disk space), shown in Finder
    @Published var finderMode = false
    @Published var finderFile: URL? = nil
    func prepareFinderCopy() {
        finderMode = true
        let dir = folder.appendingPathComponent("copy-to-phone"), link = dir.appendingPathComponent("romfs.img")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try? FileManager.default.removeItem(at: link)
        do { try FileManager.default.linkItem(at: romfsImage, to: link) }
        catch {   // another drive: a hard link can't cross volumes, so copy it (needs the space)
            do { try FileManager.default.copyItem(at: romfsImage, to: link) }
            catch { copyStatus = ["✗ Couldn't prepare the file for Finder: \(error.localizedDescription)"]; return }
        }
        finderFile = link
        NSWorkspace.shared.activateFileViewerSelecting([link])
    }

    /// The size of a file in the game's Documents folder on the phone, or nil when it isn't there
    /// Brings the small game files on the phone up to date without touching the 24 GB image: makes them for the current engine, compares, and sends only what differs.
    /// auto: the Play step's own check after a build; it says nothing when the phone isn't there.
    @Published var smallFilesStatus = ""
    var smallFilesChecked = false
    func updateSmallFiles(auto: Bool = false) async {
        if busy || (auto && smallFilesChecked) { return }
        if device == nil || bundleID.isEmpty { await findDevices() }
        guard let d = device, !bundleID.isEmpty else { if !auto { smallFilesStatus = "Plug in your iPhone with the game installed, unlock it, and try again." }; return }
        guard FileManager.default.fileExists(atPath: romfsImage.path) else { if !auto { smallFilesStatus = "HookLink needs your game files on this Mac to make these. Build the app again first." }; return }
        smallFilesChecked = true; busy = true; defer { busy = false; endWork() }
        beginWork("Updating the small game files", steps: 3)
        let remote = "Documents/res_overlay/Pack/Bootup.Nin_Ounce_NVN2.pack.zs"
        func dc(_ way: String, _ source: String, _ destination: String) -> [String] {
            ["xcrun", "devicectl", "device", "copy", way, "--device", d.id, "--domain-type", "appDataContainer", "--domain-identifier", bundleID, "--source", source, "--destination", destination]
        }
        let r = Runner(); runner = r
        workStep(0, "Making them from your game")
        try? FileManager.default.createDirectory(at: overlayFile.deletingLastPathComponent(), withIntermediateDirectories: true)
        guard await r.run([venvPython.path, "-I", resources.appendingPathComponent("tools/hl_resolution.py").path, engine.path, romfsImage.path, overlayFile.path], onLine: { self.say($0) }) == 0 else { smallFilesStatus = "✗ The resolution file could not be made."; return }
        workStep(1, "Comparing with your iPhone")
        let back = FileManager.default.temporaryDirectory.appendingPathComponent("hooklink-small.pack.zs")
        try? FileManager.default.removeItem(at: back)
        _ = await r.run(dc("from", remote, back.path), onLine: { self.say($0) })
        let wanted = try? Data(contentsOf: overlayFile)
        if wanted != nil, (try? Data(contentsOf: back)) == wanted { smallFilesStatus = "✓ Small game files are up to date."; return }
        workStep(2, "Copying what changed")
        guard await r.run(dc("to", overlayFile.path, remote), onLine: { self.say($0) }) == 0 else { smallFilesStatus = "✗ The small game files did not copy. Keep the phone unlocked and try again."; return }
        try? FileManager.default.removeItem(at: back)
        _ = await r.run(dc("from", remote, back.path), onLine: { self.say($0) })
        smallFilesStatus = wanted != nil && (try? Data(contentsOf: back)) == wanted ? "✓ Small game files updated." : "✗ The file on your iPhone doesn't match. Try again."
    }

    func phoneFileSize(_ d: Device, _ name: String) async -> Int64? {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("hooklink-files.json")
        try? FileManager.default.removeItem(at: tmp)
        _ = await Runner.capture(["xcrun", "devicectl", "device", "info", "files", "--device", d.id, "--domain-type", "appDataContainer",
                                  "--domain-identifier", bundleID, "--subdirectory", "Documents", "--json-output", tmp.path])
        guard let data = try? Data(contentsOf: tmp), let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let files = (root["result"] as? [String: Any])?["files"] as? [[String: Any]] else { return nil }
        for f in files where (f["relativePath"] as? String) == name || (f["name"] as? String) == name {
            if let m = f["metadata"] as? [String: Any], let n = m["size"] as? NSNumber { return n.int64Value }
        }
        return nil
    }

    /// Known build failures, said plainly: the last lines of the build's output → what to do
    static func plainError<S: Sequence>(_ lines: S) -> String? where S.Element == String {
        let text = lines.joined(separator: "\n").lowercased()
        if text.contains("metal") && (text.contains("compiler") || text.contains("toolchain")) && (text.contains("differs") || text.contains("lock") || text.contains("another") || text.contains("not found") || text.contains("version")) {
            return "The build needs Xcode 27.2's Metal compiler, and this Mac has a different one. Install Xcode 27.2 from developer.apple.com (you can keep other versions), then in Terminal run: sudo xcode-select -s /Applications/Xcode.app (or the 27.2 app's name), open Xcode once, and build again."
        }
        if text.contains("no space left") || text.contains("disk is full") || text.contains("not enough space") {
            return "The disk ran out of space. Free up space (the build needs about 80 GB; see Disk space in the README), then build again: finished parts are kept."
        }
        if text.contains("xcodegen") && text.contains("not found") { return "A build tool is missing. Go back to Check your Mac and click Install tools." }
        return nil
    }

    static func gb(_ b: Int64) -> String { String(format: "%.2f GB", Double(b) / 1e9) }

    /// Copies the game's log (and the previous run's) from the phone to the Desktop, for a bug report. The log holds no game data.
    @Published var logStatus = ""
    func fetchLog() async {
        if device == nil || bundleID.isEmpty { await findDevices() }
        guard let d = device, !bundleID.isEmpty else { logStatus = "Plug in your iPhone with the game installed, unlock it, and try again."; return }
        busy = true; defer { busy = false; endWork() }
        beginWork("Getting the game log"); workStep(0, "Copying from your iPhone")
        let desk = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask)[0]
        var got: [URL] = []
        for (src, name) in [("Documents/log.txt", "HookLink-log.txt"), ("Documents/log.prev.txt", "HookLink-log-previous.txt")] {
            let dst = desk.appendingPathComponent(name); try? FileManager.default.removeItem(at: dst)
            let st = await Runner().run(["xcrun", "devicectl", "device", "copy", "from", "--device", d.id, "--domain-type", "appDataContainer",
                                         "--domain-identifier", bundleID, "--source", src, "--destination", dst.path]) { self.say($0) }
            if st == 0, FileManager.default.fileExists(atPath: dst.path) { got.append(dst) }
        }
        if got.isEmpty { logStatus = "No log yet: open the game once, then try again." }
        else { logStatus = "Saved \(got.map(\.lastPathComponent).joined(separator: " and ")) on your Desktop. Attach it to your issue."; NSWorkspace.shared.activateFileViewerSelecting(got) }
    }

    /// Saves the phone's pipeline list (Documents/pso_user.tsv) on the Desktop for sharing, and opens the GitHub form for it.
    /// The list holds shader identifiers and drawing settings only (what nxnative ships in its own lists), never game files.
    /// Only S, R and C rows are kept, so nothing else from the file can leave the Mac.
    @Published var shareStatus = ""
    func sharePipelines() async {
        if device == nil || bundleID.isEmpty { await findDevices() }
        guard let d = device, !bundleID.isEmpty else { shareStatus = "Plug in your iPhone with the game installed, unlock it, and try again."; return }
        busy = true; defer { busy = false; endWork() }
        beginWork("Saving your pipeline list"); workStep(0, "Copying from your iPhone")
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("hooklink-pso_user.tsv")
        try? FileManager.default.removeItem(at: tmp)
        _ = await Runner().run(["xcrun", "devicectl", "device", "copy", "from", "--device", d.id, "--domain-type", "appDataContainer",
                                "--domain-identifier", bundleID, "--source", "Documents/pso_user.tsv", "--destination", tmp.path]) { self.say($0) }
        guard let text = try? String(contentsOf: tmp, encoding: .utf8) else { shareStatus = "No pipeline list yet: play the game for a while first, then try again."; return }
        let rows = text.split(separator: "\n").filter { l in l.count > 2 && "SRC".contains(l.first!) && l.dropFirst().first == "\t" }
        guard !rows.isEmpty else { shareStatus = "No pipeline list yet: play the game for a while first, then try again."; return }
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        let out = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask)[0].appendingPathComponent("HookLink-pipelines-\(f.string(from: Date())).txt")
        let header = "# HookLink pipeline list: \(d.model), HookLink \(AppInfo.version), \(Game.titleID) \(Game.version)\n"
        do { try (header + rows.joined(separator: "\n") + "\n").write(to: out, atomically: true, encoding: .utf8) }
        catch { shareStatus = "Could not save the list: \(error.localizedDescription)"; return }
        shareStatus = "Saved \(out.lastPathComponent) on your Desktop (\(rows.count) entries). Attach it to the form that just opened. Thank you!"
        NSWorkspace.shared.activateFileViewerSelecting([out])
        if let u = URL(string: "https://github.com/\(AppInfo.repo)/issues/new?template=pipeline-list.yml") { NSWorkspace.shared.open(u) }
    }

    func cancel() { runner?.cancel() }

    static func hms(_ s: Double) -> String {
        let t = Int(s.rounded()); return t >= 3600 ? String(format: "%d:%02d:%02d", t / 3600, t / 60 % 60, t % 60) : String(format: "%d:%02d", t / 60, t % 60)
    }
}

/// Where the build engine (nxnative with HookLink's changes) is downloaded from: Resources/engine.json.
struct Engine: Decodable {
    var repo: String
    var branch: String
    static func load(from resources: URL) -> Engine {
        let u = resources.appendingPathComponent("engine.json")
        if let d = try? Data(contentsOf: u), let e = try? JSONDecoder().decode(Engine.self, from: d) { return e }
        return Engine(repo: "", branch: "main")
    }
}
