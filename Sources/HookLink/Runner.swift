import Foundation

/// Runs a command and streams its output, one line at a time, to the caller on the main actor.
/// Every tool HookLink runs goes through here, so the log shows exactly what was run.
final class Runner {
    private var process: Process?

    /// PATH for the tools: GUI apps do not get the shell's PATH, so Homebrew's folders are added.
    static let path: String = {
        let extra = ["/opt/homebrew/bin", "/usr/local/bin", "/usr/bin", "/bin", "/usr/sbin", "/sbin",
                     "/usr/local/share/dotnet", NSHomeDirectory() + "/.dotnet"]
        let current = ProcessInfo.processInfo.environment["PATH"].map { $0.split(separator: ":").map(String.init) } ?? []
        var seen = Set<String>(); var all: [String] = []
        for p in current + extra where !seen.contains(p) { seen.insert(p); all.append(p) }
        return all.joined(separator: ":")
    }()

    /// Runs `args[0]` (looked up on PATH) with the rest as arguments. `onLine` gets each output line (stdout and stderr merged).
    /// Returns the exit status, or -1 when it could not start.
    @discardableResult
    func run(_ args: [String], cwd: URL? = nil, env: [String: String] = [:],
             onLine: @escaping @MainActor (String) -> Void) async -> Int32 {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        p.arguments = args
        if let cwd { p.currentDirectoryURL = cwd }
        var e = ProcessInfo.processInfo.environment
        e["PATH"] = Runner.path
        e["PYTHONUNBUFFERED"] = "1"
        for (k, v) in env { e[k] = v }
        p.environment = e
        let pipe = Pipe()
        p.standardOutput = pipe; p.standardError = pipe
        process = p
        do { try p.run() } catch {
            await onLine("Could not start \(args.first ?? "?"): \(error.localizedDescription)")
            return -1
        }
        let handle = pipe.fileHandleForReading
        var buffer = Data()
        while true {
            let chunk = handle.availableData
            if chunk.isEmpty { break }
            buffer.append(chunk)
            while let nl = buffer.firstIndex(of: 0x0a) {
                let lineData = buffer.subdata(in: buffer.startIndex..<nl)
                buffer.removeSubrange(buffer.startIndex...nl)
                let line = String(decoding: lineData, as: UTF8.self)
                await onLine(line)
            }
        }
        if !buffer.isEmpty { await onLine(String(decoding: buffer, as: UTF8.self)) }
        p.waitUntilExit()
        process = nil
        return p.terminationStatus
    }

    /// Runs a command and returns its whole output (for quick checks).
    static func capture(_ args: [String], env: [String: String] = [:]) async -> (status: Int32, out: String) {
        var lines: [String] = []
        let status = await Runner().run(args, env: env) { lines.append($0) }
        return (status, lines.joined(separator: "\n"))
    }

    func cancel() { process?.terminate() }
}
