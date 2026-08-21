import Foundation

/// The four trainable qualities Setline measures. A movement can serve several
/// at once, so callers hold a set rather than a single value.
public enum Pillar: String, Codable, CaseIterable, Sendable {
    case strength
    case stamina
    case mobility
    case flexibility

    public var title: String {
        switch self {
        case .strength: "Strength"
        case .stamina: "Stamina"
        case .mobility: "Mobility"
        case .flexibility: "Flexibility"
        }
    }
}

/// Why a set exists inside a session. Only `working` sets count toward volume,
/// personal records and progression decisions — the authored programme is
/// explicit that warm-ups are not working sets.
public enum StepType: String, Codable, CaseIterable, Sendable {
    case preparation
    case warmUp
    case working
    case cardio
    case mobility
    case cooldown
    case check

    public var countsAsWorkingSet: Bool { self == .working }

    public var title: String {
        switch self {
        case .preparation: "Preparation"
        case .warmUp: "Warm-up"
        case .working: "Working"
        case .cardio: "Cardio"
        case .mobility: "Mobility"
        case .cooldown: "Cooldown"
        case .check: "Check"
        }
    }
}

/// How a set's load is prescribed. Authored programmes routinely express load
/// relatively ("about 70%", "bodyweight + 10 kg") or leave it to the lifter, and
/// collapsing those into a single number loses the instruction.
public enum LoadTarget: Codable, Equatable, Sendable {
    case absolute(kilograms: Double)
    case percentOfOneRepMax(Double)
    case bodyweight(plusKilograms: Double)
    case assisted(kilograms: Double)
    case chooseLoad

    public var displayString: String {
        switch self {
        case let .absolute(kilograms):
            "\(kilograms.trimmedString) kg"
        case let .percentOfOneRepMax(percent):
            "\(percent.trimmedString)% 1RM"
        case let .bodyweight(plus):
            plus == 0 ? "Bodyweight" : "Bodyweight + \(plus.trimmedString) kg"
        case let .assisted(kilograms):
            "Assisted −\(kilograms.trimmedString) kg"
        case .chooseLoad:
            "Choose load"
        }
    }
}

/// Prescribed movement speed, in seconds per phase.
public struct Tempo: Codable, Equatable, Sendable {
    public var eccentricSeconds: Int
    public var pauseBottomSeconds: Int
    public var concentricSeconds: Int
    public var pauseTopSeconds: Int

    public init(
        eccentricSeconds: Int,
        pauseBottomSeconds: Int = 0,
        concentricSeconds: Int,
        pauseTopSeconds: Int = 0
    ) {
        self.eccentricSeconds = eccentricSeconds
        self.pauseBottomSeconds = pauseBottomSeconds
        self.concentricSeconds = concentricSeconds
        self.pauseTopSeconds = pauseTopSeconds
    }

    public var displayString: String {
        "\(eccentricSeconds)-\(pauseBottomSeconds)-\(concentricSeconds)-\(pauseTopSeconds)"
    }
}

/// An inclusive range of rest seconds. The authored programme prescribes rest as
/// a band ("2.5-3 min"), so storing a scalar would silently pick one end.
public struct RestRange: Codable, Equatable, Sendable {
    public var lowSeconds: Int
    public var highSeconds: Int

    public init(lowSeconds: Int, highSeconds: Int) {
        self.lowSeconds = max(0, min(lowSeconds, highSeconds))
        self.highSeconds = max(0, max(lowSeconds, highSeconds))
    }

    public init(_ seconds: Int) {
        self.init(lowSeconds: seconds, highSeconds: seconds)
    }

    public static let none = RestRange(0)

    /// The value the rest timer counts down from.
    public var timerSeconds: Int { lowSeconds }

    public var isEmpty: Bool { highSeconds == 0 }

    public var displayString: String {
        if isEmpty { return "No rest" }
        if lowSeconds == highSeconds { return lowSeconds.restLabel }
        return "\(lowSeconds.restValue)–\(highSeconds.restLabel)"
    }
}

/// The complete structured prescription for one set.
///
/// This replaces the free-text target string the programme used to carry. Rep
/// ranges, reps in reserve, tempo, per-side work and relative load all have to
/// be machine-readable for progression, volume and personal records to mean
/// anything.
public struct SetTarget: Codable, Equatable, Sendable {
    public struct RepTarget: Equatable, Sendable {
        public var repsLow: Int?
        public var repsHigh: Int?
        public var repsInReserve: Int?
        public var rpe: Double?

        public init(
            repsLow: Int? = nil,
            repsHigh: Int? = nil,
            repsInReserve: Int? = nil,
            rpe: Double? = nil
        ) {
            self.repsLow = repsLow
            self.repsHigh = repsHigh
            self.repsInReserve = repsInReserve
            self.rpe = rpe
        }
    }

    public struct TimeTarget: Equatable, Sendable {
        public var tempo: Tempo?
        public var timeSeconds: Int?
        public var holdSeconds: Int?

        public init(
            tempo: Tempo? = nil,
            timeSeconds: Int? = nil,
            holdSeconds: Int? = nil
        ) {
            self.tempo = tempo
            self.timeSeconds = timeSeconds
            self.holdSeconds = holdSeconds
        }
    }

    public struct DistanceTarget: Equatable, Sendable {
        public var distanceMetres: Double?
        public var paceSecondsPerKilometre: Int?
        public var heartRateZone: Int?

        public init(
            distanceMetres: Double? = nil,
            paceSecondsPerKilometre: Int? = nil,
            heartRateZone: Int? = nil
        ) {
            self.distanceMetres = distanceMetres
            self.paceSecondsPerKilometre = paceSecondsPerKilometre
            self.heartRateZone = heartRateZone
        }
    }

    public var repsLow: Int?
    public var repsHigh: Int?
    public var load: LoadTarget?
    public var repsInReserve: Int?
    public var rpe: Double?
    public var tempo: Tempo?
    public var timeSeconds: Int?
    public var holdSeconds: Int?
    public var distanceMetres: Double?
    public var paceSecondsPerKilometre: Int?
    public var heartRateZone: Int?
    public var perSide: Bool
    /// Preserves a target string that predates structured targets so historic
    /// sessions keep displaying exactly what they were performed against.
    public var legacyDisplay: String?

    public init(
        repTarget: RepTarget = .init(),
        timeTarget: TimeTarget = .init(),
        distanceTarget: DistanceTarget = .init(),
        load: LoadTarget? = nil,
        perSide: Bool = false,
        legacyDisplay: String? = nil
    ) {
        self.repsLow = repTarget.repsLow
        self.repsHigh = repTarget.repsHigh
        self.load = load
        self.repsInReserve = repTarget.repsInReserve
        self.rpe = repTarget.rpe
        self.tempo = timeTarget.tempo
        self.timeSeconds = timeTarget.timeSeconds
        self.holdSeconds = timeTarget.holdSeconds
        self.distanceMetres = distanceTarget.distanceMetres
        self.paceSecondsPerKilometre = distanceTarget.paceSecondsPerKilometre
        self.heartRateZone = distanceTarget.heartRateZone
        self.perSide = perSide
        self.legacyDisplay = legacyDisplay
    }

    /// Wraps an un-parseable historic target so nothing recorded is ever lost.
    public init(legacy display: String) {
        self.init(legacyDisplay: display)
    }

    public var repetitionsDisplay: String? {
        guard let repsLow else { return nil }
        guard let repsHigh, repsHigh != repsLow else { return "\(repsLow) reps" }
        return "\(repsLow)–\(repsHigh) reps"
    }

    public var durationDisplay: String? {
        guard let seconds = timeSeconds ?? holdSeconds else { return nil }
        return seconds.durationLabel
    }

    /// The single line the player shows as TARGET.
    public var displayString: String {
        if let legacyDisplay, !legacyDisplay.isEmpty { return legacyDisplay }
        var parts: [String] = []
        if let load { parts.append(load.displayString) }
        if let repetitionsDisplay { parts.append(repetitionsDisplay) }
        if let durationDisplay { parts.append(durationDisplay) }
        if let distanceMetres { parts.append(distanceMetres.distanceLabel) }
        if let paceSecondsPerKilometre { parts.append("\(paceSecondsPerKilometre.paceLabel)/km") }
        if let heartRateZone { parts.append("Zone \(heartRateZone)") }
        if parts.isEmpty { return "Complete" }
        var line = parts.joined(separator: " · ")
        if perSide { line += " per side" }
        return line
    }

    /// Secondary qualifiers shown beneath the target, never folded into it.
    public var qualifiers: [String] {
        var result: [String] = []
        if let repsInReserve { result.append("\(repsInReserve) RIR") }
        if let rpe { result.append("RPE \(rpe.trimmedString)") }
        if let tempo { result.append("Tempo \(tempo.displayString)") }
        return result
    }

    public var isEmpty: Bool {
        self == SetTarget()
    }
}

// MARK: - Formatting helpers

public extension Double {
    /// Formats without a trailing ".0" so "65 kg" never renders as "65.0 kg", and
    /// without leaking binary floating-point precision — an estimated 1RM must
    /// read "91.83 kg", never "91.83333333333333 kg".
    var trimmedString: String {
        guard isFinite else { return "—" }
        let bounded = (self * 100).rounded() / 100
        if bounded == bounded.rounded() { return String(Int(bounded)) }
        var text = String(format: "%.2f", bounded)
        while text.hasSuffix("0") { text.removeLast() }
        if text.hasSuffix(".") { text.removeLast() }
        return text
    }

    /// Rounded to a single decimal, for kilogram values where two decimals claim
    /// more precision than a barbell can express.
    var kilogramString: String {
        ((self * 10).rounded() / 10).trimmedString
    }

    var distanceLabel: String {
        self >= 1_000 ? "\((self / 1_000).trimmedString) km" : "\(trimmedString) m"
    }
}

public extension Int {
    /// "45 sec", "2 min", "2 min 30 sec" — never a bare second count for long work.
    var durationLabel: String {
        if self < 60 { return "\(self) sec" }
        let minutes = self / 60
        let seconds = self % 60
        if seconds == 0 { return "\(minutes) min" }
        return "\(minutes) min \(seconds) sec"
    }

    /// The numeric part of a rest bound, used to build "2.5–3 min".
    var restValue: String {
        if self < 60 { return "\(self)" }
        let minutes = Double(self) / 60
        return minutes.trimmedString
    }

    var restLabel: String {
        self < 60 ? "\(self) sec" : "\(restValue) min"
    }

    var paceLabel: String {
        String(format: "%d:%02d", self / 60, self % 60)
    }
}
