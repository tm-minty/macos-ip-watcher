import Foundation

enum IPServiceError: LocalizedError {
    case badStatus(Int)
    case providerError(String)
    case noData

    var errorDescription: String? {
        switch self {
        case .badStatus(let code): return "Server returned HTTP \(code)"
        case .providerError(let message): return message
        case .noData: return "Empty response from provider"
        }
    }
}

/// Fetches the external IP and its geolocation.
///
/// Primary provider is ip-api.com (free tier is HTTP-only), with ipwho.is used
/// as an HTTPS fallback so the widget keeps working even if HTTP is blocked.
enum IPService {
    private static let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 15
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: config)
    }()

    static func fetchExternalIP() async throws -> IPInfo {
        do {
            return try await fetchFromIPAPI()
        } catch {
            do {
                return try await fetchFromIPWhoIs()
            } catch let fallbackError {
                throw fallbackError
            }
        }
    }

    private static func fetchFromIPAPI() async throws -> IPInfo {
        let fields = "status,message,country,countryCode,region,regionName,city,timezone,isp,org,as,query"
        var components = URLComponents(string: "http://ip-api.com/json/")!
        components.queryItems = [URLQueryItem(name: "fields", value: fields)]
        let (data, response) = try await session.data(from: components.url!)
        try validate(response)

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw IPServiceError.noData
        }
        let status = json["status"] as? String
        if status != "success" {
            throw IPServiceError.providerError(json["message"] as? String ?? "ip-api.com error")
        }
        return IPInfo(
            ip: json["query"] as? String ?? "",
            country: json["country"] as? String ?? "",
            countryCode: json["countryCode"] as? String ?? "",
            region: json["regionName"] as? String ?? "",
            city: json["city"] as? String ?? "",
            timezone: json["timezone"] as? String ?? "",
            isp: json["isp"] as? String ?? "",
            org: json["org"] as? String ?? "",
            asn: json["as"] as? String ?? "",
            provider: "ip-api.com",
            fetchedAt: Date()
        )
    }

    private static func fetchFromIPWhoIs() async throws -> IPInfo {
        let (data, response) = try await session.data(from: URL(string: "https://ipwho.is/")!)
        try validate(response)

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw IPServiceError.noData
        }
        guard (json["success"] as? Bool) != false else {
            throw IPServiceError.providerError(json["message"] as? String ?? "ipwho.is error")
        }
        let connection = json["connection"] as? [String: Any] ?? [:]
        let timezone = json["timezone"] as? [String: Any] ?? [:]
        let asnValue = connection["asn"].map { "AS\($0)" } ?? ""
        return IPInfo(
            ip: json["ip"] as? String ?? "",
            country: json["country"] as? String ?? "",
            countryCode: json["country_code"] as? String ?? "",
            region: json["region"] as? String ?? "",
            city: json["city"] as? String ?? "",
            timezone: timezone["id"] as? String ?? "",
            isp: connection["isp"] as? String ?? "",
            org: connection["org"] as? String ?? "",
            asn: asnValue,
            provider: "ipwho.is",
            fetchedAt: Date()
        )
    }

    private static func validate(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200..<300).contains(http.statusCode) else {
            throw IPServiceError.badStatus(http.statusCode)
        }
    }
}
