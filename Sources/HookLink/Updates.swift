import Foundation
import SwiftUI

/// Updates: the build engine (nxnative with HookLink's changes, a branch of a GitHub fork) and HookLink itself (GitHub Releases).
///
/// The engine is a git checkout HookLink owns (in Application Support). An update fetches the configured branch and moves the
/// checkout to it with a hard reset, so it also works when the branch was rebuilt on a newer nxnative (a force-push). An engine
/// folder the player set themselves (Settings, or HOOKLINK_ENGINE) is never touched: it is theirs.
@MainActor
extension HookLink {
    /// Is the engine HookLink's own download (and so safe to update)?
    var engineIsManaged: Bool {
        ProcessInfo.processInfo.environment["HOOKLINK_ENGINE"].map { $0.isEmpty } ?? true && enginePathSetting.isEmpty
    }

    /// Looks for a newer engine and a newer HookLink. The version panel shows the outcome: up to date, an update, or that the check failed.
    func checkForUpdates() async {
        updateMessage = ""
        checkState = .checking
        await readEngineVersion()
        let engineOK = await checkEngine()
        let appOK = await checkApp()
        if engineOK && appOK { lastUpdateCheck = Date().timeIntervalSince1970; checkState = .done }
        else { checkState = .failed(appOK ? "Couldn't reach the engine's download address" : "Couldn't reach GitHub") }
    }

    /// The engine this Mac has: its commit and the commit's date, for the version panel
    func readEngineVersion() async {
        guard FileManager.default.fileExists(atPath: engine.appendingPathComponent(".git").path) else { engineVersion = nil; return }
        let r = await Runner.capture(["git", "-C", engine.path, "log", "-1", "--format=%h|%cs"])
        let parts = r.out.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: "|").map(String.init)
        engineVersion = r.status == 0 && parts.count == 2 ? EngineVersion(commit: parts[0], date: parts[1], managed: engineIsManaged) : nil
    }

    /// false when the engine's remote couldn't be reached (no network, GitHub down); true when checked, or nothing to check
    @discardableResult
    func checkEngine() async -> Bool {
        engineUpdate = nil
        guard engineIsManaged, FileManager.default.fileExists(atPath: engine.appendingPathComponent(".git").path) else { return true }
        let cfg = Engine.load(from: resources)
        guard !cfg.repo.isEmpty else { return true }
        let dir = engine.path
        // The remote and branch can change between HookLink versions: follow engine.json
        _ = await Runner.capture(["git", "-C", dir, "remote", "set-url", "origin", cfg.repo])
        let f = await Runner.capture(["git", "-C", dir, "fetch", "--quiet", "--depth", "50", "origin",
                                      "+refs/heads/\(cfg.branch):refs/remotes/origin/\(cfg.branch)"])
        guard f.status == 0 else { return false }
        let here = (await Runner.capture(["git", "-C", dir, "rev-parse", "HEAD"])).out.trimmingCharacters(in: .whitespacesAndNewlines)
        let there = (await Runner.capture(["git", "-C", dir, "rev-parse", "origin/\(cfg.branch)"])).out.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !there.isEmpty, here != there else { return true }
        // What's new: the commits the update brings (subjects only, newest first); a rebased branch shows its newest commits
        var log = (await Runner.capture(["git", "-C", dir, "log", "--format=%s", "-n", "15", "HEAD..origin/\(cfg.branch)"])).out
        if log.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            log = (await Runner.capture(["git", "-C", dir, "log", "--format=%s", "-n", "8", "origin/\(cfg.branch)"])).out
        }
        let items = log.split(separator: "\n").map { s -> String in
            let t = String(s); return t.count > 140 ? String(t.prefix(140)) + "…" : t
        }
        engineUpdate = EngineUpdate(commit: String(there.prefix(12)), changes: items)
        return true
    }

    /// false when GitHub couldn't be reached; true when checked
    @discardableResult
    func checkApp() async -> Bool {
        appUpdate = nil
        guard let url = URL(string: "https://api.github.com/repos/\(AppInfo.repo)/releases/latest") else { return true }
        var req = URLRequest(url: url); req.timeoutInterval = 10
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        guard let (data, resp) = try? await URLSession.shared.data(for: req), let code = (resp as? HTTPURLResponse)?.statusCode else { return false }
        guard code == 200, let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tag = obj["tag_name"] as? String else { return code == 404 }   // 404: no release yet, nothing newer
        let latest = tag.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
        if AppInfo.isNewer(latest, than: AppInfo.version) {
            appUpdate = AppUpdate(version: latest, page: (obj["html_url"] as? String) ?? "https://github.com/\(AppInfo.repo)/releases/latest")
        }
        return true
    }

    /// Moves the engine to the fetched branch. The player then builds again and installs the new IPA over the old one:
    /// saves, game files and the resolution file stay on the phone.
    func applyEngineUpdate() async {
        guard engineIsManaged, engineUpdate != nil else { return }
        busy = true; defer { busy = false; endWork() }
        beginWork("Updating the game engine"); workStep(0, "Moving to the new version")
        let cfg = Engine.load(from: resources)
        say("$ git reset --hard origin/\(cfg.branch)   (updating the build engine)")
        let st = await Runner().run(["git", "-C", engine.path, "reset", "--hard", "origin/\(cfg.branch)"]) { self.say($0) }
        if st == 0 {
            engineUpdate = nil
            await readEngineVersion()
            buildOK = false
            updateMessage = "The engine is updated. Build again, then install the new app over the old one: your saves and game files stay on your phone."
            step = .build
        } else {
            updateMessage = "The update did not apply. Click Show details for the reason, or try again later."
        }
    }
}

struct EngineUpdate: Equatable { let commit: String; let changes: [String] }
struct EngineVersion: Equatable { let commit: String; let date: String; let managed: Bool }
enum CheckState: Equatable { case never, checking, done, failed(String) }
struct AppUpdate: Equatable { let version: String; let page: String }

enum AppInfo {
    static let repo = "dsi-hub/HookLink"
    static var version: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0" }
    /// Compares dotted versions numerically: 0.10.0 is newer than 0.9.2
    static func isNewer(_ a: String, than b: String) -> Bool {
        let x = a.split(separator: ".").map { Int($0) ?? 0 }, y = b.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(x.count, y.count) {
            let p = i < x.count ? x[i] : 0, q = i < y.count ? y[i] : 0
            if p != q { return p > q }
        }
        return false
    }
}

/// The banner at the top of every page when an update is waiting.
struct UpdateBanner: View {
    @EnvironmentObject var app: HookLink
    @State private var showChanges = false
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let u = app.appUpdate {
                HStack {
                    Image(systemName: "arrow.down.app.fill").foregroundStyle(.blue)
                    Text("HookLink \(u.version) is out (you have \(AppInfo.version)).").bold()
                    Spacer()
                    Link("Download", destination: URL(string: u.page)!)
                }
            }
            if let e = app.engineUpdate {
                HStack {
                    Image(systemName: "sparkles").foregroundStyle(.orange)
                    Text("A game update is ready: performance and fixes.").bold()
                    Spacer()
                    Button(showChanges ? "Hide changes" : "What's new") { showChanges.toggle() }.buttonStyle(.link)
                    Button("Update and rebuild") { Task { await app.applyEngineUpdate() } }.buttonStyle(.borderedProminent).disabled(app.busy)
                }
                if showChanges {
                    VStack(alignment: .leading, spacing: 3) {
                        ForEach(e.changes, id: \.self) { Text("• " + $0).font(.callout).foregroundStyle(.secondary) }
                    }
                }
                Text("You rebuild on your Mac, then install the new app over the old one. Saves and game files stay on your phone.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if !app.updateMessage.isEmpty { Text(app.updateMessage).foregroundStyle(.secondary) }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.5))
    }
}


/// Always at the bottom of the sidebar: which HookLink and engine this Mac has, whether each is up to date, and when it was last checked
struct VersionPanel: View {
    @EnvironmentObject var app: HookLink
    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { ctx in
            VStack(alignment: .leading, spacing: 5) {
                row("HookLink \(AppInfo.version)", update: app.appUpdate.map { "\($0.version) available" }) {
                    if let u = app.appUpdate, let url = URL(string: u.page) { NSWorkspace.shared.open(url) }
                }
                if let e = app.engineVersion {
                    row("Engine \(e.commit) (\(e.date))" + (e.managed ? "" : ", your folder"), update: app.engineUpdate != nil ? "update available" : nil) {
                        app.updateMessage = ""   // the banner at the top has What's new and Update and rebuild
                    }
                } else {
                    Text("Engine: not downloaded yet").font(.caption).foregroundStyle(.secondary)
                }
                HStack(spacing: 6) {
                    switch app.checkState {
                    case .checking: ProgressView().controlSize(.mini); Text("Checking…")
                    case .failed(let why): Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange); Text(why).lineLimit(2)
                    default:
                        Text(app.lastUpdateCheck > 0 ? "Checked " + HookLink.ago(ctx.date.timeIntervalSince1970 - app.lastUpdateCheck) : "Not checked yet")
                    }
                    Spacer(minLength: 0)
                    Button("Check now") { Task { await app.checkForUpdates() } }.buttonStyle(.link).disabled(app.checkState == .checking)
                }.font(.caption).foregroundStyle(.secondary)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
            .padding(8)
        }
    }

    @ViewBuilder func row(_ name: String, update: String?, open: @escaping () -> Void) -> some View {
        HStack(spacing: 6) {
            Image(systemName: update == nil ? "checkmark.circle.fill" : "arrow.down.circle.fill").foregroundStyle(update == nil ? .green : .orange)
            VStack(alignment: .leading, spacing: 1) {
                Text(name).font(.caption.bold())
                if let u = update { Button(u, action: open).buttonStyle(.link).font(.caption) }
                else { Text("Up to date").font(.caption).foregroundStyle(.secondary) }
            }
        }
    }
}

extension HookLink {
    static func ago(_ s: Double) -> String {
        if s < 60 { return "just now" }
        if s < 3600 { let m = Int(s / 60); return "\(m) minute\(m == 1 ? "" : "s") ago" }
        if s < 86400 { let h = Int(s / 3600); return "\(h) hour\(h == 1 ? "" : "s") ago" }
        let d = Int(s / 86400); return "\(d) day\(d == 1 ? "" : "s") ago"
    }
}
