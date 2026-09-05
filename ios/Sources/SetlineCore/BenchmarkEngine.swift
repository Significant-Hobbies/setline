import Foundation

/// Derives the assessment for every benchmark: current value, target, status,
/// and a plain-language message. Ported from the Baseline tracker's `assess()`
/// function, preserving the distinction between recorded, estimated, reported,
/// and unknown values.
public enum BenchmarkEngine {
    /// Assesses one metric against its target, using the given state.
    public static func assess(_ id: String, state: BenchmarksState) -> BenchmarkAssessment {
        let x = state.metrics[id] ?? .init()
        let t = state.targets[id] ?? .init()
        let w = state.profile.weight
        let h = state.profile.height
        var r = BenchmarkAssessment()

        func mark(_ met: Bool, status: String = "Building") {
            r.reached = met
            r.status = met ? "Target reached" : status
            r.tone = met ? .good : r.tone
        }

        switch id {
        case "run":
            let secs = parseTime(x.text("time"))
            let distance = x.number("distance")
            let timed = secs.map { $0 > 0 } ?? false
            let targetSeconds = t.value("minutes").map { $0 * 60 } ?? 0
            r.target = "< \(displayTime(targetSeconds))"
            r.targetSub = "\(fmt(t.value("distance") ?? 0)) km \u{00B7} continuous"
            if present(distance) || timed {
                r.recorded = true
                r.current = present(distance) ? "\(fmt(distance!)) km" : "Time only"
                r.currentSub = timed ? "\(x.text("qualifier") == "More than" ? "> " : "")\(displayTime(secs!)) elapsed" : "Time not entered"
                r.status = "Baseline logged"
                if present(distance) && timed && near(distance!, t.value("distance") ?? 0) {
                    let exact = x.text("qualifier") == "Exact time"
                    mark(exact && x.flag("continuous") && secs! < targetSeconds, status: "Time / protocol")
                    if r.reached {
                        r.message = "Distance, continuous running, and time goal met."
                    } else if !exact {
                        r.message = "Enter an exact time before comparing this run."
                    } else if !x.flag("continuous") {
                        r.message = "Confirm continuous running to meet this standard."
                    } else {
                        r.message = "Target is under \(displayTime(targetSeconds)) over \(fmt(t.value("distance") ?? 0)) km."
                    }
                } else {
                    r.status = "Shorter effort"
                    r.message = "Recorded as-is. Not extrapolated to \(fmt(t.value("distance") ?? 0)) km; complete the target distance to compare times."
                }
            }

        case "pullups":
            r.target = String(Int(t.value("reps") ?? 0))
            r.targetSub = "strict repetitions"
            if let reps = x.number("reps"), present(reps) {
                r.recorded = true
                r.current = String(Int(reps))
                r.currentSub = "strict repetitions"
                mark(near(reps, t.value("reps") ?? 0))
                r.message = r.reached ? "Clean repetition goal met." : "\(fmt(max(0, t.value("reps") ?? 0 - reps), 0)) more clean repetitions to target."
            }

        case "bench":
            let target = w.map { $0 * (t.value("ratio") ?? 0) }
            r.target = target.map { "\(fmt($0)) kg" } ?? "Set weight"
            r.targetSub = "\(fmt(t.value("ratio") ?? 0, 2))\u{00D7} bodyweight \u{00B7} 1 rep"
            if let load = x.number("load"), present(load) {
                r.recorded = true
                let reps = x.number("reps")
                r.current = "\(fmt(load)) \u{00D7} \(reps.map { fmt($0, 0) } ?? "?")"
                r.currentSub = "kg \u{00D7} repetitions"
                let valid = reps.map { $0 > 0 } ?? false
                let estimate: Double? = {
                    guard valid, let reps, reps <= 10 else { return nil }
                    return reps == 1 ? load : load * (1 + Double(reps) / 30)
                }()
                mark(target.map { tgt in valid && near(load, tgt) } ?? false)
                if r.reached {
                    r.message = "You have actually lifted at least the target load."
                } else if target == nil {
                    r.message = "Enter your bodyweight to calculate the load target."
                } else if let estimate, let reps, reps > 1 {
                    r.status = "Estimate only"
                    r.tone = .caution
                    r.message = "Estimated 1RM \u{2248} \(fmt(estimate)) kg. Not a tested max or a passed target."
                } else if let reps, reps == 1 {
                    r.message = "\(fmt(max(0, target! - load))) kg below target. Use a spotter / safeties when testing."
                } else {
                    r.message = "Enter a tested single or a set of 2\u{2013}10 reps for a planning estimate."
                }
            }

        case "split":
            let target = w.map { $0 * (t.value("ratio") ?? 0) / 2 }
            r.target = target.map { "\(fmt($0)) kg" } ?? "Set weight"
            r.targetSub = "per hand \u{00D7} \(Int(t.value("reps") ?? 0)) reps / leg"
            if present(x.number("load")) || present(x.number("reps")) {
                r.recorded = true
                r.current = "\(fmt(x.number("load") ?? 0)) \u{00D7} \(fmt(x.number("reps") ?? 0, 0))"
                r.currentSub = "kg per hand \u{00D7} reps / leg"
                let load = x.number("load")
                let reps = x.number("reps")
                mark(target.map { tgt in present(load) && present(reps) && near(load!, tgt) && near(reps!, t.value("reps") ?? 0) } ?? false)
                if r.reached {
                    r.message = "Load and repetitions met on the weaker leg."
                } else if target != nil {
                    r.message = "\(fmt(target! * 2)) kg total external load, with \(Int(t.value("reps") ?? 0)) controlled reps on each leg."
                } else {
                    r.message = "Enter your bodyweight to calculate the load target."
                }
            }

        case "jump":
            r.target = "\(fmt(t.value("distance") ?? 0, 2)) m"
            r.targetSub = "standing broad jump"
            if let distance = x.number("distance"), present(distance) {
                r.recorded = true
                r.current = "\(x.text("effort") == "Comfortable attempt" ? "\u{2265} " : "")\(fmt(distance, 2)) m"
                r.currentSub = x.text("effort") == "Comfortable attempt" ? "comfortable attempt, not maximum" : "best of three"
                mark(x.text("effort") != "Comfortable attempt" && near(distance, t.value("distance") ?? 0), status: x.text("effort") == "Comfortable attempt" ? "Easy attempt" : "Building")
                if r.reached {
                    r.message = "Recorded jump reaches the distance target."
                } else if x.text("effort") == "Comfortable attempt" {
                    r.message = "Your best distance is unknown. Practise, then record a controlled best of three."
                } else {
                    r.message = "\(fmt(max(0, t.value("distance") ?? 0 - distance), 2)) m from the distance target."
                }
            }

        case "carry":
            let target = w.map { $0 * (t.value("ratio") ?? 0) }
            r.target = target.map { "\(fmt($0)) kg" } ?? "Set weight"
            r.targetSub = "per hand \u{00B7} \(fmt(t.value("distance") ?? 0)) m"
            let load = x.number("load")
            let distance = x.number("distance")
            if present(load) || present(distance) {
                r.recorded = true
                r.current = load.map { "\(fmt($0)) kg" } ?? "Load unknown"
                r.currentSub = "per hand \u{00B7} \(distance.map { "\(fmt($0)) m" } ?? "distance not logged")"
                let hasDistance = present(distance)
                mark(target.map { tgt in present(load) && hasDistance && near(load!, tgt) && near(distance!, t.value("distance") ?? 0) } ?? false,
                     status: !hasDistance ? "Need distance" : (x.text("effort") == "Comfortable attempt" ? "Easy attempt" : "Building"))
                if r.reached {
                    r.message = "Load and unbroken distance targets both met."
                } else if !hasDistance {
                    r.message = "Your load was easy. Add the distance; do not treat this as a maximum."
                } else if target != nil {
                    r.message = "Meet both \(fmt(target!)) kg per hand and \(fmt(t.value("distance") ?? 0)) m without a put-down."
                } else {
                    r.message = "Enter bodyweight to calculate the load target."
                }
            }

        case "balance":
            r.target = "\(Int(t.value("seconds") ?? 0)) s"
            r.targetSub = "each leg \u{00B7} eyes closed"
            let left = x.number("left")
            let right = x.number("right")
            if present(left) || present(right) {
                r.recorded = true
                r.current = (present(left) && present(right)) ? "\(fmt(min(left!, right!), 0)) s" : "One side"
                r.currentSub = "L \(fmt(left ?? 0, 0)) / R \(fmt(right ?? 0, 0)) s"
                mark(x.text("condition") == "Eyes closed" && present(left) && present(right) && near(left!, t.value("seconds") ?? 0) && near(right!, t.value("seconds") ?? 0), status: "Building")
                if r.reached {
                    r.message = "Both legs meet the eyes-closed standard."
                } else if x.text("condition") != "Eyes closed" {
                    r.message = "Confirm eyes-closed conditions. Eyes-open times are not interchangeable."
                } else {
                    r.message = "The weaker side sets the result. Record both legs."
                }
                if x.text("condition") != "Eyes closed" {
                    r.status = "Check protocol"
                    r.tone = .caution
                }
            } else if x.reported {
                r.recorded = true
                r.current = "10\u{2013}15 s"
                r.currentSub = "reported easy \u{00B7} conditions unknown"
                r.status = "Check protocol"
                r.tone = .caution
                r.message = "Sides and eyes-open/closed condition were not stated. Log a comparable result."
            }

        case "ankle":
            r.target = "\(fmt(t.value("cm") ?? 0)) cm"
            r.targetSub = "on both sides \u{00B7} heel down"
            let left = x.number("left")
            let right = x.number("right")
            if present(left) || present(right) {
                r.recorded = true
                r.current = (present(left) && present(right)) ? "\(fmt(min(left!, right!))) cm" : "One side"
                r.currentSub = "L \(fmt(left ?? 0)) / R \(fmt(right ?? 0)) cm"
                mark(present(left) && present(right) && near(left!, t.value("cm") ?? 0) && near(right!, t.value("cm") ?? 0))
                r.message = r.reached ? "Both ankles reach your selected target." : "Record both sides without lifting the heel or forcing a painful range."
            } else if x.reported {
                r.recorded = true
                r.current = "Not yet"
                r.currentSub = "restriction reported \u{00B7} not measured"
                r.status = "Needs measure"
                r.message = "Enter each ankle\u{2019}s distance. A missing measurement is not zero mobility."
            }

        case "squat":
            r.target = "\(Int(t.value("seconds") ?? 0)) s"
            r.targetSub = "comfortable \u{00B7} unsupported"
            if let seconds = x.number("seconds"), present(seconds) {
                r.recorded = true
                r.current = "\(fmt(seconds, 0)) s"
                r.currentSub = x.flag("clean") ? "heels down \u{00B7} unassisted" : "position quality not confirmed"
                mark(x.flag("clean") && near(seconds, t.value("seconds") ?? 0))
                if r.reached {
                    r.message = "Duration and comfortable-position checks met."
                } else if !x.flag("clean") {
                    r.message = "A longer assisted hold does not meet the unsupported standard."
                } else {
                    r.message = "\(fmt(max(0, t.value("seconds") ?? 0 - seconds), 0)) seconds to your hold target."
                }
            } else if x.reported {
                r.recorded = true
                r.current = "Not yet"
                r.currentSub = "restriction reported"
                r.status = "Needs measure"
                r.message = "Work within a comfortable range. Log time and whether the position meets the standard."
            }

        case "overhead":
            r.target = "Clean reach"
            r.targetSub = "arms beside ears \u{00B7} no back arch"
            if let status = x.text("status"), status != "Not tested" {
                r.recorded = true
                r.current = status == "Meets standard" ? "Pass" : "Not yet"
                r.currentSub = status == "Meets standard" ? "comfortable overhead position" : "restriction reported"
                mark(status == "Meets standard", status: "Working on it")
                r.message = r.reached ? "Functional reach standard met\u{2014}not a full joint assessment." : "Straight arms by ears, without pronounced rib flare or lumbar arching."
            }

        case "waist":
            let target = h.map { $0 * (t.value("ratio") ?? 0) }
            r.target = target.map { "< \(fmt($0)) cm" } ?? "Set height"
            r.targetSub = "waist \u{00F7} height < \(fmt(t.value("ratio") ?? 0, 2))"
            if let waist = x.number("waist"), present(waist) {
                r.recorded = true
                r.current = "\(fmt(waist)) cm"
                r.currentSub = h.map { "ratio \(fmt(waist / $0, 3))" } ?? "height required for ratio"
                mark(h.map { waist / $0 < (t.value("ratio") ?? 0) } ?? false, status: "Above target")
                if r.reached {
                    r.message = "Below your selected waist-to-height boundary."
                } else if target != nil {
                    r.message = "Track the measurement trend toward below \(fmt(target!)) cm; not a body-fat estimate."
                } else {
                    r.message = "Enter your height to calculate the ratio."
                }
            } else if x.reported {
                r.recorded = true
                r.current = "Above goal"
                r.currentSub = "reported \u{00B7} circumference unknown"
                r.status = "Needs measure"
                r.message = "Enter a tape measurement. We have not invented a waist value from bodyweight."
            }

        case "swim":
            r.target = "\(fmt(t.value("distance") ?? 0, 0)) m"
            r.targetSub = "+ \(fmt(t.value("tread") ?? 0, 0)) s treading + basics"
            let distance = x.number("distance")
            let tread = x.number("tread")
            if present(distance) || present(tread) || x.flag("basics") {
                r.recorded = true
                r.current = distance.map { "\(fmt($0, 0)) m" } ?? "Swim not logged"
                r.currentSub = "treading \(fmt(tread ?? 0, 0)) s \u{00B7} basics \(x.flag("basics") ? "yes" : "not confirmed")"
                mark(present(distance) && present(tread) && near(distance!, t.value("distance") ?? 0) && near(tread!, t.value("tread") ?? 0) && x.flag("basics"))
                r.message = r.reached ? "Pool goals met. This is not an open-water safety certificate." : "Swim, tread, and demonstrate entry / orientation / exit skills under supervision."
            } else {
                r.message = "No baseline yet. Test only with appropriate supervision and help available."
            }

        case "reaction":
            r.target = "\u{2264} \(fmt(t.value("cm") ?? 0)) cm"
            r.targetSub = "mean of 10 ruler drops"
            if let cm = x.number("cm"), present(cm) {
                r.recorded = true
                r.current = "\(fmt(cm)) cm"
                r.currentSub = "\u{2248} \(fmt(1000 * (2 * cm / 100 / 9.80665).squareRoot(), 0)) ms \u{00B7} simple visual response"
                mark(cm <= (t.value("cm") ?? 0))
                r.message = r.reached ? "Your mean catch distance meets the drill target." : "\(fmt(max(0, cm - (t.value("cm") ?? 0)))) cm above target. Lower is faster; do not anticipate the drop."
            }

        case "coordination":
            r.target = String(Int(t.value("catches") ?? 0))
            r.targetSub = "catches / 30 s \u{00B7} 2 m from wall"
            if let catches = x.number("catches"), present(catches) {
                r.recorded = true
                r.current = String(Int(catches))
                r.currentSub = "alternate-hand catches / 30 s"
                mark(near(catches, t.value("catches") ?? 0))
                r.message = r.reached ? "Drill target met. This is one coordination task, not a universal score." : "\(fmt(max(0, t.value("catches") ?? 0 - catches), 0)) more successful catches in the same 30-second test."
            }

        case "agility":
            r.target = "\u{2264} \(fmt(t.value("seconds") ?? 0, 2)) s"
            r.targetSub = "5\u{2013}10\u{2013}5 yards \u{00B7} consistent timing"
            if let seconds = x.number("seconds"), present(seconds) {
                r.recorded = true
                r.current = "\(fmt(seconds, 2)) s"
                r.currentSub = "planned shuttle time"
                mark(seconds <= (t.value("seconds") ?? 0))
                r.message = r.reached ? "Shuttle target met using your recorded test setup." : "\(fmt(max(0, seconds - (t.value("seconds") ?? 0)), 2)) seconds above target. Keep timing and surface consistent."
            } else {
                r.message = "Build sprint and braking tolerance before attempting a maximal shuttle."
            }

        default:
            break
        }

        return r
    }

    /// Assesses one metric against a check-in snapshot's state.
    public static func assess(_ id: String, checkIn: BenchmarkCheckIn) -> BenchmarkAssessment {
        assess(id, state: BenchmarksState(
            profile: checkIn.profile,
            metrics: checkIn.metrics,
            targets: checkIn.targets,
            updated: checkIn.updated,
            history: []
        ))
    }

    // MARK: - Helpers

    static func present(_ value: Double?) -> Bool {
        guard let value else { return false }
        return value.isFinite
    }

    static func near(_ a: Double, _ b: Double) -> Bool {
        a >= b - 1e-8
    }

    static func fmt(_ n: Double, _ d: Int = 1) -> String {
        guard n.isFinite else { return "\u{2014}" }
        let rounded = Double(round(pow(10.0, Double(d)) * n) / pow(10.0, Double(d)))
        let formatter = NumberFormatter()
        formatter.maximumFractionDigits = d
        formatter.minimumFractionDigits = 0
        formatter.locale = Locale(identifier: "en_GB")
        return formatter.string(from: NSNumber(value: rounded)) ?? "\u{2014}"
    }

    /// Parses "mm:ss" or "hh:mm:ss" into seconds. Returns nil for empty/invalid.
    static func parseTime(_ raw: String?) -> Double? {
        guard let raw else { return nil }
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return nil }
        if let n = Double(s) { return n * 60 }
        let parts = s.split(separator: ":").map(String.init)
        guard parts.count >= 2, parts.count <= 3,
              parts.allSatisfy({ Int($0) != nil }) else { return nil }
        let nums = parts.compactMap { Int($0) }
        guard nums.count == parts.count else { return nil }
        if nums.dropFirst().contains(where: { $0 >= 60 }) { return nil }
        if parts.count == 2 {
            return Double(nums[0] * 60 + nums[1])
        } else {
            return Double(nums[0] * 3600 + nums[1] * 60 + nums[2])
        }
    }

    /// Formats seconds as "m:ss" or "h:mm:ss".
    static func displayTime(_ seconds: Double) -> String {
        guard seconds.isFinite else { return "\u{2014}" }
        let n = Int(seconds.rounded())
        let h = n / 3600
        let m = (n % 3600) / 60
        let s = n % 60
        if h > 0 {
            return "\(h):\(String(format: "%02d", m)):\(String(format: "%02d", s))"
        } else {
            return "\(n / 60):\(String(format: "%02d", s))"
        }
    }
}

// MARK: - Scorecard export

/// Produces a plain-text scorecard that preserves the distinction between
/// measured, estimated, reported, and unknown values. Designed for sharing via
/// the iOS share sheet or printing — no HTML, no composite score, no
/// extrapolation.
public enum BenchmarkScorecard {
    /// Renders the full scorecard as plain text.
    public static func text(for state: BenchmarksState) -> String {
        let reached = BenchmarkCatalog.reachedCount(in: state)
        let recorded = BenchmarkCatalog.recordedCount(in: state)
        var lines: [String] = []

        lines.append("Setline \u{00B7} Baseline scorecard")
        lines.append(String(repeating: "\u{2014}", count: 30))
        lines.append("Generated: \(Date.now.formatted(date: .abbreviated, time: .omitted))")
        if let weight = state.profile.weight, let height = state.profile.height {
            lines.append("Profile: \(fmt(weight)) kg \u{00B7} \(fmt(height)) cm")
        } else if let weight = state.profile.weight {
            lines.append("Profile: \(fmt(weight)) kg")
        } else if let height = state.profile.height {
            lines.append("Profile: \(fmt(height)) cm")
        }
        lines.append("Summary: \(reached)/\(BenchmarkCatalog.metrics.count) targets reached \u{00B7} \(recorded) recorded")
        lines.append("")

        for group in BenchmarkGroup.allCases {
            let groupMetrics = BenchmarkCatalog.metrics.filter { $0.group == group }
            guard !groupMetrics.isEmpty else { continue }
            lines.append(group.title.uppercased())
            for metric in groupMetrics {
                let assessment = BenchmarkEngine.assess(metric.id, state: state)
                let status = assessment.reached ? "[\u{2713}]" : (assessment.recorded ? "[ ]" : "[\u{2014}]")
                lines.append("  \(status) \(metric.name)")
                lines.append("       Current: \(assessment.current)")
                if !assessment.currentSub.isEmpty {
                    lines.append("       \(assessment.currentSub)")
                }
                lines.append("       Target:  \(assessment.target)")
                lines.append("       Status:  \(assessment.status)")
            }
            lines.append("")
        }

        lines.append("Ambitious goals, not certified percentiles. An easy attempt is a")
        lines.append("lower bound, a blank is unknown, and an estimated lift is not a")
        lines.append("tested maximum.")
        return lines.joined(separator: "\n")
    }

    private static func fmt(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...1)))
    }
}
