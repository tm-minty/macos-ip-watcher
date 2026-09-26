import Foundation

/// Storage shared between the menu bar app and the widget extension.
///
/// When an App Group is available (signed with a development team) both
/// processes read the same data. Without the entitlement it gracefully falls
/// back to the process-local defaults, so the widget still works but cannot
/// compare against the "home" network saved by the app.
enum SharedStore {
    static let appGroupID = "group.com.local.ipwatch"

    static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }

    private static let homeKey = "homeIPInfo"

    static func loadHome() -> IPInfo? {
        guard let data = defaults.data(forKey: homeKey) else { return nil }
        return try? JSONDecoder().decode(IPInfo.self, from: data)
    }

    static func saveHome(_ info: IPInfo?) {
        if let info, let data = try? JSONEncoder().encode(info) {
            defaults.set(data, forKey: homeKey)
        } else {
            defaults.removeObject(forKey: homeKey)
        }
    }
}
