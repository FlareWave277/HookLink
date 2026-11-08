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
        PhoneModel(id: "g19p", name: "iPhone 18 Pro / 18 Pro Max (A20 Pro)", tested: true),
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
        return URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Resources")
    }

    func say(_ s: String) { log.append(s); if log.count > 4000 { log.removeFirst(log.count - 4000) } }

    // MARK: Step 1: the Mac

    func runChecks() async {
        busy = true; defer { busy = false }
        var cs: [Check] = []
        func add(_ id: String, _ name: String, _ state: Check.State, _ detail: String) { cs.append(Check(id: id, name: name, state: state, detail: detail)) }

        let xc = await Runner.capture(["xcodebuild", "-version"])
        let xcVer = xc.out.split(separator: "\n").first.map(String.init) ?? ""
        add("xcode", "Xcode", xc.status == 0 ? (xcVer.contains("27.") ? .ok : .warn) : .missing,
            xc.status == 0 ? "\(xcVer) (27.2 is the tested version)" : "Install Xcode 27.2 from developer.apple.com, open it once, then add the iOS platform in Settings → Components.")

        let mt = await Runner.capture(["xcrun", "-sdk", "iphoneos", "metal", "--version"])
        add("metal", "Metal toolchain", mt.status == 0 ? .ok : .missing, mt.status == 0 ? "Installed" : "Click Install tools below (runs: xcodebuild -downloadComponent MetalToolchain).")

        let brew = await Runner.capture(["brew", "--version"])
        add("brew", "Homebrew", brew.status == 0 ? .ok : .missing, brew.status == 0 ? (brew.out.split(separator: "\n").first.map(String.init) ?? "") : "Install it from brew.sh (one command in Terminal), then check again.")

        let py = await Runner.capture(["python3", "-c", "import sys; print('%d.%d' % sys.version_info[:2])"])
        let pyOK = py.status == 0 && (Double(py.out.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0) >= 3.12
        add("python", "Python 3.12 or newer", pyOK ? .ok : .missing, pyOK ? "Python \(py.out.trimmingCharacters(in: .whitespacesAndNewlines))" : "Click Install tools below (Homebrew's python).")

        var tools: [String] = []
        for t in ["xcodegen", "zstd", "glslangValidator"] { if (await Runner.capture(["which", t])).status != 0 { tools.append(t) } }
        add("tools", "Build tools (xcodegen, zstd, glslang)", tools.isEmpty ? .ok : .missing, tools.isEmpty ? "Installed" : "Missing: \(tools.joined(separator: ", ")). Click Install tools below.")

        let venvOK = FileManager.default.fileExists(atPath: venvPython.path)
        add("venv", "HookLink's Python packages", venvOK ? .ok : .missing, venvOK ? "Ready" : "Click Install tools below.")

        let engOK = FileManager.default.fileExists(atPath: engine.appendingPathComponent("scripts/build_ipa_from_nsp.py").path)
        add("engine", "Build engine (nxnative)", engOK ? .ok : .missing, engOK ? engine.path : "Click Install tools below to download it.")

        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let free = (try? folder.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]).volumeAvailableCapacityForImportantUsage) ?? 0
        let gb = Double(free) / 1e9
        add("disk", "Free disk space (80 GB needed)", gb >= 80 ? .ok : (gb >= 60 ? .warn : .missing), String(format: "%.0f GB free in %@", gb, folder.path))

        checks = cs
    }
    var macReady: Bool { !checks.isEmpty && !checks.contains { $0.state == .missing } }

    /// Installs what the checks found missing. Homebrew and Xcode themselves are the player's to install.
    func installTools() async {
        busy = true; defer { busy = false }
        let r = Runner(); runner = r
        let missing = Set(checks.filter { $0.state == .missing }.map(\.id))
        if missing.contains("metal") {
            say("$ xcodebuild -downloadComponent MetalToolchain")
            await r.run(["xcodebuild", "-downloadComponent", "MetalToolchain"]) { self.say($0) }
        }
        if missing.contains("tools") || missing.contains("python") {
            say("$ brew install xcodegen zstd glslang python@3.13")
            await r.run(["brew", "install", "xcodegen", "zstd", "glslang", "python@3.13"]) { self.say($0) }
        }
        if !FileManager.default.fileExists(atPath: venvPython.path) {
            say("$ python3 -m venv \(support.appendingPathComponent("venv").path)")
            await r.run(["python3", "-m", "venv", support.appendingPathComponent("venv").path]) { self.say($0) }
        }
        say("$ pip install (the build's Python packages)")
        await r.run([venvPython.path, "-m", "pip", "install", "--upgrade", "lz4", "capstone>=5,<6", "fonttools", "nsz", "zbic",
                     "backports.zstd; python_version < '3.14'"]) { self.say($0) }
        if !FileManager.default.fileExists(atPath: engine.appendingPathComponent("scripts/build_ipa_from_nsp.py").path) {
            let cfg = Engine.load(from: resources)
            if cfg.repo.isEmpty {
                say("The build engine's download address is not set in this copy of HookLink. Set the engine folder in Settings.")
            } else {
                say("$ git clone --depth 1 -b \(cfg.branch) \(cfg.repo)")
                await r.run(["git", "clone", "--depth", "1", "-b", cfg.branch, cfg.repo, engine.path]) { self.say($0) }
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
        busy = true; buildOK = false; buildError = ""; damagedFiles = []; defer { busy = false }
        try? FileManager.default.createDirectory(at: workDir, withIntermediateDirectories: true)
        let args = [venvPython.path, "-I", engine.appendingPathComponent("scripts/build_ipa_from_nsp.py").path, nupPath,
                    "--platform", "ios", "--romfs", "separate", "--allow-damaged", "--gpu", gpu,
                    "--env-file", resources.appendingPathComponent("presets/iphone.env").path,
                    "--work-dir", workDir.path, "-o", ipa.path, "--progress", "json"]
        say("$ " + args.joined(separator: " "))
        let r = Runner(); runner = r
        var collectingDamaged = false
        let status = await r.run(args, cwd: engine, env: ["DM_ENTITLEMENTS": resources.appendingPathComponent("presets/entitlements.plist").path]) { line in
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
                self.say("[\(self.stageIndex)/\(self.stageCount)] \(self.stageName)")
            case "progress":
                self.stageFraction = ev["frac"] as? Double
                if let eta = ev["eta"] as? Double { self.stageETA = HookLink.hms(eta) } else { self.stageETA = "" }
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
                if !text.uppercased().contains(Game.titleID) {
                    self.buildError = "This is not Ocarina of Time (Nintendo Switch 2 Edition, \(Game.titleID)). HookLink builds only that game."
                    r.cancel()
                }
            default: self.say(line)
            }
        }
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

    func copyToPhone() async {
        guard let d = device, !bundleID.isEmpty else { return }
        busy = true; copyOK = false; copyStatus = []; defer { busy = false }
        let r = Runner(); runner = r
        // devicectl device copy to|from, into the game's own Documents folder on the phone
        func dc(_ way: String, _ rest: [String]) -> [String] {
            ["xcrun", "devicectl", "device", "copy", way, "--device", d.id, "--domain-type", "appDataContainer", "--domain-identifier", bundleID] + rest
        }

        copyStatus.append("Copying the game files (about 24 GB). This takes 10 to 20 minutes…")
        let push = await r.run(["bash", engine.appendingPathComponent("scripts/push_romfs.sh").path, d.id, bundleID, romfsImage.path], cwd: engine) { self.say($0) }
        guard push == 0 else { copyStatus.append("✗ The game files did not copy. Check the cable and that the phone is unlocked, then try again."); return }
        copyStatus.append("✓ Game files copied")

        copyStatus.append("Making the iPhone resolution file from your game…")
        try? FileManager.default.createDirectory(at: overlayFile.deletingLastPathComponent(), withIntermediateDirectories: true)
        let res = await r.run([venvPython.path, "-I", resources.appendingPathComponent("tools/hl_resolution.py").path, engine.path, romfsImage.path, overlayFile.path]) { self.say($0) }
        guard res == 0 else { copyStatus.append("✗ The resolution file could not be made."); return }
        let up = await r.run(dc("to", ["--source", overlayFile.path, "--destination", "Documents/res_overlay/Pack/Bootup.Nin_Ounce_NVN2.pack.zs"])) { self.say($0) }
        guard up == 0 else { copyStatus.append("✗ The resolution file did not copy."); return }

        // Check: read it back and compare
        let back = FileManager.default.temporaryDirectory.appendingPathComponent("hooklink-check.pack.zs")
        try? FileManager.default.removeItem(at: back)
        _ = await r.run(dc("from", ["--source", "Documents/res_overlay/Pack/Bootup.Nin_Ounce_NVN2.pack.zs", "--destination", back.path])) { self.say($0) }
        let same = (try? Data(contentsOf: back)) == (try? Data(contentsOf: overlayFile))
        copyStatus.append(same ? "✓ Resolution file copied and checked" : "✗ The resolution file on the phone does not match. Try again.")
        if !damagedFiles.isEmpty {
            copyStatus.append("⚠ Your dump has \(damagedFiles.count) damaged file(s). The game may show a missing texture there; dumping the game again fixes it.")
        }
        copyOK = same
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
