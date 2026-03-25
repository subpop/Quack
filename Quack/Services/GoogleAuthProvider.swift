import Foundation

/// Manages Google OAuth2 tokens from Application Default Credentials (ADC).
///
/// Reads `~/.config/gcloud/application_default_credentials.json` (created by
/// `gcloud auth application-default login`) and transparently refreshes access
/// tokens as needed.
///
/// Thread-safe via `actor` isolation -- only one refresh request can be in
/// flight at a time.
actor GoogleAuthProvider: Sendable {
    // MARK: - ADC Credential File

    private struct ADCCredentials: Decodable {
        let type: String
        let clientId: String
        let clientSecret: String
        let refreshToken: String

        enum CodingKeys: String, CodingKey {
            case type
            case clientId = "client_id"
            case clientSecret = "client_secret"
            case refreshToken = "refresh_token"
        }
    }

    // MARK: - Token Response

    private struct TokenResponse: Decodable {
        let accessToken: String
        let expiresIn: Int
        let tokenType: String

        enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
            case expiresIn = "expires_in"
            case tokenType = "token_type"
        }
    }

    // MARK: - Errors

    enum AuthError: Error, LocalizedError {
        case credentialsFileNotFound(path: String)
        case unsupportedCredentialType(String)
        case refreshFailed(statusCode: Int, body: String)
        case decodingFailed(Error)

        var errorDescription: String? {
            switch self {
            case .credentialsFileNotFound(let path):
                "Google ADC credentials not found at \(path). Run `gcloud auth application-default login`."
            case .unsupportedCredentialType(let type):
                "Unsupported ADC credential type: \(type). Only 'authorized_user' is supported."
            case .refreshFailed(let code, let body):
                "Token refresh failed (HTTP \(code)): \(body)"
            case .decodingFailed(let error):
                "Failed to decode ADC credentials: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - State

    private let clientID: String
    private let clientSecret: String
    private let refreshToken: String
    private let session: URLSession

    private var cachedAccessToken: String?
    private var tokenExpiry: Date?

    /// Refresh the token when it has fewer than this many seconds remaining.
    private let refreshMargin: TimeInterval = 300  // 5 minutes

    private static let tokenEndpoint = URL(string: "https://oauth2.googleapis.com/token")!

    // MARK: - Init

    /// Creates an auth provider by reading the ADC file at the default path.
    init(session: URLSession = .shared) throws {
        let path = Self.defaultCredentialsPath()
        guard FileManager.default.fileExists(atPath: path) else {
            throw AuthError.credentialsFileNotFound(path: path)
        }
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let credentials: ADCCredentials
        do {
            credentials = try JSONDecoder().decode(ADCCredentials.self, from: data)
        } catch {
            throw AuthError.decodingFailed(error)
        }
        guard credentials.type == "authorized_user" else {
            throw AuthError.unsupportedCredentialType(credentials.type)
        }
        self.clientID = credentials.clientId
        self.clientSecret = credentials.clientSecret
        self.refreshToken = credentials.refreshToken
        self.session = session
    }

    // MARK: - Public API

    /// Returns a valid access token, refreshing if necessary.
    func accessToken() async throws -> String {
        if let token = cachedAccessToken,
           let expiry = tokenExpiry,
           Date() < expiry.addingTimeInterval(-refreshMargin) {
            return token
        }
        return try await refreshAccessToken()
    }

    // MARK: - Private

    private func refreshAccessToken() async throws -> String {
        var request = URLRequest(url: Self.tokenEndpoint)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body = [
            "client_id=\(urlEncode(clientID))",
            "client_secret=\(urlEncode(clientSecret))",
            "refresh_token=\(urlEncode(refreshToken))",
            "grant_type=refresh_token",
        ].joined(separator: "&")
        request.httpBody = Data(body.utf8)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.refreshFailed(statusCode: 0, body: "Invalid response")
        }
        guard httpResponse.statusCode == 200 else {
            let responseBody = String(data: data, encoding: .utf8) ?? "<unreadable>"
            throw AuthError.refreshFailed(statusCode: httpResponse.statusCode, body: responseBody)
        }

        let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
        cachedAccessToken = tokenResponse.accessToken
        tokenExpiry = Date().addingTimeInterval(TimeInterval(tokenResponse.expiresIn))
        return tokenResponse.accessToken
    }

    private func urlEncode(_ string: String) -> String {
        string.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? string
    }

    static func defaultCredentialsPath() -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return "\(home)/.config/gcloud/application_default_credentials.json"
    }

    /// Whether an ADC credentials file exists at the default path.
    static func credentialsAvailable() -> Bool {
        FileManager.default.fileExists(atPath: defaultCredentialsPath())
    }
}
