import SwiftUI
import AppKit

struct ContentView: View {
    @EnvironmentObject private var state: AppState
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            statusBadge

            if let home = state.home {
                referenceRow(home)
            }

            if let error = state.errorMessage {
                errorRow(error)
            }

            details
            Divider()
            actions
            Divider()
            settings
            Divider()
            footer
        }
        .padding(14)
        .frame(width: 330)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            Text(state.current?.flag ?? "🌐")
                .font(.system(size: 36))
            VStack(alignment: .leading, spacing: 2) {
                Text(state.current?.ip ?? "—")
                    .font(.system(.title3, design: .monospaced))
                    .fontWeight(.semibold)
                    .textSelection(.enabled)
                Text(state.current?.shortLocation ?? "Fetching external IP…")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            if state.isLoading {
                ProgressView().controlSize(.small)
            }
        }
    }

    // MARK: - VPN status

    private var statusBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: state.vpnStatus.symbol)
                .foregroundStyle(statusColor)
            Text(state.vpnStatus.title)
                .fontWeight(.medium)
            Spacer(minLength: 0)
        }
        .font(.callout)
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(statusColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
    }

    private var statusColor: Color {
        switch state.vpnStatus {
        case .direct: return .green
        case .ipChanged, .interfaceOnly: return .orange
        case .countryChanged: return .red
        case .unknown, .noReference: return .secondary
        }
    }

    private func referenceRow(_ home: IPInfo) -> some View {
        HStack(spacing: 6) {
            Text("Reference: \(home.flag) \(home.ip)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
            Spacer(minLength: 0)
            Button("Clear") { state.clearHome() }
                .buttonStyle(.link)
                .font(.caption)
        }
    }

    private func errorRow(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(.red)
            Text(message)
                .font(.caption)
                .foregroundStyle(.red)
            Spacer(minLength: 0)
        }
    }

    // MARK: - Details

    private var details: some View {
        VStack(spacing: 6) {
            detailRow("ISP", state.current?.isp)
            detailRow("Org", state.current?.org)
            detailRow("ASN", state.current?.asn)
            detailRow("Region", state.current?.region)
            detailRow("Timezone", state.current?.timezone)
            detailRow("Interface", state.primaryInterface)
            if !state.vpnInterfaces.isEmpty {
                detailRow("Tunnel", state.vpnInterfaces.joined(separator: ", "))
            }
            detailRow("Source", state.current?.provider)
        }
    }

    private func detailRow(_ label: String, _ value: String?) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 70, alignment: .leading)
            Text((value?.isEmpty == false) ? value! : "—")
                .textSelection(.enabled)
            Spacer(minLength: 0)
        }
        .font(.callout)
    }

    // MARK: - Actions

    private var actions: some View {
        HStack(spacing: 8) {
            Button {
                Task { await state.refresh() }
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .disabled(state.isLoading)

            Button {
                state.setCurrentAsHome()
            } label: {
                Label("Set as home", systemImage: "house")
            }
            .disabled(state.current == nil)

            Spacer(minLength: 0)

            Button {
                copyIP()
            } label: {
                Image(systemName: "doc.on.doc")
            }
            .help("Copy IP address")
            .disabled(state.current == nil)

            Button {
                if let ip = state.current?.ip,
                   let url = URL(string: "https://ipwho.is/\(ip)") {
                    openURL(url)
                }
            } label: {
                Image(systemName: "safari")
            }
            .help("Open details in browser")
            .disabled(state.current == nil)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }

    // MARK: - Settings

    private var settings: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Refresh", selection: $state.refreshInterval) {
                ForEach(RefreshInterval.allCases) { interval in
                    Text(interval.title).tag(interval)
                }
            }
            .pickerStyle(.menu)
            .controlSize(.small)

            Toggle("Show IP in menu bar", isOn: $state.showIPInMenuBar)
                .toggleStyle(.checkbox)
            Toggle("Show flag in menu bar", isOn: $state.showFlagInMenuBar)
                .toggleStyle(.checkbox)
            Toggle("Refresh on VPN / network change", isOn: $state.refreshOnNetworkChange)
                .toggleStyle(.checkbox)
            Toggle("Launch at login", isOn: $state.launchAtLogin)
                .toggleStyle(.checkbox)
        }
        .font(.callout)
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                if let updated = state.lastUpdated {
                    Text("Updated \(updated.formatted(date: .omitted, time: .standard))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Not updated yet")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }
                    .buttonStyle(.link)
                    .font(.caption)
            }
            if let event = state.lastNetworkEvent {
                Text(event)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func copyIP() {
        guard let ip = state.current?.ip else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(ip, forType: .string)
    }
}
