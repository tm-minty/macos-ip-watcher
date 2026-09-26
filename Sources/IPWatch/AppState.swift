import SwiftUI
import ServiceManagement

enum RefreshInterval: Double, CaseIterable, Identifiable {
    case thirtySeconds = 30
    case oneMinute = 60
    case fiveMinutes = 300
    case fifteenMinutes = 900
    case thirtyMinutes = 1800
    case oneHour = 3600
    case manual = 0

    var id: Double { rawValue }

    var seconds: Double? { self == .manual ? nil : rawValue }

    var title: String {
        switch self {
        case .thirtySeconds: return "30 seconds"
        case .oneMinute: return "1 minute"
        case .fiveMinutes: return "5 minutes"
        case .fifteenMinutes: return "15 minutes"
        case .thirtyMinutes: return "30 minutes"
        case .oneHour: return "1 hour"
        case .manual: return "Manual only"
        }
    }
}

@MainActor
final class AppState: ObservableObject {
    @Published private(set) var current: IPInfo?
    @Published private(set) var home: IPInfo?
    @Published private(set) var errorMessage: String?
    @Published private(set) var isLoading = false
    @Published private(set) var lastUpdated: Date?
    @Published private(set) var primaryInterface: String?
    @Published private(set) var vpnInterfaces: [String] = []
    @Published private(set) var lastNetworkEvent: String?

    @Published var refreshOnNetworkChange: Bool {
        didSet {
            guard didLoad else { return }
            defaults.set(refreshOnNetworkChange, forKey: Keys.refreshOnNetworkChange)
            updateMonitor()
        }
    }

    @Published var refreshInterval: RefreshInterval {
        didSet {
            guard didLoad else { return }
            defaults.set(refreshInterval.rawValue, forKey: Keys.refreshInterval)
            restartTimer()
        }
    }

    @Published var showIPInMenuBar: Bool {
        didSet { guard didLoad else { return }; defaults.set(showIPInMenuBar, forKey: Keys.showIP) }
    }

    @Published var showFlagInMenuBar: Bool {
        didSet { guard didLoad else { return }; defaults.set(showFlagInMenuBar, forKey: Keys.showFlag) }
    }

    @Published var launchAtLogin: Bool {
        didSet {
            guard didLoad else { return }
            applyLaunchAtLogin()
        }
    }

    private enum Keys {
        static let refreshInterval = "refreshInterval"
        static let showIP = "showIPInMenuBar"
        static let showFlag = "showFlagInMenuBar"
        static let refreshOnNetworkChange = "refreshOnNetworkChange"
    }

    static let shared = AppState()

    private let defaults = UserDefaults.standard
    private let vpnMonitor = VPNEventMonitor()
    private var refreshTask: Task<Void, Never>?
    private var eventRefreshTask: Task<Void, Never>?
    private var didLoad = false

    private init() {
        let storedInterval = defaults.object(forKey: Keys.refreshInterval) as? Double
        refreshInterval = storedInterval.flatMap(RefreshInterval.init(rawValue:)) ?? .fiveMinutes
        showIPInMenuBar = defaults.object(forKey: Keys.showIP) as? Bool ?? true
        showFlagInMenuBar = defaults.object(forKey: Keys.showFlag) as? Bool ?? true
        refreshOnNetworkChange = defaults.object(forKey: Keys.refreshOnNetworkChange) as? Bool ?? true
        launchAtLogin = SMAppService.mainApp.status == .enabled
        home = SharedStore.loadHome()
        didLoad = true
    }

    // MARK: - Derived state

    var vpnStatus: VPNStatus {
        guard let current else { return .unknown }
        if let home {
            if current.countryCode.caseInsensitiveCompare(home.countryCode) != .orderedSame {
                return .countryChanged(previous: home.countryCode, current: current.countryCode)
            }
            if current.ip != home.ip {
                return .ipChanged
            }
            if let tunnel = tunnelInterface {
                return .interfaceOnly(interface: tunnel)
            }
            return .direct
        }
        if let tunnel = tunnelInterface {
            return .interfaceOnly(interface: tunnel)
        }
        return .noReference
    }

    /// The interface currently carrying tunnel traffic, if any.
    var tunnelInterface: String? {
        if let primaryInterface, InterfaceInspector.isVPNName(primaryInterface) {
            return primaryInterface
        }
        return vpnInterfaces.first
    }

    var isTunnelActive: Bool {
        tunnelInterface != nil
    }

    var menuBarLabel: String {
        guard let current else {
            return showFlagInMenuBar ? "🌐" : "IP"
        }
        var parts: [String] = []
        if showFlagInMenuBar { parts.append(current.flag) }
        if showIPInMenuBar { parts.append(current.ip) }
        return parts.isEmpty ? "IP" : parts.joined(separator: " ")
    }

    // MARK: - Actions

    func refresh() async {
        updateNetworkSnapshot()
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let info = try await IPService.fetchExternalIP()
            current = info
            lastUpdated = info.fetchedAt
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func updateNetworkSnapshot() {
        let snapshot = NetworkProbe.snapshot()
        primaryInterface = snapshot.primaryInterface
        vpnInterfaces = snapshot.vpnInterfaces
    }

    /// A network path event arrived (VPN connect/disconnect or route change).
    func networkDidChange(snapshot: NetworkSnapshot, source: String) {
        primaryInterface = snapshot.primaryInterface
        vpnInterfaces = snapshot.vpnInterfaces

        let description = snapshot.isTunnelActive
            ? "Tunnel \(snapshot.tunnelInterface ?? "?") up"
            : "Tunnel down (via \(snapshot.primaryInterface ?? "?"))"
        lastNetworkEvent = description

        guard refreshOnNetworkChange else { return }
        eventRefreshTask?.cancel()
        eventRefreshTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            guard !Task.isCancelled else { return }
            await self?.refresh()
        }
    }

    func setCurrentAsHome() {
        guard let current else { return }
        home = current
        SharedStore.saveHome(current)
    }

    func clearHome() {
        home = nil
        SharedStore.saveHome(nil)
    }

    func start() {
        updateNetworkSnapshot()
        updateMonitor()
        restartTimer()
        Task { await refresh() }
    }

    private func updateMonitor() {
        if refreshOnNetworkChange {
            vpnMonitor.onChange = { [weak self] snapshot, source in
                Task { @MainActor in
                    self?.networkDidChange(snapshot: snapshot, source: source)
                }
            }
            vpnMonitor.start()
        } else {
            vpnMonitor.stop()
        }
    }

    private func restartTimer() {
        refreshTask?.cancel()
        guard let seconds = refreshInterval.seconds else { return }
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                if Task.isCancelled { return }
                await self?.refresh()
            }
        }
    }

    private func applyLaunchAtLogin() {
        do {
            if launchAtLogin {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            errorMessage = "Launch at login: \(error.localizedDescription)"
        }
    }
}
