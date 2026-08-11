import AuthenticationServices
import Foundation
import Security
import SetlineCore
import UIKit

struct SetlineAccount: Equatable, Sendable {
    let name: String
    let email: String
}

enum NativeAccountError: LocalizedError {
    case invalidCallback
    case missingSession
    case conflict(SetlineCloudSnapshot)
    case server(String)
    case http(Int, String)

    var errorDescription: String? {
        switch self {
        case .invalidCallback:
            "Setline could not verify the sign-in handoff."
        case .missingSession:
            "Your Setline session expired. Sign in again."
        case .conflict:
            "A newer account copy needs your decision."
        case let .server(message), let .http(_, message):
            message
        }
    }
}

actor SetlineKeychainSessionStore {
    private let service: String
    private let account: String

    init(
        service: String = "com.significanthobbies.setline.session",
        account: String = "better-auth-bearer"
    ) {
        self.service = service
        self.account = account
    }

    func load() throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else {
            throw NativeAccountError.server("Setline could not read the secure session.")
        }
        return String(data: data, encoding: .utf8)
    }

    func save(_ token: String) throws {
        let data = Data(token.utf8)
        let identity: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        let updateStatus = SecItemUpdate(identity as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecItemNotFound {
            var insertion = identity
            insertion.merge(attributes) { _, replacement in replacement }
            guard SecItemAdd(insertion as CFDictionary, nil) == errSecSuccess else {
                throw NativeAccountError.server("Setline could not store the secure session.")
            }
        } else if updateStatus != errSecSuccess {
            throw NativeAccountError.server("Setline could not update the secure session.")
        }
    }

    func delete() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw NativeAccountError.server("Setline could not remove the secure session.")
        }
    }
}

actor SetlineNativeAccountClient {
    static let productionBaseURL = URL(string: "https://setline.significanthobbies.com")!

    private let baseURL: URL
    private let urlSession: URLSession
    private let sessionStore: SetlineKeychainSessionStore

    init(
        baseURL: URL = productionBaseURL,
        urlSession: URLSession = .shared,
        sessionStore: SetlineKeychainSessionStore = SetlineKeychainSessionStore()
    ) {
        self.baseURL = baseURL
        self.urlSession = urlSession
        self.sessionStore = sessionStore
    }

    var googleStartURL: URL {
        var components = URLComponents(
            url: endpoint("/api/native/auth/google/start"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [URLQueryItem(name: "callback", value: "setline://auth")]
        return components.url!
    }

    func restoreAccount() async throws -> SetlineAccount? {
        guard try await sessionStore.load() != nil else { return nil }
        do {
            return try await account()
        } catch {
            try? await sessionStore.delete()
            throw error
        }
    }

    func exchangeHandoff(_ code: String) async throws -> SetlineAccount {
        let response = try await request(
            path: "/api/native/auth/exchange",
            body: ["code": code],
            authenticated: false
        )
        let payload = try JSONDecoder().decode(TokenResponse.self, from: response.data)
        try await sessionStore.save(payload.token)
        return try await account()
    }

    func fetchState() async throws -> SetlineCloudSnapshot? {
        let response = try await request(path: "/api/native/state", method: "GET")
        return try decoder.decode(StateResponse.self, from: response.data).state
    }

    func pushState(
        _ document: SetlineCloudDocument,
        baseRevision: Int?
    ) async throws -> SetlineCloudSnapshot {
        let body = StateWrite(document: document, baseRevision: baseRevision)
        let response = try await request(path: "/api/native/state", method: "PUT", encodableBody: body)
        let payload = try decoder.decode(StateResponse.self, from: response.data)
        guard let state = payload.state else {
            throw NativeAccountError.server("Setline did not return the saved account copy.")
        }
        return state
    }

    func signOut() async {
        _ = try? await request(path: "/api/auth/sign-out", body: [String: String]())
        try? await sessionStore.delete()
    }

    func deleteAccount() async throws {
        _ = try await request(path: "/api/auth/delete-user", body: [String: String]())
        try await sessionStore.delete()
    }

    private func account() async throws -> SetlineAccount {
        let response = try await request(path: "/api/auth/get-session", method: "GET")
        let session = try decoder.decode(SessionResponse.self, from: response.data)
        return SetlineAccount(name: session.user.name, email: session.user.email)
    }

    private func request(
        path: String,
        method: String = "POST",
        body: [String: String],
        authenticated: Bool = true
    ) async throws -> NetworkResponse {
        try await request(
            path: path,
            method: method,
            data: try JSONEncoder().encode(body),
            authenticated: authenticated
        )
    }

    private func request<T: Encodable>(
        path: String,
        method: String,
        encodableBody: T
    ) async throws -> NetworkResponse {
        try await request(
            path: path,
            method: method,
            data: try encoder.encode(encodableBody),
            authenticated: true
        )
    }

    private func request(
        path: String,
        method: String,
        data: Data? = nil,
        authenticated: Bool = true
    ) async throws -> NetworkResponse {
        var request = URLRequest(url: endpoint(path))
        request.httpMethod = method
        request.httpBody = data
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if data != nil { request.setValue("application/json", forHTTPHeaderField: "Content-Type") }
        if authenticated {
            guard let token = try await sessionStore.load() else {
                throw NativeAccountError.missingSession
            }
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let (responseData, rawResponse) = try await urlSession.data(for: request)
        guard let response = rawResponse as? HTTPURLResponse else {
            throw NativeAccountError.server("Setline received an invalid server response.")
        }
        if response.statusCode == 409,
           let conflict = try? decoder.decode(StateResponse.self, from: responseData).state {
            throw NativeAccountError.conflict(conflict)
        }
        guard (200..<300).contains(response.statusCode) else {
            let message = (try? decoder.decode(ErrorResponse.self, from: responseData).message)
                ?? "Setline account service is unavailable."
            if response.statusCode == 401 { throw NativeAccountError.missingSession }
            throw NativeAccountError.http(response.statusCode, message)
        }
        return NetworkResponse(data: responseData, response: response)
    }

    private func endpoint(_ path: String) -> URL {
        baseURL.appending(path: path.trimmingCharacters(in: CharacterSet(charactersIn: "/")))
    }

    private var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

@MainActor
final class SetlineWebAuthenticator: NSObject, ASWebAuthenticationPresentationContextProviding {
    private var session: ASWebAuthenticationSession?

    func authenticate(at url: URL) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: "setline"
            ) { callbackURL, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard
                    let callbackURL,
                    callbackURL.scheme == "setline",
                    callbackURL.host == "auth",
                    let code = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?
                        .queryItems?.first(where: { $0.name == "code" })?.value
                else {
                    continuation.resume(throwing: NativeAccountError.invalidCallback)
                    return
                }
                continuation.resume(returning: code)
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            self.session = session
            guard session.start() else {
                continuation.resume(throwing: NativeAccountError.server("Setline could not open sign in."))
                return
            }
        }
    }

    func presentationAnchor(for _: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow) ?? ASPresentationAnchor()
    }
}

private struct TokenResponse: Decodable { let token: String }
private struct SessionResponse: Decodable { let user: SessionUser }
private struct SessionUser: Decodable { let name: String; let email: String }
private struct ErrorResponse: Decodable { let message: String }
private struct StateResponse: Decodable { let state: SetlineCloudSnapshot? }
private struct StateWrite: Encodable {
    let document: SetlineCloudDocument
    let baseRevision: Int?

    private enum CodingKeys: String, CodingKey { case document, baseRevision }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(document, forKey: .document)
        if let baseRevision {
            try container.encode(baseRevision, forKey: .baseRevision)
        } else {
            try container.encodeNil(forKey: .baseRevision)
        }
    }
}
private struct NetworkResponse { let data: Data; let response: HTTPURLResponse }
