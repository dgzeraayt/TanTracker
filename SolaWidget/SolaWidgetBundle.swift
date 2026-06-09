import WidgetKit
import SwiftUI

// MARK: - Widget UV (écran d'accueil + écran de verrouillage)
struct SolaUVWidget: Widget {
    let kind = "SolaUVWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: UVProvider()) { entry in
            UVWidgetRootView(entry: entry)
        }
        .configurationDisplayName("Indice UV")
        .description("UV actuel, niveau, pic du jour et prévision.")
        .supportedFamilies([
            .systemSmall, .systemMedium, .systemLarge,
            .accessoryCircular, .accessoryInline, .accessoryRectangular
        ])
    }
}

// Route vers la bonne vue selon la famille + applique le fond de marque.
struct UVWidgetRootView: View {
    let entry: UVEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            switch family {
            case .systemSmall, .systemMedium:
                UVSmallMediumView(entry: entry).widgetBackground(WidgetPalette.bg)
            case .systemLarge:
                UVLargeView(entry: entry).widgetBackground(WidgetPalette.bg)
            default:
                UVAccessoryView(entry: entry) // fond géré par le système
            }
        }
    }
}

// Compat fond widget : containerBackground requis dès iOS 17.
extension View {
    @ViewBuilder
    func widgetBackground(_ color: Color) -> some View {
        if #available(iOS 17.0, *) {
            containerBackground(color, for: .widget)
        } else {
            padding(14).background(color)
        }
    }
}

// MARK: - Bundle
@main
struct SolaWidgetBundle: WidgetBundle {
    var body: some Widget {
        SolaUVWidget()
        if #available(iOS 16.1, *) {
            SunSessionLiveActivity()
        }
    }
}
