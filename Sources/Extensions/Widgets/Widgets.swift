import Shared
import SwiftUI
import WidgetKit

@main
struct Widgets: WidgetBundle {
    init() {
        MaterialDesignIcons.register()
    }

    var body: some Widget {
        WidgetAssist()
        // Intentionally placing scripts before actions
        if #available(iOS 17, *) {
            WidgetScripts()
        }
        actionsWidget()
        WidgetOpenPage()
        if #available(iOS 17, *) {
            WidgetGauge()
            WidgetDetails()
        }
    }

    private func actionsWidget() -> some Widget {
        if #available(iOS 17, *) {
            return WidgetActions()
        } else {
            return LegacyWidgetActions()
        }
    }
}
