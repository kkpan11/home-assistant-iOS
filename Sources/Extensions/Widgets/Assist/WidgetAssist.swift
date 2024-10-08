import Intents
import Shared
import SwiftUI
import WidgetKit

struct WidgetAssist: Widget {
    var body: some WidgetConfiguration {
        IntentConfiguration(
            kind: WidgetsKind.assist.rawValue,
            intent: AssistInAppIntent.self,
            provider: WidgetAssistProvider(),
            content: { entry in
                if #available(iOS 18.0, *) {
                    WidgetAssistViewTintedWrapper(entry: entry)
                        .widgetBackground(Color.clear)
                } else {
                    WidgetAssistView(entry: entry, tinted: false)
                        .widgetBackground(Color.clear)
                }
            }
        )
        .contentMarginsDisabledIfAvailable()
        .configurationDisplayName(L10n.Widgets.Assist.title)
        .description(L10n.Widgets.Assist.description)
        .supportedFamilies(supportedFamilies)
    }

    private var supportedFamilies: [WidgetFamily] {
        var supportedFamilies: [WidgetFamily] = [.systemSmall]

        if #available(iOSApplicationExtension 16.0, *) {
            supportedFamilies.append(.accessoryCircular)
        }

        return supportedFamilies
    }
}
