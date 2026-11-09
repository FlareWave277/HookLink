import Foundation
import SwiftUI

/// Save backups: the game's saves live only on the phone (Documents/save in the game's own folder). HookLink copies them to
/// ~/Documents/HookLink Save Backups/<date> <why>/save on the Mac: on request, before copying game files, and before a restore.
/// A restore writes one file at a time (never a whole-folder replace, which can wipe the game's folder) and reads each back to check it.
@MainActor
extension HookLink {
    var saveBackupsDir: URL {
        let u = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("HookLink Save Backups")
        try? FileManager.default.createDirectory(at: u, withIntermediateDirectories: true)
        return u
    }

    /// Backups, newest first
    var saveBackups: [URL] {
        ((try? FileManager.default.contentsOfDirectory(at: saveBackupsDir, includingPropertiesForKeys: [.creationDateKey])) ?? [])
            .filter { FileManager.default.fileExists(atPath: $0.appendingPathComponent("save").path) }
            .sorted { $0.lastPathComponent > $1.lastPathComponent }
    }

    /// Copies the phone's saves to a new dated backup. Returns the backup folder, or nil (no phone, no game, or no saves yet)
    @discardableResult
    func backupSaves(_ why: String, quiet: Bool = false) async -> URL? {
        if device == nil || bundleID.isEmpty { await findDevices() }
        guard let d = device, !bundleID.isEmpty else { if !quiet { saveStatus = "Plug in your iPhone with the game installed, unlock it, and try again." }; return nil }
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd HH.mm.ss"
        let dir = saveBackupsDir.appendingPathComponent("\(f.string(from: Date())) \(why)")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let st = await Runner().run(["xcrun", "devicectl", "device", "copy", "from", "--device", d.id, "--domain-type", "appDataContainer",
                                     "--domain-identifier", bundleID, "--source", "Documents/save", "--destination", dir.appendingPathComponent("save").path]) { self.say($0) }
        let files = HookLink.files(in: dir.appendingPathComponent("save"))
        guard st == 0, !files.isEmpty else {
            try? FileManager.default.removeItem(at: dir)
            if !quiet { saveStatus = "No saves on the phone yet (or it couldn't be read). Play and save in the game first." }
            return nil
        }
        saveStatus = "✓ Saves backed up (\(files.count) files) to Documents → HookLink Save Backups → \(dir.lastPathComponent)"
        return dir
    }

    /// Puts a backup's saves on the phone, file by file, after backing up what's there now. The game must be closed.
    func restoreSaves(from backup: URL) async {
        let src = backup.lastPathComponent == "save" ? backup : backup.appendingPathComponent("save")
        let files = HookLink.files(in: src)
        guard !files.isEmpty else { saveStatus = "That folder has no saves in it."; return }
        if device == nil || bundleID.isEmpty { await findDevices() }
        guard let d = device, !bundleID.isEmpty else { saveStatus = "Plug in your iPhone with the game installed, unlock it, and try again."; return }
        busy = true; defer { busy = false; endWork() }
        beginWork("Restoring saves", steps: 3)
        workStep(1, "Backing up the saves on the phone first")
        await backupSaves("before restore", quiet: true)
        workStep(2, "Copying \(files.count) save files", fraction: 0)
        var bad = 0
        for (i, rel) in files.enumerated() {
            let st = await Runner().run(["xcrun", "devicectl", "device", "copy", "to", "--device", d.id, "--domain-type", "appDataContainer",
                                         "--domain-identifier", bundleID, "--source", src.appendingPathComponent(rel).path, "--destination", "Documents/save/\(rel)"]) { self.say($0) }
            if st != 0 { bad += 1 }
            workFraction(Double(i + 1) / Double(files.count))
        }
        workStep(3, "Checking")
        let back = FileManager.default.temporaryDirectory.appendingPathComponent("hooklink-save-check")
        for rel in files {
            try? FileManager.default.removeItem(at: back)
            _ = await Runner().run(["xcrun", "devicectl", "device", "copy", "from", "--device", d.id, "--domain-type", "appDataContainer",
                                    "--domain-identifier", bundleID, "--source", "Documents/save/\(rel)", "--destination", back.path]) { _ in }
            if (try? Data(contentsOf: back)) != (try? Data(contentsOf: src.appendingPathComponent(rel))) { bad += 1 }
        }
        saveStatus = bad == 0 ? "✓ Restored \(files.count) save files from \(backup.lastPathComponent), and checked them. Open the game."
                              : "✗ \(bad) save file(s) didn't copy correctly. Your previous saves are in the newest \"before restore\" backup."
    }

    /// Files under a folder, as paths relative to it
    static func files(in dir: URL) -> [String] {
        guard let e = FileManager.default.enumerator(at: dir, includingPropertiesForKeys: [.isRegularFileKey]) else { return [] }
        var out: [String] = []
        for case let u as URL in e where (try? u.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true {
            out.append(String(u.standardizedFileURL.path.dropFirst(dir.standardizedFileURL.path.count + 1)))
        }
        return out.sorted()
    }
}

/// On the Play page: back up, restore, open the backups folder
struct SavesBox: View {
    @EnvironmentObject var app: HookLink
    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                Text("Your saves").font(.headline)
                Text("Your saves live only on your iPhone. Back them up to this Mac now and then, and before reinstalling the game. HookLink also backs them up by itself before copying game files.")
                HStack {
                    Button("Back up my saves") { Task { await app.backupSaves("backup") } }.disabled(app.busy)
                    Button("Restore a backup…") { pick() }.disabled(app.busy)
                    Button("Show backups") { NSWorkspace.shared.open(app.saveBackupsDir) }
                }
                if !app.saveStatus.isEmpty { Text(app.saveStatus).foregroundStyle(.secondary) }
            }.frame(maxWidth: .infinity, alignment: .leading).padding(4)
        }
    }
    func pick() {
        let p = NSOpenPanel(); p.canChooseDirectories = true; p.canChooseFiles = false; p.directoryURL = app.saveBackupsDir
        p.message = "Choose a backup folder to put back on your iPhone (close the game first). What's on the phone now is backed up first."
        p.prompt = "Restore"
        if p.runModal() == .OK, let u = p.url { Task { await app.restoreSaves(from: u) } }
    }
}
