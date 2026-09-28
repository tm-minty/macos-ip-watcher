import SwiftUI
import AppKit
import WidgetKit

/// Off-screen screenshot generator for the docs. Renders the real SwiftUI
/// views with mock data (RFC 5737 documentation ranges) so no personal IP
/// addresses ever appear.
///
/// Build & run via `scripts/make-screenshots.sh`.
@main
struct SnapshotTool {
    @MainActor
    static func main() {
        _ = NSApplication.shared
        let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "docs/screenshots"
        try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

        let now = Date()

        let home = IPInfo(
            ip: "198.51.100.10", country: "United States", countryCode: "US",
            region: "California", city: "San Francisco", timezone: "America/Los_Angeles",
            isp: "Example Broadband LLC", org: "Example Broadband LLC",
            asn: "AS64501 Example Broadband", provider: "ip-api.com", fetchedAt: now
        )
        let vpn = IPInfo(
            ip: "203.0.113.42", country: "Sweden", countryCode: "SE",
            region: "Stockholm County", city: "Stockholm", timezone: "Europe/Stockholm",
            isp: "Example VPN AB", org: "Example VPN AB",
            asn: "AS64500 Example VPN", provider: "ip-api.com", fetchedAt: now
        )
        let direct = IPInfo(
            ip: "198.51.100.10", country: "United States", countryCode: "US",
            region: "California", city: "San Francisco", timezone: "America/Los_Angeles",
            isp: "Example Broadband LLC", org: "Example Broadband LLC",
            asn: "AS64501 Example Broadband", provider: "ip-api.com", fetchedAt: now
        )

        // Popover, VPN/proxy detected (country changed) + a tunnel interface.
        let vpnState = AppState(previewCurrent: vpn, home: home,
                                primaryInterface: "utun4", vpnInterfaces: ["utun4"],
                                lastUpdated: now)
        renderPopover(state: vpnState, to: "\(outDir)/popover-vpn.png")

        // Popover, direct connection matching the home network.
        let directState = AppState(previewCurrent: direct, home: home,
                                   primaryInterface: "en0", vpnInterfaces: [],
                                   lastUpdated: now)
        renderPopover(state: directState, to: "\(outDir)/popover-direct.png")

        // Widgets.
        let entry = IPEntry(date: now, info: vpn, home: home, vpnInterfaces: ["utun4"], error: nil)
        renderWidget(entry: entry, family: .systemMedium, to: "\(outDir)/widget-medium.png")
        renderWidget(entry: entry, family: .systemSmall, to: "\(outDir)/widget-small.png")

        print("Screenshots written to \(outDir)")
    }

    @MainActor
    static func renderPopover(state: AppState, to path: String) {
        let view = ContentView()
            .environmentObject(state)
            .background(Color(nsColor: .windowBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
            )
            .padding(1)
        render(view, to: path, scale: 2)
    }

    @MainActor
    static func renderWidget(entry: IPEntry, family: WidgetFamily, to path: String) {
        let width: CGFloat = family == .systemSmall ? 158 : 338
        let view = IPWatchWidgetEntryView(entry: entry, familyOverride: family)
            .frame(width: width, height: 158)
            .background(Color(nsColor: .windowBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
            )
        render(view, to: path, scale: 2)
    }

    @MainActor
    static func render<V: View>(_ view: V, to path: String, scale: CGFloat) {
        let hosting = NSHostingView(rootView: view)
        hosting.layoutSubtreeIfNeeded()
        let size = hosting.fittingSize
        hosting.frame = NSRect(origin: .zero, size: size)

        // AppKit-backed controls (Toggle, Picker, .link buttons) only render
        // when hosted in a window. Keep it off-screen.
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless], backing: .buffered, defer: false
        )
        window.isReleasedWhenClosed = false
        window.contentView = hosting
        window.setFrameOrigin(NSPoint(x: -30000, y: -30000))
        window.orderFrontRegardless()
        hosting.layoutSubtreeIfNeeded()
        window.displayIfNeeded()

        let pixelsWide = Int((size.width * scale).rounded())
        let pixelsHigh = Int((size.height * scale).rounded())
        guard pixelsWide > 0, pixelsHigh > 0,
              let rep = NSBitmapImageRep(
                bitmapDataPlanes: nil, pixelsWide: pixelsWide, pixelsHigh: pixelsHigh,
                bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
              let ctx = NSGraphicsContext(bitmapImageRep: rep) else {
            FileHandle.standardError.write(Data("Failed to render \(path)\n".utf8))
            return
        }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = ctx
        let cg = ctx.cgContext
        cg.translateBy(x: 0, y: CGFloat(pixelsHigh))
        cg.scaleBy(x: scale, y: -scale)
        hosting.layer?.render(in: cg)
        NSGraphicsContext.restoreGraphicsState()
        window.orderOut(nil)

        guard let png = rep.representation(using: .png, properties: [:]) else {
            FileHandle.standardError.write(Data("PNG encode failed for \(path)\n".utf8))
            return
        }
        do {
            try png.write(to: URL(fileURLWithPath: path))
            print("  wrote \(path)")
        } catch {
            FileHandle.standardError.write(Data("Write failed for \(path): \(error)\n".utf8))
        }
    }
}
