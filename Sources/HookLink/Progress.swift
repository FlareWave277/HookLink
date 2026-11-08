import SwiftUI

/// What HookLink is doing right now, for the progress card every long task shows: an overall bar across the task's steps, a bar
/// for the current step (a percentage when it can be counted, an estimate or a moving bar when it can't), the elapsed time, and
/// the latest thing the task said, so a step that takes a while never looks frozen.
struct WorkProgress: Equatable {
    var title: String                 // "Building", "Copying game files"
    var stepName = ""                 // the current step
    var stepIndex = 0, stepCount = 0  // 1-based; 0 when the task has no steps
    var stepFraction: Double? = nil   // nil: not countable (a moving bar)
    var estimated = false             // stepFraction is a time estimate, not a count
    var eta = ""                      // time left in this step, when known
    var detail = ""                   // the latest activity line
    var started = Date()
    var stepStarted = Date()
    var lastChange = Date()

    /// Across the whole task: finished steps plus the current one's share
    var overall: Double? {
        guard stepCount > 0 else { return stepFraction }
        return min(1, (Double(max(stepIndex, 1) - 1) + (stepFraction ?? 0)) / Double(stepCount))
    }
}

@MainActor
extension HookLink {
    func beginWork(_ title: String, steps: Int = 0) { work = WorkProgress(title: title, stepCount: steps) }
    func workStep(_ i: Int, _ name: String, fraction: Double? = nil, estimated: Bool = false) {
        guard work != nil else { return }
        work!.stepIndex = i; work!.stepName = name; work!.stepFraction = fraction; work!.estimated = estimated
        work!.eta = ""; work!.stepStarted = Date(); work!.lastChange = Date()
    }
    func workFraction(_ f: Double?, eta: String = "") {
        guard work != nil else { return }
        if let f, f != work!.stepFraction { work!.lastChange = Date() }
        work!.stepFraction = f; work!.eta = eta
    }
    func workDetail(_ s: String) {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        guard work != nil, !t.isEmpty, !t.hasPrefix("{") else { return }
        work!.detail = t.count > 160 ? String(t.prefix(160)) + "…" : t; work!.lastChange = Date()
    }
    func endWork() { work = nil }
}

/// The card: shown on any page while a task runs
struct ProgressCard: View {
    let w: WorkProgress
    var body: some View {
        GroupBox {
            TimelineView(.periodic(from: .now, by: 1)) { ctx in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(w.title).font(.headline)
                        Spacer()
                        Text(HookLink.hms(ctx.date.timeIntervalSince(w.started))).monospacedDigit().foregroundStyle(.secondary)
                    }
                    if let o = w.overall, w.stepCount > 0 {
                        ProgressView(value: o) { EmptyView() } currentValueLabel: {
                            Text("\(Int(o * 100))% overall").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    if !w.stepName.isEmpty {
                        HStack {
                            Text(w.stepCount > 0 ? "Step \(w.stepIndex) of \(w.stepCount): \(w.stepName)" : w.stepName).font(.callout)
                            Spacer()
                            Text(HookLink.hms(ctx.date.timeIntervalSince(w.stepStarted)) + " in this step").font(.caption).monospacedDigit().foregroundStyle(.secondary)
                        }
                    }
                    if let f = w.stepFraction {
                        ProgressView(value: f)
                        Text((w.estimated ? "About " : "") + "\(Int(f * 100))%" + (w.eta.isEmpty ? "" : ", about \(w.eta) left") + (w.estimated ? " (estimated)" : ""))
                            .font(.caption).foregroundStyle(.secondary)
                    } else {
                        ProgressView().progressViewStyle(.linear)
                        Text("Working… this part can't be counted, so the bar moves until it's done.").font(.caption).foregroundStyle(.secondary)
                    }
                    if !w.detail.isEmpty { Text(w.detail).font(.caption.monospaced()).foregroundStyle(.secondary).lineLimit(2) }
                    if ctx.date.timeIntervalSince(w.lastChange) > 120 {
                        Text("Still working: some steps go quiet for several minutes while they check large files.").font(.caption).foregroundStyle(.orange)
                    }
                }
            }
        }
    }
}
