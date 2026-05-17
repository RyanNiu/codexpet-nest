import Foundation

// MARK: - Response Types (spec-compliant)

struct DesktopVersionResponse: Codable, Equatable {
    let platform: String
    let latestVersion: String
    let buildVersion: String
    let downloadUrl: String?
    let sha256: String?
    let releaseNotesUrl: String?
    let minimumSupportedVersion: String
    let minimumSystemVersion: String
}

// MARK: - API DTOs (Data Transfer Objects for codexpet.xyz)

struct APIPet: Codable {
    let slug: String
    let display_name: String?
    let author_name: String?
    let description: String?
    let version: String?
    let tags_json: String?
    let download_count: Int?
    let published_at: String?
    let spritesheetUrl: String?
    let downloadUrl: String?
    let detailUrl: String?
    let sha256: String?
    let license: String?
    let updated_at: String?
    let animations_json: String?

    func toPetItem(baseURL: String) -> PetItem {
        PetItem(
            id: slug,
            name: display_name ?? slug,
            version: version ?? "1.0.0",
            author: author_name ?? "Unknown",
            description: description ?? "",
            previewUrl: normalizeURL(spritesheetUrl, baseURL: baseURL),
            tags: parseTags(tags_json),
            detailUrl: normalizeURL(detailUrl, baseURL: baseURL)
        )
    }

    func toPetDetail(baseURL: String) -> PetDetail {
        PetDetail(
            id: slug,
            name: display_name ?? slug,
            version: version ?? "1.0.0",
            author: author_name ?? "Unknown",
            description: description ?? "",
            previewUrl: normalizeURL(spritesheetUrl, baseURL: baseURL),
            tags: parseTags(tags_json),
            license: license ?? "MIT",
            downloads: download_count ?? 0,
            updatedAt: updated_at ?? published_at ?? "",
            detailUrl: normalizeURL(detailUrl, baseURL: baseURL),
            animations: {
                guard let json = animations_json, let data = json.data(using: .utf8) else { return nil }
                return try? JSONDecoder().decode([String: PetAnimationConfig].self, from: data)
            }()
        )
    }
    
    func toDownloadMeta(baseURL: String) -> PetDownloadMeta {
        PetDownloadMeta(
            id: slug,
            version: version ?? "1.0.0",
            url: normalizeURL(downloadUrl, baseURL: baseURL),
            sha256: sha256,
            size: nil,
            contentType: "application/zip"
        )
    }
}

struct PetsAPIResponse: Codable {
    let pets: [APIPet]
    let pagination: APIPagination
}

struct PetAPIWrapper: Codable {
    let pet: APIPet
}

struct APINest: Codable {
    let slug: String
    let display_name: String?
    let author_name: String?
    let description: String?
    let version: String?
    let tags_json: String?
    let download_count: Int?
    let published_at: String?
    let previewUrl: String?
    let downloadUrl: String?
    let detailUrl: String?
    let sha256: String?
    let license: String?
    let updated_at: String?
    let layout: String?
    let widgets_json: String?

    func toNestItem(baseURL: String) -> NestItem {
        NestItem(
            id: slug,
            name: display_name ?? slug,
            version: version ?? "1.0.0",
            author: author_name ?? "Unknown",
            description: description ?? "",
            previewUrl: normalizeURL(previewUrl, baseURL: baseURL),
            tags: parseTags(tags_json),
            detailUrl: normalizeURL(detailUrl, baseURL: baseURL)
        )
    }

    func toNestDetail(baseURL: String) -> NestDetail {
        NestDetail(
            id: slug,
            name: display_name ?? slug,
            version: version ?? "1.0.0",
            author: author_name ?? "Unknown",
            description: description ?? "",
            layout: layout ?? "default",
            widgets: parseTags(widgets_json), // Reuse tag parser for widgets array
            previewUrl: normalizeURL(previewUrl, baseURL: baseURL),
            tags: parseTags(tags_json),
            license: license ?? "MIT",
            downloads: download_count ?? 0,
            updatedAt: updated_at ?? published_at ?? ""
        )
    }

    func toDownloadMeta(baseURL: String) -> NestDownloadMeta {
        NestDownloadMeta(
            id: slug,
            version: version ?? "1.0.0",
            url: normalizeURL(downloadUrl, baseURL: baseURL),
            sha256: sha256,
            size: nil,
            contentType: "application/zip"
        )
    }
}

struct NestsAPIResponse: Codable {
    let nests: [APINest]
    let pagination: APIPagination
}

struct NestAPIWrapper: Codable {
    let nest: APINest
}

struct APIPagination: Codable {
    let currentPage: Int
    let limit: Int
    let totalItems: Int
}

struct PetDownloadMetaDTO: Codable {
    let id: String?
    let slug: String?
    let version: String?
    let url: String?
    let downloadUrl: String?
    let sha256: String?
    let size: Int?
    let contentType: String?

    func toPetDownloadMeta(baseURL: String) -> PetDownloadMeta {
        PetDownloadMeta(
            id: slug ?? id ?? "unknown",
            version: version ?? "1.0.0",
            url: normalizeURL(downloadUrl ?? url, baseURL: baseURL),
            sha256: sha256,
            size: size,
            contentType: contentType ?? "application/zip"
        )
    }

    func toNestDownloadMeta(baseURL: String) -> NestDownloadMeta {
        NestDownloadMeta(
            id: slug ?? id ?? "unknown",
            version: version ?? "1.0.0",
            url: normalizeURL(downloadUrl ?? url, baseURL: baseURL),
            sha256: sha256,
            size: size,
            contentType: contentType ?? "application/zip"
        )
    }
}

private func parseTags(_ json: String?) -> [String] {
    guard let json = json, !json.isEmpty else { return [] }
    guard let data = json.data(using: .utf8) else { return [] }
    return (try? JSONDecoder().decode([String].self, from: data)) ?? []
}

private func normalizeURL(_ path: String?, baseURL: String) -> String {
    guard let path = path, !path.isEmpty else { return "" }
    if path.hasPrefix("http") { return path }
    let separator = path.hasPrefix("/") ? "" : "/"
    return "\(baseURL)\(separator)\(path)"
}

// MARK: - UI Models

struct PetItem: Codable, Equatable, Identifiable {
    let id: String
    let name: String
    let version: String
    let author: String
    let description: String
    let previewUrl: String
    let tags: [String]
    let detailUrl: String
}

struct PetListResponse: Codable, Equatable {
    let items: [PetItem]
    let page: Int
    let pageSize: Int
    let total: Int
}

struct PetDetail: Codable, Equatable, Identifiable {
    let id: String
    let name: String
    let version: String
    let author: String
    let description: String
    let previewUrl: String
    let tags: [String]
    let license: String
    let downloads: Int
    let updatedAt: String
    let detailUrl: String
    let animations: [String: PetAnimationConfig]?
}

struct PetDownloadMeta: Codable, Equatable {
    let id: String
    let version: String
    let url: String
    let sha256: String?
    let size: Int?
    let contentType: String
}

struct NestItem: Codable, Equatable, Identifiable {
    let id: String
    let name: String
    let version: String
    let author: String
    let description: String
    let previewUrl: String
    let tags: [String]
    let detailUrl: String
}

struct NestListResponse: Codable, Equatable {
    let items: [NestItem]
    let page: Int
    let pageSize: Int
    let total: Int
}

struct NestDetail: Codable, Equatable, Identifiable {
    let id: String
    let name: String
    let version: String
    let author: String
    let description: String
    let layout: String
    let widgets: [String]
    let previewUrl: String
    let tags: [String]
    let license: String
    let downloads: Int
    let updatedAt: String
}

struct NestDownloadMeta: Codable, Equatable {
    let id: String
    let version: String
    let url: String
    let sha256: String?
    let size: Int?
    let contentType: String
}

struct DeviceCodeResponse: Codable, Equatable {
    let deviceCode: String
    let userCode: String
    let verificationUri: String
    let verificationUriComplete: String
    let expiresIn: Int
    let interval: Int
}

struct TokenPollResponse: Codable, Equatable {
    let status: String?
    let accessToken: String?
    let refreshToken: String?
    let tokenType: String?
    let expiresIn: Int?
}

struct UploadResponse: Codable, Equatable {
    let uploadId: String
    let status: String
    let detailUrl: String
}

struct UploadStatusResponse: Codable, Equatable {
    let id: String
    let status: String
    let resourceType: String?
    let createdAt: String?
    let reviewNotes: String?
}

struct APIError: Codable, Equatable {
    let code: String
    let message: String
}

struct APIErrorResponse: Codable, Equatable {
    let error: APIError
}

// MARK: - API Client Errors

enum CodexPetAPIError: Error, LocalizedError {
    case invalidURL
    case networkError(Error)
    case httpError(statusCode: Int, apiError: APIError?)
    case decodingError(Error)
    case unauthorized

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL"
        case .networkError(let err):
            return "Network error: \(err.localizedDescription)"
        case .httpError(let code, let apiErr):
            return apiErr?.message ?? "HTTP \(code)"
        case .decodingError(let err):
            return "Failed to parse response: \(err.localizedDescription)"
        case .unauthorized:
            return "Authentication required"
        }
    }
}

// MARK: - API Client

final class CodexPetAPI {
    static let shared = CodexPetAPI()

    private let baseURL: String
    private let session: URLSession
    private let decoder: JSONDecoder

    private init(baseURL: String = ProcessInfo.processInfo.environment["CODEXPET_API_BASE_URL"] ?? "https://codexpet.xyz") {
        self.baseURL = baseURL
        print("[CodexPetAPI] baseURL =", self.baseURL)
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 120
        self.session = URLSession(configuration: config)
        self.decoder = JSONDecoder()
    }

    // MARK: - Helpers

    private func url(_ path: String, query: [String: String] = [:]) -> URL? {
        guard var comps = URLComponents(string: "\(baseURL)\(path)") else { return nil }
        if !query.isEmpty {
            comps.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        return comps.url
    }

    private func get<T: Codable>(_ path: String, query: [String: String] = [:], token: String? = nil) async throws -> T {
        guard let u = url(path, query: query) else { throw CodexPetAPIError.invalidURL }
        var req = URLRequest(url: u)
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return try await perform(req)
    }

    private func post<Body: Codable, T: Codable>(_ path: String, body: Body, token: String? = nil) async throws -> T {
        guard let u = url(path) else { throw CodexPetAPIError.invalidURL }
        var req = URLRequest(url: u)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        req.httpBody = try JSONEncoder().encode(body)
        return try await perform(req)
    }

    private func perform<T: Codable>(_ request: URLRequest) async throws -> T {
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw CodexPetAPIError.networkError(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw CodexPetAPIError.httpError(statusCode: 0, apiError: nil)
        }

        if http.statusCode == 401 {
            throw CodexPetAPIError.unauthorized
        }

        if http.statusCode >= 400 {
            let apiErr = try? decoder.decode(APIErrorResponse.self, from: data)
            throw CodexPetAPIError.httpError(statusCode: http.statusCode, apiError: apiErr?.error)
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw CodexPetAPIError.decodingError(error)
        }
    }

    // MARK: - Desktop Version

    func getVersion() async throws -> DesktopVersionResponse {
        try await get("/api/desktop/version")
    }

    // MARK: - Pets

    func listPets(search: String? = nil, tag: String? = nil, sort: String? = nil, page: Int = 1, limit: Int = 10) async throws -> PetListResponse {
        var query: [String: String] = ["page": String(page), "limit": String(limit)]
        if let s = search, !s.isEmpty { query["search"] = s }
        if let t = tag, !t.isEmpty { query["tag"] = t }
        if let s = sort, !s.isEmpty { query["sort"] = s }
        
        let response: PetsAPIResponse = try await get("/api/pets", query: query)
        let items = response.pets.map { $0.toPetItem(baseURL: baseURL) }
        return PetListResponse(
            items: items,
            page: response.pagination.currentPage,
            pageSize: response.pagination.limit,
            total: response.pagination.totalItems
        )
    }

    func getPet(id: String) async throws -> PetDetail {
        let wrapper: PetAPIWrapper = try await get("/api/pets/\(id)")
        return wrapper.pet.toPetDetail(baseURL: baseURL)
    }

    func getPetDownload(id: String) async throws -> PetDownloadMeta {
        let dto: PetDownloadMetaDTO = try await get("/api/pets/\(id)/download")
        return dto.toPetDownloadMeta(baseURL: baseURL)
    }

    // MARK: - Nests

    func listNests(search: String? = nil, tag: String? = nil, sort: String? = nil, page: Int = 1) async throws -> NestListResponse {
        var query: [String: String] = ["page": String(page)]
        if let s = search, !s.isEmpty { query["search"] = s }
        if let t = tag, !t.isEmpty { query["tag"] = t }
        if let s = sort, !s.isEmpty { query["sort"] = s }
        
        let response: NestsAPIResponse = try await get("/api/nests", query: query)
        let items = response.nests.map { $0.toNestItem(baseURL: baseURL) }
        return NestListResponse(
            items: items,
            page: response.pagination.currentPage,
            pageSize: response.pagination.limit,
            total: response.pagination.totalItems
        )
    }

    func getNest(id: String) async throws -> NestDetail {
        let wrapper: NestAPIWrapper = try await get("/api/nests/\(id)")
        return wrapper.nest.toNestDetail(baseURL: baseURL)
    }

    func getNestDownload(id: String) async throws -> NestDownloadMeta {
        let dto: PetDownloadMetaDTO = try await get("/api/nests/\(id)/download")
        return dto.toNestDownloadMeta(baseURL: baseURL)
    }

    // MARK: - Auth

    func createDeviceCode(client: String = "codexpet-nest", platform: String = "macos") async throws -> DeviceCodeResponse {
        struct Body: Codable { let client: String; let platform: String }
        return try await post("/api/auth/device-code", body: Body(client: client, platform: platform))
    }

    func pollToken(deviceCode: String) async throws -> TokenPollResponse {
        struct Body: Codable {
            let grantType: String
            let deviceCode: String
            enum CodingKeys: String, CodingKey {
                case grantType
                case deviceCode
            }
        }
        return try await post("/api/auth/token", body: Body(grantType: "urn:ietf:params:oauth:grant-type:device_code", deviceCode: deviceCode))
    }

    // MARK: - Uploads

    func createUpload(token: String, name: String, description: String, author: String, license: String, tags: [String] = [], zipData: Data) async throws -> UploadResponse {
        // This endpoint uses multipart upload, so we handle it specially
        guard let u = url("/api/uploads/pets") else { throw CodexPetAPIError.invalidURL }

        let boundary = "CodexPetBoundary\(UUID().uuidString)"
        var body = Data()

        func appendField(_ name: String, _ value: String) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }

        appendField("name", name)
        appendField("description", description)
        appendField("author", author)
        appendField("license", license)
        if let tagsData = try? JSONEncoder().encode(tags),
           let tagsStr = String(data: tagsData, encoding: .utf8) {
            appendField("tags", tagsStr)
        }

        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"package\"; filename=\"pet.zip\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: application/zip\r\n\r\n".data(using: .utf8)!)
        body.append(zipData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        var req = URLRequest(url: u)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.httpBody = body

        return try await perform(req)
    }

    func getUploadStatus(token: String, uploadId: String) async throws -> UploadStatusResponse {
        try await get("/api/uploads/\(uploadId)", token: token)
    }

    // MARK: - Desktop Nest Runtime API

    func resolveInstallIntent(token: String) async throws -> InstallIntentResponse {
        let intent: InstallIntentResponse = try await get("/api/desktop/install-intents/\(token)")
        return InstallIntentResponse(
            runtimeToken: intent.runtimeToken,
            runtimeManifestUrl: normalizeURL(intent.runtimeManifestUrl, baseURL: baseURL),
            nestId: intent.nestId,
            version: intent.version
        )
    }

    func getRuntimeManifest(url: String) async throws -> RuntimeManifest {
        let resolved = normalizeURL(url, baseURL: baseURL)
        guard let u = URL(string: resolved) else { throw CodexPetAPIError.invalidURL }
        var req = URLRequest(url: u)
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        let manifest = try await perform(req) as RuntimeManifest

        return RuntimeManifest(
            type: manifest.type,
            id: manifest.id,
            version: manifest.version,
            title: manifest.title,
            schemaVersion: manifest.schemaVersion,
            layout: RuntimeLayoutRef(
                url: normalizeURL(manifest.layout.url, baseURL: baseURL),
                sha256: manifest.layout.sha256,
                size: manifest.layout.size
            ),
            assets: manifest.assets.map { asset in
                RuntimeAsset(
                    path: asset.path,
                    url: normalizeURL(asset.url, baseURL: baseURL),
                    sha256: asset.sha256,
                    contentType: asset.contentType,
                    size: asset.size
                )
            },
            metricCatalog: manifest.metricCatalog.map {
                RuntimeRegistryRef(
                    version: $0.version,
                    url: normalizeURL($0.url, baseURL: baseURL),
                    sha256: $0.sha256
                )
            },
            componentRegistry: manifest.componentRegistry.map {
                RuntimeRegistryRef(
                    version: $0.version,
                    url: normalizeURL($0.url, baseURL: baseURL),
                    sha256: $0.sha256
                )
            },
            componentRegistryVersion: manifest.componentRegistryVersion,
            expiresAt: manifest.expiresAt,
            preview: manifest.preview
        )
    }

    func downloadRegistry(url: String) async throws -> Data {
        return try await downloadData(url: url, accept: "application/json")
    }

    func downloadLayout(url: String) async throws -> Data {
        return try await downloadData(url: url, accept: "application/json")
    }

    func downloadAsset(url: String) async throws -> Data {
        return try await downloadData(url: url, accept: "*/*")
    }

    func completeInstall(nestId: String, runtimeToken: String) async throws {
        struct Body: Codable { let runtimeToken: String }
        let response: InstallCompleteResponse = try await post(
            "/api/desktop/nests/\(nestId)/install-complete",
            body: Body(runtimeToken: runtimeToken)
        )
        guard response.ok else {
            throw CodexPetAPIError.httpError(statusCode: 502, apiError: APIError(code: "INSTALL_COMPLETE_FAILED", message: "Server returned ok: false"))
        }
    }

    // MARK: - Raw Download

    private func downloadData(url: String, accept: String) async throws -> Data {
        let resolved = normalizeURL(url, baseURL: baseURL)
        guard let u = URL(string: resolved) else { throw CodexPetAPIError.invalidURL }
        var req = URLRequest(url: u)
        req.setValue(accept, forHTTPHeaderField: "Accept")

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: req)
        } catch {
            throw CodexPetAPIError.networkError(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw CodexPetAPIError.httpError(statusCode: 0, apiError: nil)
        }

        if http.statusCode == 401 {
            throw CodexPetAPIError.unauthorized
        }

        if http.statusCode >= 400 {
            throw CodexPetAPIError.httpError(
                statusCode: http.statusCode,
                apiError: APIError(code: "DOWNLOAD_FAILED", message: "HTTP \(http.statusCode) for \(url)")
            )
        }

        return data
    }

    func downloadFile(url: String) async throws -> (Data, URLResponse) {
        guard let u = URL(string: url) else { throw CodexPetAPIError.invalidURL }
        var req = URLRequest(url: u)
        req.setValue("application/zip", forHTTPHeaderField: "Accept")
        do {
            return try await session.data(for: req)
        } catch {
            throw CodexPetAPIError.networkError(error)
        }
    }
}
