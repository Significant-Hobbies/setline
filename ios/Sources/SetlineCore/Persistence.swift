import Foundation

public actor SetlineStore {
    public let fileURL: URL

    public init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            self.fileURL = base.appending(path: "Setline", directoryHint: .isDirectory)
                .appending(path: "setline-v1.json")
        }
    }

    public func load() throws -> SetlineDocument {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return .initial
        }
        let data = try Data(contentsOf: fileURL)
        return try Self.migrate(Self.decoder.decode(SetlineDocument.self, from: data))
    }

    /// Brings a decoded document up to the current schema.
    ///
    /// Version 1 stored free-text targets, scalar rest and a bare custom
    /// programme; the decoders in `Domain` absorb those shapes, so migration only
    /// has to stamp the version and backfill catalogue links.
    static func migrate(_ document: SetlineDocument) throws -> SetlineDocument {
        guard document.schemaVersion <= SetlineDocument.currentSchemaVersion else {
            throw SetlineError.unsupportedSchema(document.schemaVersion)
        }
        guard document.schemaVersion < SetlineDocument.currentSchemaVersion else { return document }
        var migrated = document
        migrated.schemaVersion = SetlineDocument.currentSchemaVersion
        migrated.templates = migrated.templates.map(linkCatalogue(in:))
        migrated.history = migrated.history.map(linkCatalogue(in:))
        if let active = migrated.activeSession { migrated.activeSession = linkCatalogue(in: active) }
        return migrated
    }

    /// Resolves recorded exercise names to catalogue slugs so historic sessions
    /// contribute to the same measurements as new ones.
    static func linkCatalogue(in template: WorkoutTemplate) -> WorkoutTemplate {
        var result = template
        result.exercises = result.exercises.map { exercise in
            guard exercise.definitionSlug == nil,
                  let definition = ExerciseCatalogue.match(name: exercise.name)
            else { return exercise }
            var linked = exercise
            linked.definitionSlug = definition.slug
            linked.pillars = definition.pillars
            return linked
        }
        return result
    }

    static func linkCatalogue(in session: WorkoutSession) -> WorkoutSession {
        var result = session
        result.steps = result.steps.map { step in
            guard step.exerciseSlug == nil,
                  let definition = ExerciseCatalogue.match(name: step.exerciseName)
            else { return step }
            var linked = step
            linked.exerciseSlug = definition.slug
            linked.pillars = definition.pillars
            return linked
        }
        return result
    }

    public func save(_ document: SetlineDocument) throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try Self.encoder.encode(document)
        try data.write(to: fileURL, options: [.atomic, .completeFileProtectionUnlessOpen])
    }

    public func export(_ document: SetlineDocument) throws -> Data {
        try Self.encoder.encode(document)
    }

    public func previewImport(_ data: Data) throws -> SetlineDocument {
        try Self.migrate(Self.decoder.decode(SetlineDocument.self, from: data))
    }

    public func replace(with document: SetlineDocument) throws {
        try save(document)
    }

    public func reset() throws {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        try FileManager.default.removeItem(at: fileURL)
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
