import SwiftUI
import AppKit

@main
struct IPWatchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var state = AppState.shared

    var body: some Scene {
        MenuBarExtra {
            ContentView()
                .environmentObject(state)
        } label: {
            Text(state.menuBarLabel)
        }
        .menuBarExtraStyle(.window)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        if CommandLine.arguments.contains("--probe") {
            runProbe()
            return
        }
        NSApp.setActivationPolicy(.accessory)
        Task { @MainActor in
            AppState.shared.start()
        }
    }

    /// Headless self-check: `IPWatch --probe` prints the detected IP and exits.
    private func runProbe() {
        Task {
            let snapshot = NetworkProbe.snapshot()
            let tunnel = snapshot.isTunnelActive
                ? "tunnel \(snapshot.tunnelInterface ?? "?") up"
                : "no tunnel"
            do {
                let info = try await IPService.fetchExternalIP()
                print("\(info.flag) \(info.ip) | \(info.country) | \(info.isp) | via \(info.provider)")
                print("network: \(tunnel) | primary=\(snapshot.primaryInterface ?? "?") | vpn=\(snapshot.vpnInterfaces.joined(separator: ","))")
                exit(0)
            } catch {
                print("probe failed: \(error.localizedDescription)")
                print("network: \(tunnel)")
                exit(1)
            }
        }
    }
}
