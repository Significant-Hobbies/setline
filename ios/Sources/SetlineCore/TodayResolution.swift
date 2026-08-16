import Foundation

/// What the programme prescribes for one calendar day.
public struct ResolvedSession: Equatable, Sendable {
    public var template: WorkoutTemplate
    public var programmeWeek: Int?
    public var programmeDayIndex: Int?
    /// "Week 3 · Tuesday · Lower", or the template name for ad-hoc work.
    public var subtitle: String
    public var notes: [String]
    /// True when the programme is running but this day has no session.
    public var isRestDay: Bool
    /// Set when the calendar sits outside a dated block, so Today can say so
    /// rather than silently showing week 1.
    public var outOfBlockNotice: String?

    public init(
        template: WorkoutTemplate,
        programmeWeek: Int? = nil,
        programmeDayIndex: Int? = nil,
        subtitle: String,
        notes: [String] = [],
        isRestDay: Bool = false,
        outOfBlockNotice: String? = nil
    ) {
        self.template = template
        self.programmeWeek = programmeWeek
        self.programmeDayIndex = programmeDayIndex
        self.subtitle = subtitle
        self.notes = notes
        self.isRestDay = isRestDay
        self.outOfBlockNotice = outOfBlockNotice
    }
}

public extension SetlineDocument {
    /// Resolves the session for a date from whichever programme is active.
    ///
    /// Returns nil only when there is nothing at all to offer: no programme and
    /// no templates. A rest day returns a session marked `isRestDay` so the
    /// caller can show the plan honestly instead of inventing a workout.
    func session(on date: Date = .now, calendar: Calendar = .current) -> ResolvedSession? {
        switch programme {
        case let .bundled(id):
            return bundledSession(id: id, on: date, calendar: calendar)
        case let .custom(programme):
            return customSession(programme: programme, on: date, calendar: calendar)
        case .none:
            guard let first = templates.first else { return nil }
            return ResolvedSession(
                template: first,
                subtitle: first.detail.isEmpty ? "Unscheduled" : first.detail,
                notes: first.notes
            )
        }
    }

    private func bundledSession(
        id: BundledProgrammeID,
        on date: Date,
        calendar: Calendar
    ) -> ResolvedSession {
        switch id {
        case .twelveWeekStrengthCardioMobility:
            let position = TwelveWeekProgramme.position(for: date, calendar: calendar)
            var notice: String?
            if position.beforeBlock {
                let start = TwelveWeekProgramme.startDate(calendar: calendar)
                notice = "The block starts \(start.formatted(date: .abbreviated, time: .omitted)). This is week 1, day 1 as a preview."
            } else if position.afterBlock {
                notice = "The block finished on 18 October 2026. This shows the final week; review it before starting another."
            }
            return ResolvedSession(
                template: position.template,
                programmeWeek: position.weekNumber,
                programmeDayIndex: position.dayIndex,
                subtitle: "Week \(position.weekNumber) of \(TwelveWeekProgramme.weekCount) · \(weekdayName(position.dayIndex, calendar: calendar)) · \(position.schedule.title)",
                notes: position.template.notes,
                outOfBlockNotice: notice
            )
        }
    }

    private func customSession(
        programme: CustomProgramme,
        on date: Date,
        calendar: Calendar
    ) -> ResolvedSession? {
        let weekday = calendar.component(.weekday, from: date)
        let assigned = programme.days.first { $0.weekday == weekday }?.templateID
        guard programme.enabled else {
            guard let first = templates.first else { return nil }
            return ResolvedSession(
                template: first,
                subtitle: "\(programme.name) is paused",
                notes: first.notes
            )
        }
        guard let assigned else {
            return ResolvedSession(
                template: WorkoutTemplate(name: "Rest day", detail: "No session scheduled", isBundled: false, exercises: []),
                subtitle: "\(programme.name) · rest day",
                isRestDay: true
            )
        }
        guard let template = templates.first(where: { $0.id == assigned }) else {
            guard let first = templates.first else { return nil }
            return ResolvedSession(
                template: first,
                subtitle: "\(programme.name) · assigned workout unavailable",
                notes: first.notes
            )
        }
        return ResolvedSession(
            template: template,
            subtitle: "\(programme.name) · \(template.name)",
            notes: template.notes
        )
    }

    /// The seven days of the current programme week, for the Today strip.
    func week(containing date: Date = .now, calendar: Calendar = .current) -> [ResolvedSession?] {
        switch programme {
        case let .bundled(id):
            switch id {
            case .twelveWeekStrengthCardioMobility:
                let position = TwelveWeekProgramme.position(for: date, calendar: calendar)
                let mondayOffset = (position.weekNumber - 1) * 7
                let start = calendar.startOfDay(for: TwelveWeekProgramme.startDate(calendar: calendar))
                return (0..<7).map { index in
                    guard let day = calendar.date(byAdding: .day, value: mondayOffset + index, to: start) else {
                        return nil
                    }
                    return bundledSession(id: id, on: day, calendar: calendar)
                }
            }
        case .custom, .none:
            guard let sunday = calendar.dateInterval(of: .weekOfYear, for: date)?.start else {
                return Array(repeating: nil, count: 7)
            }
            return (0..<7).map { index in
                guard let day = calendar.date(byAdding: .day, value: index, to: sunday) else { return nil }
                return session(on: day, calendar: calendar)
            }
        }
    }

    private func weekdayName(_ dayIndex: Int, calendar: Calendar) -> String {
        // dayIndex is Monday-based; weekdaySymbols is Sunday-first.
        let symbols = calendar.weekdaySymbols
        guard symbols.count == 7 else { return "" }
        return symbols[(dayIndex + 1) % 7]
    }
}
