import Foundation

/// Normalized result from any IP geolocation provider.
struct IPInfo: Codable, Equatable {
    var ip: String
    var country: String
    var countryCode: String
    var region: String
    var city: String
    var timezone: String
    var isp: String
    var org: String
    var asn: String
    var provider: String
    var fetchedAt: Date

    /// Emoji flag derived from the ISO country code (e.g. "SE" -> 🇸🇪).
    var flag: String {
        let code = countryCode.uppercased()
        guard code.count == 2 else { return "🌐" }
        let base: UInt32 = 0x1F1E6
        var scalars = String.UnicodeScalarView()
        for scalar in code.unicodeScalars {
            guard scalar.value >= 0x41, scalar.value <= 0x5A,
                  let flagScalar = UnicodeScalar(base + scalar.value - 0x41) else {
                return "🌐"
            }
            scalars.append(flagScalar)
        }
        return String(scalars)
    }

    var shortLocation: String {
        [city, country].filter { !$0.isEmpty }.joined(separator: ", ")
    }
}

enum VPNStatus: Equatable {
    /// No IP data yet.
    case unknown
    /// We have an IP, but the user has not marked a "home" network to compare against.
    case noReference
    /// Current IP and country match the saved home network.
    case direct
    /// IP changed but the country stayed the same (dynamic ISP, or VPN in the same country).
    case ipChanged
    /// A tunnel interface is up but the external IP still matches the reference.
    case interfaceOnly(interface: String)
    /// Country changed compared to the saved home network (strong VPN/proxy signal).
    case countryChanged(previous: String, current: String)

    var title: String {
        switch self {
        case .unknown: return "Checking…"
        case .noReference: return "No reference set"
        case .direct: return "Direct connection"
        case .ipChanged: return "IP changed (same country)"
        case .interfaceOnly(let interface): return "Tunnel active (\(interface))"
        case .countryChanged: return "VPN / proxy likely"
        }
    }

    var symbol: String {
        switch self {
        case .unknown: return "questionmark.circle"
        case .noReference: return "questionmark.circle"
        case .direct: return "checkmark.shield.fill"
        case .ipChanged: return "exclamationmark.triangle.fill"
        case .interfaceOnly: return "exclamationmark.shield.fill"
        case .countryChanged: return "lock.shield.fill"
        }
    }
}
