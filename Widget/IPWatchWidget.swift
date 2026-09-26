import WidgetKit
import SwiftUI

extension IPInfo {
    static let sample = IPInfo(
        ip: "203.0.113.1",
        country: "Sweden",
        countryCode: "SE",
        region: "Stockholm County",
        city: "Stockholm",
        timezone: "Europe/Stockholm",
        isp: "Example ISP AB",
        org: "Example ISP AB",
        asn: "AS64500 Example ISP",
        provider: "ip-api.com",
        fetchedAt: Date()
    )
}

struct IPEntry: TimelineEntry {
    let date: Date
    let info: IPInfo?
    let home: IPInfo?
    let vpnInterfaces: [String]
    let error: String?

    static let placeholder = IPEntry(date: Date(), info: .sample, home: nil, vpnInterfaces: [], error: nil)

    /// VPN verdict from the external IP/country vs. the saved home network,
    /// plus the tunnel interfaces visible from the widget process.
    var vpnStatus: VPNStatus {
        guard let info else { return .unknown }
        if let home {
            if info.countryCode.caseInsensitiveCompare(home.countryCode) != .orderedSame {
                return .countryChanged(previous: home.countryCode, current: info.countryCode)
            }
            if info.ip != home.ip {
                return .ipChanged
            }
            if let tunnel = vpnInterfaces.first {
                return .interfaceOnly(interface: tunnel)
            }
            return .direct
        }
        if let tunnel = vpnInterfaces.first {
            return .interfaceOnly(interface: tunnel)
        }
        return .noReference
    }
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> IPEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (IPEntry) -> Void) {
        if context.isPreview {
            completion(.placeholder)
            return
        }
        Task { completion(await loadEntry()) }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<IPEntry>) -> Void) {
        Task {
            let entry = await loadEntry()
            let next = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date().addingTimeInterval(900)
            completion(Timeline(entries: [entry], policy: .after(next)))
        }
    }

    private func loadEntry() async -> IPEntry {
        let home = SharedStore.loadHome()
        let interfaces = InterfaceInspector.activeVPNInterfaces()
        do {
            let info = try await IPService.fetchExternalIP()
            return IPEntry(date: Date(), info: info, home: home, vpnInterfaces: interfaces, error: nil)
        } catch {
            return IPEntry(date: Date(), info: nil, home: home, vpnInterfaces: interfaces, error: error.localizedDescription)
        }
    }
}

struct IPWatchWidget: Widget {
    let kind = "IPWatchWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            IPWatchWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("External IP")
        .description("Your external IP, country flag and VPN status.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct IPWatchWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: IPEntry

    var body: some View {
        switch family {
        case .systemMedium:
            mediumView
        default:
            smallView
        }
    }

    private var smallView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(entry.info?.flag ?? "🌐")
                .font(.system(size: 34))
            Text(entry.info?.ip ?? "—")
                .font(.system(.callout, design: .monospaced))
                .fontWeight(.semibold)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(entry.info?.country ?? entry.error ?? "…")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer(minLength: 0)
            statusLabel
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private var mediumView: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(entry.info?.flag ?? "🌐")
                .font(.system(size: 44))
            VStack(alignment: .leading, spacing: 3) {
                Text(entry.info?.ip ?? "—")
                    .font(.system(.title3, design: .monospaced))
                    .fontWeight(.semibold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(entry.info?.shortLocation ?? entry.error ?? "…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(entry.info?.isp ?? " ")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer(minLength: 0)
                statusLabel
            }
            Spacer(minLength: 0)
            VStack(alignment: .trailing) {
                Button(intent: RefreshIntent()) {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.plain)
                .font(.caption)
                Spacer(minLength: 0)
                Text(entry.date.formatted(date: .omitted, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private var statusLabel: some View {
        HStack(spacing: 4) {
            Image(systemName: entry.vpnStatus.symbol)
            Text(entry.vpnStatus.title)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
        .font(.caption2)
        .foregroundStyle(statusColor)
    }

    private var statusColor: Color {
        switch entry.vpnStatus {
        case .direct: return .green
        case .ipChanged, .interfaceOnly: return .orange
        case .countryChanged: return .red
        case .unknown, .noReference: return .secondary
        }
    }
}
