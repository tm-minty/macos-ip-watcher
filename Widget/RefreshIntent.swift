import AppIntents
import WidgetKit

/// Lets the user force an immediate refresh by tapping the button in the widget.
struct RefreshIntent: AppIntent {
    static var title: LocalizedStringResource = "Refresh external IP"
    static var isDiscoverable = false

    func perform() async throws -> some IntentResult {
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
