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
            return .sample
        }
        let data = try Data(contentsOf: fileURL)
        let document = try Self.decoder.decode(SetlineDocument.self, from: data)
        guard document.schemaVersion == 1 else {
            throw SetlineError.unsupportedSchema(document.schemaVersion)
        }
        return document
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
        let document = try Self.decoder.decode(SetlineDocument.self, from: data)
        guard document.schemaVersion == 1 else {
            throw SetlineError.unsupportedSchema(document.schemaVersion)
        }
        return document
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
