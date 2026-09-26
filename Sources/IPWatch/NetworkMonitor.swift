import Foundation
import Network
import SystemConfiguration
import Darwin

struct NetworkSnapshot: Equatable {
    var primaryInterface: String?
    var vpnInterfaces: [String]

    /// True when traffic appears to be routed through a tunnel: either the
    /// default route sits on a VPN-like interface, or a VPN-like interface is
    /// up with an assigned IPv4 address.
    var isTunnelActive: Bool {
        if let primaryInterface, InterfaceInspector.isVPNName(primaryInterface) {
            return true
        }
        return !vpnInterfaces.isEmpty
    }

    var tunnelInterface: String? {
        if let primaryInterface, InterfaceInspector.isVPNName(primaryInterface) {
            return primaryInterface
        }
        return vpnInterfaces.first
    }
}

enum InterfaceInspector {
    static let vpnPrefixes = ["utun", "ppp", "ipsec", "tun", "tap", "wg"]

    static func isVPNName(_ name: String) -> Bool {
        vpnPrefixes.contains { name.hasPrefix($0) }
    }

    /// Interfaces that look like tunnels and currently have a usable IPv4 address.
    static func activeVPNInterfaces() -> [String] {
        var names = Set<String>()
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return [] }
        defer { freeifaddrs(ifaddr) }

        var pointer: UnsafeMutablePointer<ifaddrs>? = first
        while let current = pointer {
            defer { pointer = current.pointee.ifa_next }
            let flags = Int32(current.pointee.ifa_flags)
            guard (flags & IFF_UP) != 0, (flags & IFF_RUNNING) != 0 else { continue }
            guard let address = current.pointee.ifa_addr,
                  address.pointee.sa_family == UInt8(AF_INET) else { continue }
            let name = String(cString: current.pointee.ifa_name)
            if isVPNName(name) {
                names.insert(name)
            }
        }
        return names.sorted()
    }
}

enum NetworkProbe {
    static func snapshot() -> NetworkSnapshot {
        NetworkSnapshot(
            primaryInterface: primaryInterface(),
            vpnInterfaces: InterfaceInspector.activeVPNInterfaces()
        )
    }

    /// The interface currently carrying the default IPv4 route, e.g. "en0" or "utun4".
    private static func primaryInterface() -> String? {
        guard let store = SCDynamicStoreCreate(nil, "com.local.ipwatch.probe" as CFString, nil, nil),
              let value = SCDynamicStoreCopyValue(store, "State:/Network/Global/IPv4" as CFString) as? [String: Any] else {
            return nil
        }
        return value["PrimaryInterface"] as? String
    }
}

/// Watches the system network configuration and fires when the tunnel or the
/// default route changes (VPN connect, disconnect, or network switch).
final class VPNEventMonitor {
    var onChange: ((NetworkSnapshot, String) -> Void)?

    private let pathMonitor = NWPathMonitor()
    private let pathQueue = DispatchQueue(label: "com.local.ipwatch.pathmonitor")
    private var dynamicStore: SCDynamicStore?
    private var runLoopSource: CFRunLoopSource?
    private var lastSnapshot: NetworkSnapshot?
    private var started = false

    func start() {
        guard !started else { return }
        started = true

        pathQueue.async { [weak self] in
            self?.lastSnapshot = NetworkProbe.snapshot()
        }

        pathMonitor.pathUpdateHandler = { [weak self] _ in
            self?.handle(source: "path")
        }
        pathMonitor.start(queue: pathQueue)

        startSystemConfigMonitor()
    }

    func stop() {
        guard started else { return }
        started = false
        pathMonitor.cancel()
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .defaultMode)
        }
        runLoopSource = nil
        dynamicStore = nil
    }

    private func startSystemConfigMonitor() {
        var context = SCDynamicStoreContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )
        let callback: SCDynamicStoreCallBack = { _, _, info in
            guard let info else { return }
            let monitor = Unmanaged<VPNEventMonitor>.fromOpaque(info).takeUnretainedValue()
            monitor.handle(source: "system")
        }
        guard let store = SCDynamicStoreCreate(nil, "com.local.ipwatch" as CFString, callback, &context) else {
            return
        }
        dynamicStore = store

        let keys = [
            "State:/Network/Global/IPv4",
            "State:/Network/Global/IPv6",
            "State:/Network/Global/DNS",
        ] as CFArray
        let patterns = [
            "State:/Network/Service/.*/IPv4",
            "State:/Network/Service/.*/IPv6",
        ] as CFArray
        SCDynamicStoreSetNotificationKeys(store, keys, patterns)

        guard let source = SCDynamicStoreCreateRunLoopSource(nil, store, 0) else { return }
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
    }

    private func handle(source: String) {
        pathQueue.async { [weak self] in
            guard let self else { return }
            let snapshot = NetworkProbe.snapshot()
            guard snapshot != self.lastSnapshot else { return }
            self.lastSnapshot = snapshot
            DispatchQueue.main.async { [weak self] in
                self?.onChange?(snapshot, source)
            }
        }
    }
}
