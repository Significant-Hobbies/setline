import Foundation

/// Turns shorthand typed at the rack into structured segments.
///
/// Deliberately rule-based rather than model-driven: entering what you just
/// lifted must never be probabilistic. When the text cannot be understood the
/// parser says so instead of guessing, and the caller shows the interpretation
/// back before anything is recorded.
///
/// Understood forms, comma- or semicolon-separated for multiple segments:
///
///     5x40              five repetitions at 40 kg
///     40kg x 5          same set, weight-first because the unit disambiguates
///     5 reps 40 kg      explicit units in either order
///     bw x 8            bodyweight
///     bw+10 x 8         bodyweight plus 10 kg
///     assist 15 x 6     15 kg of assistance
///     45s               a 45-second hold or carry
///     2min              a two-minute effort
///     5km 25min         distance with its duration
///     5x40 @rpe8 rir1   effort qualifiers
///     left 8, right 8   per-side work
///     5x40, 2x30        one set with two segments
public enum SetEntryParser {
    public struct Result: Equatable, Sendable {
        public var segments: [SetSegment]
        /// Fragments the parser could not interpret, surfaced rather than dropped.
        public var unrecognised: [String]

        public var isEmpty: Bool { segments.isEmpty }
        public var isFullyUnderstood: Bool { unrecognised.isEmpty && !segments.isEmpty }
    }

    public static func parse(_ text: String) -> Result {
        var segments: [SetSegment] = []
        var unrecognised: [String] = []
        for fragment in split(text) {
            if let segment = parseSegment(fragment) {
                segments.append(segment)
            } else {
                unrecognised.append(fragment)
            }
        }
        return Result(segments: segments, unrecognised: unrecognised)
    }

    /// Renders segments back into the shorthand that would reproduce them, so the
    /// field can be round-tripped when editing a recorded set.
    public static func shorthand(for segments: [SetSegment]) -> String {
        segments.map(shorthand(for:)).joined(separator: ", ")
    }

    static func shorthand(for segment: SetSegment) -> String {
        var parts: [String] = []
        if let side = segment.side, side != .both { parts.append(side.rawValue) }
        switch (segment.repetitions, segment.weight) {
        case let (reps?, weight?):
            parts.append("\(reps)x\(weight.trimmedString)")
        case let (reps?, nil):
            if let assistance = segment.assistanceKilograms {
                parts.append("assist \(assistance.trimmedString) x \(reps)")
            } else {
                parts.append("\(reps) reps")
            }
        case let (nil, weight?):
            parts.append("\(weight.trimmedString) kg")
        case (nil, nil):
            break
        }
        if let seconds = segment.durationSeconds {
            parts.append(seconds % 60 == 0 && seconds >= 60 ? "\(seconds / 60)min" : "\(seconds)s")
        }
        if let kilometres = segment.distanceKilometres { parts.append("\(kilometres.trimmedString)km") }
        if let rpe = segment.rpe { parts.append("@rpe\(rpe.trimmedString)") }
        if let rir = segment.repsInReserve { parts.append("rir\(rir)") }
        if segment.reachedFailure { parts.append("fail") }
        return parts.joined(separator: " ")
    }

    // MARK: - Fragmentation

    static func split(_ text: String) -> [String] {
        text
            .replacingOccurrences(of: " then ", with: ",")
            .replacingOccurrences(of: " & ", with: ",")
            .split(whereSeparator: { $0 == "," || $0 == ";" || $0 == "\n" })
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    // MARK: - Segment parsing

    static func parseSegment(_ fragment: String) -> SetSegment? {
        var working = fragment.lowercased()
        var segment = SetSegment()
        var understoodAnything = false

        // Qualifiers and units are consumed first so that whatever remains can be
        // read as a bare "reps x weight" pair without ambiguity.
        if let side = takeSide(&working) {
            segment.side = side
            understoodAnything = true
        }
        if takeFailure(&working) {
            segment.reachedFailure = true
            understoodAnything = true
        }
        if let rpe = takeNumber(&working, pattern: #"@?\s*rpe\s*([0-9]{1,2}(?:\.[05])?)"#)
            ?? takeNumber(&working, pattern: #"@\s*([0-9]{1,2}(?:\.[05])?)"#) {
            segment.rpe = rpe
            understoodAnything = true
        }
        if let rir = takeNumber(&working, pattern: #"rir\s*([0-9]{1,2})"#) {
            segment.repsInReserve = Int(rir)
            understoodAnything = true
        }
        if let assistance = takeNumber(
            &working,
            pattern: #"(?:assist(?:ed)?|assistance)\s*([0-9]+(?:\.[0-9]+)?)\s*(?:kgs?|kilos?|kilograms?)?"#
        ) {
            segment.assistanceKilograms = assistance
            understoodAnything = true
        }
        if let bodyweight = takeBodyweight(&working) {
            if bodyweight > 0 { segment.weight = bodyweight }
            understoodAnything = true
        }
        if let minutes = takeNumber(&working, pattern: #"([0-9]+(?:\.[0-9]+)?)\s*(?:min(?:s|ute|utes)?)"#) {
            segment.durationSeconds = Int((minutes * 60).rounded())
            understoodAnything = true
        }
        if let seconds = takeNumber(&working, pattern: #"([0-9]+(?:\.[0-9]+)?)\s*(?:s|sec|secs|second|seconds)\b"#) {
            segment.durationSeconds = (segment.durationSeconds ?? 0) + Int(seconds.rounded())
            understoodAnything = true
        }
        if let kilometres = takeNumber(&working, pattern: #"([0-9]+(?:\.[0-9]+)?)\s*(?:km|kms|kilometres?|kilometers?)\b"#) {
            segment.distanceKilometres = kilometres
            understoodAnything = true
        }
        if let metres = takeNumber(&working, pattern: #"([0-9]+(?:\.[0-9]+)?)\s*(?:m|metres?|meters?)\b"#) {
            segment.distanceKilometres = (segment.distanceKilometres ?? 0) + metres / 1_000
            understoodAnything = true
        }
        if let weight = takeNumber(&working, pattern: #"([0-9]+(?:\.[0-9]+)?)\s*(?:kgs?|kilos?|kilograms?)\b"#) {
            segment.weight = weight
            understoodAnything = true
        }
        if let reps = takeNumber(&working, pattern: #"([0-9]+)\s*(?:r|rep|reps|repetitions?)\b"#) {
            segment.repetitions = Int(reps)
            understoodAnything = true
        }
        if let degrees = takeNumber(&working, pattern: #"([0-9]+(?:\.[0-9]+)?)\s*(?:deg|degrees?|°)"#) {
            segment.rangeOfMotionValue = degrees
            understoodAnything = true
        }

        // A remaining "A x B" pair. Reps come first when no unit settled it,
        // matching how the plan is written; an already-known value pins the other.
        if let pair = takePair(&working) {
            if segment.repetitions != nil, segment.weight == nil {
                segment.weight = pair.second
            } else if segment.weight != nil, segment.repetitions == nil {
                segment.repetitions = Int(pair.first)
            } else if segment.repetitions == nil, segment.weight == nil {
                segment.repetitions = Int(pair.first)
                segment.weight = pair.second
            }
            understoodAnything = true
        }

        // Whatever units were consumed can leave a dangling separator and number,
        // as "40kg x 5" or "bw+10 x 8" do. Those numbers still carry meaning.
        for character in ["×", "x", "*"] {
            working = working.replacingOccurrences(of: character, with: " ")
        }
        for value in takeRemainingNumbers(&working) {
            if segment.repetitions == nil {
                segment.repetitions = Int(value)
            } else if segment.weight == nil {
                segment.weight = value
            } else {
                continue
            }
            understoodAnything = true
        }

        let leftover = working.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
            .trimmingCharacters(in: .whitespaces)
        guard understoodAnything, leftover.isEmpty || leftover.allSatisfy({ !$0.isNumber }) else {
            return nil
        }
        guard !segment.isEmpty || segment.reachedFailure else { return nil }
        return segment
    }

    // MARK: - Token extraction

    /// Matches `pattern`, removes the match from `text`, and returns capture 1.
    static func takeNumber(_ text: inout String, pattern: String) -> Double? {
        guard let (range, capture) = firstMatch(in: text, pattern: pattern) else { return nil }
        guard let value = Double(capture) else { return nil }
        text.replaceSubrange(range, with: " ")
        return value
    }

    /// Every bare number left after units and separators were consumed, in order.
    static func takeRemainingNumbers(_ text: inout String) -> [Double] {
        var values: [Double] = []
        while let value = takeNumber(&text, pattern: #"([0-9]+(?:\.[0-9]+)?)"#) {
            values.append(value)
            if values.count >= 4 { break }
        }
        return values
    }

    static func takeSide(_ text: inout String) -> BodySide? {
        if let (range, _) = firstMatch(in: text, pattern: #"\b(left|lt)\b"#) {
            text.replaceSubrange(range, with: " ")
            return .left
        }
        if let (range, _) = firstMatch(in: text, pattern: #"\b(right|rt)\b"#) {
            text.replaceSubrange(range, with: " ")
            return .right
        }
        if let (range, _) = firstMatch(in: text, pattern: #"\b(each side|per side|both)\b"#) {
            text.replaceSubrange(range, with: " ")
            return .both
        }
        return nil
    }

    static func takeFailure(_ text: inout String) -> Bool {
        guard let (range, _) = firstMatch(in: text, pattern: #"\b(fail|failed|failure|amrap|to failure)\b"#) else {
            return false
        }
        text.replaceSubrange(range, with: " ")
        return true
    }

    /// `bw`, `bodyweight`, or `bw+10`. Returns the added load, zero when bare.
    static func takeBodyweight(_ text: inout String) -> Double? {
        let pattern = #"\b(?:bw|bodyweight)\b(?:\s*\+\s*([0-9]+(?:\.[0-9]+)?)\s*(?:kgs?|kilos?)?)?"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: nsRange),
              let range = Range(match.range, in: text)
        else { return nil }
        var added = 0.0
        if match.numberOfRanges > 1,
           let captureRange = Range(match.range(at: 1), in: text),
           let value = Double(text[captureRange]) {
            added = value
        }
        text.replaceSubrange(range, with: " ")
        return added
    }

    static func takePair(_ text: inout String) -> (first: Double, second: Double)? {
        let pattern = #"([0-9]+(?:\.[0-9]+)?)\s*[x×*]\s*([0-9]+(?:\.[0-9]+)?)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: nsRange),
              let range = Range(match.range, in: text),
              let firstRange = Range(match.range(at: 1), in: text),
              let secondRange = Range(match.range(at: 2), in: text),
              let first = Double(text[firstRange]),
              let second = Double(text[secondRange])
        else { return nil }
        text.replaceSubrange(range, with: " ")
        return (first, second)
    }

    static func firstMatch(in text: String, pattern: String) -> (Range<String.Index>, String)? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: nsRange),
              let range = Range(match.range, in: text)
        else { return nil }
        let captureIndex = match.numberOfRanges > 1 ? 1 : 0
        guard let captureRange = Range(match.range(at: captureIndex), in: text) else { return nil }
        return (range, String(text[captureRange]))
    }
}
