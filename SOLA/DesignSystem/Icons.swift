import SwiftUI

// Jeu d'icônes au trait — chemins repris tels quels du kit du design.
enum SolaIcons {
    static let clayAssets: [String: String] = [
        "sun": "clay_sun",
        "sunFull": "clay_sun",
        "sunBright": "clay_sun",
        "sunrise": "clay_cloud_sun",
        "moon": "clay_icon_moon",
        "drop": "clay_icon_drop",
        "dropFull": "clay_icon_drop",
        "shield": "clay_shield",
        "clock": "clay_timer",
        "timer": "clay_timer",
        "bell": "clay_bell",
        "camera": "clay_camera_scan",
        "scan": "clay_icon_scan",
        "sparkle": "clay_icon_sparkle",
        "check": "clay_icon_check",
        "checkCircle": "clay_icon_check_circle",
        "chevL": "clay_icon_chev_l",
        "chevR": "clay_icon_chev_r",
        "chevD": "clay_icon_chev_d",
        "arrowL": "clay_icon_arrow_l",
        "arrowR": "clay_icon_arrow_r",
        "arrowUp": "clay_icon_arrow_up",
        "flame": "clay_flame",
        "fire": "clay_flame",
        "thermo": "clay_icon_thermo",
        "pin": "clay_icon_pin",
        "cal": "clay_icon_cal",
        "trend": "clay_icon_trend",
        "user": "clay_profile",
        "grid": "clay_icon_grid",
        "search": "clay_icon_search",
        "book": "clay_icon_book",
        "eye": "clay_icon_eye",
        "leaf": "clay_leaf",
        "wave": "clay_icon_wave",
        "plus": "clay_icon_plus",
        "star": "clay_icon_star",
        "info": "clay_icon_info",
        "target": "clay_icon_target",
        "palette": "clay_icon_palette",
        "lock": "clay_icon_lock",
        "dots": "clay_icon_dots",
        "gauge": "clay_icon_gauge",
        "cloudSun": "clay_cloud_sun",
        "cloud": "clay_icon_cloud",
        "heart": "clay_icon_heart",
        "settings": "clay_settings",
        "ruler": "clay_icon_ruler",
        "refresh": "clay_icon_refresh",
        "globe": "clay_icon_globe",
        "chat": "clay_icon_chat",
        "music": "clay_icon_music",
        "store": "clay_icon_store",
        "umbrella": "clay_icon_umbrella",
        "spots": "clay_icon_spots",
        "home": "clay_icon_home",
        "alertTri": "clay_icon_alert_tri",
        "cross": "clay_icon_x",
        "x": "clay_icon_x",
        "minus": "clay_icon_minus",
        "crown": "clay_icon_crown",
        "share": "clay_icon_share",
        "copy": "clay_icon_copy",
        "trash": "clay_icon_trash",
        "users": "clay_icon_users"
    ]

    static let paths: [String: String] = [
        "sun": "M12 4V2M12 22v-2M4 12H2M22 12h-2M5.6 5.6 4.2 4.2M19.8 19.8l-1.4-1.4M18.4 5.6l1.4-1.4M4.2 19.8l1.4-1.4 M12 8a4 4 0 1 0 0 8 4 4 0 0 0 0-8Z",
        "moon": "M20 14.5A8 8 0 0 1 9.5 4 7 7 0 1 0 20 14.5Z",
        "drop": "M12 3.5c3 3.8 5.5 6.4 5.5 9.5a5.5 5.5 0 0 1-11 0c0-3.1 2.5-5.7 5.5-9.5Z",
        "shield": "M12 3 5 6v5c0 4 3 7.5 7 9 4-1.5 7-5 7-9V6l-7-3Z",
        "clock": "M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18ZM12 7v5l3.5 2",
        "bell": "M6 9a6 6 0 1 1 12 0c0 5 2 6 2 6H4s2-1 2-6ZM10 20a2 2 0 0 0 4 0",
        "camera": "M3 8a2 2 0 0 1 2-2h2l1.5-2h7L17 6h2a2 2 0 0 1 2 2v9a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V8ZM12 16.5a3.5 3.5 0 1 0 0-7 3.5 3.5 0 0 0 0 7Z",
        "sparkle": "M12 3l1.8 5.4L19 10l-5.2 1.6L12 17l-1.8-5.4L5 10l5.2-1.6L12 3ZM18.5 15l.8 2.2 2.2.8-2.2.8-.8 2.2-.8-2.2-2.2-.8 2.2-.8.8-2.2Z",
        "check": "M5 12.5l4.5 4.5L19 7.5",
        "chevL": "M14.5 5 8 12l6.5 7",
        "chevR": "M9.5 5 16 12l-6.5 7",
        "chevD": "M5 9.5 12 16l7-6.5",
        "flame": "M12 3c1 3-2 4.5-2 7a3 3 0 0 0 6 0c0-1-.4-1.8-.8-2.4C16.5 9 18 11 18 14a6 6 0 0 1-12 0C6 9.5 10 7 12 3Z",
        "thermo": "M14 14.8V6a2 2 0 0 0-4 0v8.8a4 4 0 1 0 4 0ZM12 12v3.5",
        "pin": "M12 21s7-5.6 7-11a7 7 0 1 0-14 0c0 5.4 7 11 7 11ZM12 12.5a2.5 2.5 0 1 0 0-5 2.5 2.5 0 0 0 0 5Z",
        "cal": "M4 6.5a2 2 0 0 1 2-2h12a2 2 0 0 1 2 2V19a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V6.5ZM4 10h16M8 3v4M16 3v4",
        "trend": "M4 16.5 9.5 11l3.5 3.5L20 7M20 7h-4.5M20 7v4.5",
        "user": "M12 12a4 4 0 1 0 0-8 4 4 0 0 0 0 8ZM5 20c.7-3.6 3.5-5.5 7-5.5s6.3 1.9 7 5.5",
        "grid": "M4 4h7v7H4V4ZM13 4h7v7h-7V4ZM4 13h7v7H4v-7ZM13 13h7v7h-7v-7Z",
        "scan": "M4 8V6a2 2 0 0 1 2-2h2M16 4h2a2 2 0 0 1 2 2v2M20 16v2a2 2 0 0 1-2 2h-2M8 20H6a2 2 0 0 1-2-2v-2M4 12h16",
        "search": "M11 18a7 7 0 1 0 0-14 7 7 0 0 0 0 14ZM20 20l-4-4",
        "book": "M6 4h11a1 1 0 0 1 1 1v15l-6.5-3.5L5 20V5a1 1 0 0 1 1-1Z",
        "eye": "M2.5 12S6 5.5 12 5.5 21.5 12 21.5 12 18 18.5 12 18.5 2.5 12 2.5 12ZM12 15a3 3 0 1 0 0-6 3 3 0 0 0 0 6Z",
        "leaf": "M5 19C4 11 9 5 19 5c0 10-6 15-14 14ZM9 15c2.5-3 5-4.5 8-5.5",
        "wave": "M3 9c2-2 4-2 6 0s4 2 6 0 4-2 6 0M3 15c2-2 4-2 6 0s4 2 6 0 4-2 6 0",
        "plus": "M12 5v14M5 12h14",
        "star": "M12 3.5l2.6 5.6 6 .7-4.5 4.1 1.2 6L12 17l-5.3 3 1.2-6L3.4 9.8l6-.7L12 3.5Z",
        "info": "M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18ZM12 11v5M12 7.5v.5",
        "target": "M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18ZM12 16a4 4 0 1 0 0-8 4 4 0 0 0 0 8ZM12 12h0",
        "palette": "M12 21a9 9 0 1 1 0-18c5 0 9 3.5 9 8 0 2.5-2 3.5-4 3.5h-2c-1.3 0-2 1-1.5 2.2.4 1-.4 2.3-1.5 2.3ZM7.5 12.5h0M10 8.5h0M15 8.5h0",
        "timer": "M12 22a8 8 0 1 0 0-16 8 8 0 0 0 0 16ZM12 14V10M9 2h6M18.5 7.5 20 6",
        "lock": "M6 11V8a6 6 0 0 1 12 0v3M5 11h14a1 1 0 0 1 1 1v8a1 1 0 0 1-1 1H5a1 1 0 0 1-1-1v-8a1 1 0 0 1 1-1Z",
        "dots": "M5 12h.01M12 12h.01M19 12h.01",
        "arrowR": "M5 12h14M13 6l6 6-6 6",
        "arrowUp": "M12 19V5M6 11l6-6 6 6",
        "gauge": "M12 21a9 9 0 1 1 8.5-12M12 13l4-3M12 13a1 1 0 1 0 0 .01",
        "cloudSun": "M8 7a4 4 0 1 1 4 4M16 19a3 3 0 0 0 0-6 4.5 4.5 0 0 0-8.7-1.2A3.5 3.5 0 0 0 7 19h9ZM4 3.5l1 1M3 9h1M9 3h.01",
        "heart": "M12 20s-7-4.4-7-9.5A3.8 3.8 0 0 1 12 7a3.8 3.8 0 0 1 7 3.5C19 15.6 12 20 12 20Z",
        "settings": "M12 15a3 3 0 1 0 0-6 3 3 0 0 0 0 6ZM19 12a7 7 0 0 0-.1-1.2l2-1.5-2-3.4-2.3 1a7 7 0 0 0-2-1.2L16.2 3h-4l-.4 2.5a7 7 0 0 0-2 1.2l-2.3-1-2 3.4 2 1.5A7 7 0 0 0 5 12c0 .4 0 .8.1 1.2l-2 1.5 2 3.4 2.3-1c.6.5 1.3.9 2 1.2L12 21h4l.4-2.5c.7-.3 1.4-.7 2-1.2l2.3 1 2-3.4-2-1.5c.1-.4.1-.8.1-1.2Z",
        "ruler": "M4 8h16a1 1 0 0 1 1 1v6a1 1 0 0 1-1 1H4a1 1 0 0 1-1-1V9a1 1 0 0 1 1-1ZM8 8v3M12 8v4M16 8v3",
        "refresh": "M4 12a8 8 0 0 1 13.7-5.6L20 8M20 4v4h-4M20 12a8 8 0 0 1-13.7 5.6L4 16M4 20v-4h4",
        "globe": "M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18ZM3 12h18M12 3c2.5 2.4 4 5.6 4 9s-1.5 6.6-4 9c-2.5-2.4-4-5.6-4-9s1.5-6.6 4-9Z",
        "chat": "M21 11.5a8.5 8.5 0 0 1-12.2 7.7L3.5 21l1.8-5.2A8.5 8.5 0 1 1 21 11.5Z",
        "music": "M9 17a3 3 0 1 1-2-2.8V5l11-2v9.2A3 3 0 1 1 16 9V6L9 7.3V17Z",
        "store": "M4 9.5 5.5 4h13L20 9.5M4 9.5V19a1 1 0 0 0 1 1h14a1 1 0 0 0 1-1V9.5M4 9.5h16M8 9.5a2 2 0 1 1-4 0M12 9.5a2 2 0 1 1-4 0M16 9.5a2 2 0 1 1-4 0M20 9.5a2 2 0 1 1-4 0",
        "umbrella": "M12 3a9 9 0 0 1 9 9H3a9 9 0 0 1 9-9ZM12 12v7a2 2 0 0 0 4 0",
        "spots": "M7 8a1.5 1.5 0 1 0 0-3 1.5 1.5 0 0 0 0 3ZM16 9a1 1 0 1 0 0-2 1 1 0 0 0 0 2ZM10 14a2 2 0 1 0 0-4 2 2 0 0 0 0 4ZM16.5 16a1.5 1.5 0 1 0 0-3 1.5 1.5 0 0 0 0 3Z",
        "home": "M4 11.5 12 4l8 7.5M6 10v9a1 1 0 0 0 1 1h10a1 1 0 0 0 1-1v-9",
        "alertTri": "M12 4 2.5 20h19L12 4ZM12 10v4M12 17h.01",
        "cross": "M6 6l12 12M18 6 6 18",
        // Alias & icônes ajoutées (écrans gamification / social / réglages)
        "x": "M6 6l12 12M18 6 6 18",
        "arrowL": "M19 12H5M11 6l-6 6 6 6",
        "minus": "M5 12h14",
        "fire": "M12 3c1 3-2 4.5-2 7a3 3 0 0 0 6 0c0-1-.4-1.8-.8-2.4C16.5 9 18 11 18 14a6 6 0 0 1-12 0C6 9.5 10 7 12 3Z",
        "crown": "M4 8l4 4 4-6 4 6 4-4-1.5 11H5.5L4 8ZM5.5 19h13",
        "sunFull": "M12 4V2M12 22v-2M4 12H2M22 12h-2M5.6 5.6 4.2 4.2M19.8 19.8l-1.4-1.4M18.4 5.6l1.4-1.4M4.2 19.8l1.4-1.4 M12 8a4 4 0 1 0 0 8 4 4 0 0 0 0-8Z",
        "sunBright": "M12 4V2M12 22v-2M4 12H2M22 12h-2M5.6 5.6 4.2 4.2M19.8 19.8l-1.4-1.4M18.4 5.6l1.4-1.4M4.2 19.8l1.4-1.4 M12 8a4 4 0 1 0 0 8 4 4 0 0 0 0-8Z",
        "dropFull": "M12 3.5c3 3.8 5.5 6.4 5.5 9.5a5.5 5.5 0 0 1-11 0c0-3.1 2.5-5.7 5.5-9.5Z",
        "checkCircle": "M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18ZM8 12l2.5 2.5L16 9",
        "share": "M16 7a3 3 0 1 0-2.8-4M8 14a3 3 0 1 0 0-.01M16 21a3 3 0 1 0 0-.01M13.5 5.5 9 11M9 13l4.5 5.5",
        "copy": "M9 9h10a1 1 0 0 1 1 1v10a1 1 0 0 1-1 1H9a1 1 0 0 1-1-1V10a1 1 0 0 1 1-1ZM5 15H4a1 1 0 0 1-1-1V4a1 1 0 0 1 1-1h10a1 1 0 0 1 1 1v1",
        "trash": "M5 7h14M10 7V5a1 1 0 0 1 1-1h2a1 1 0 0 1 1 1v2M6 7l1 13a1 1 0 0 0 1 1h8a1 1 0 0 0 1-1l1-13M10 11v6M14 11v6",
        "users": "M9 12a4 4 0 1 0 0-8 4 4 0 0 0 0 8ZM2 20c.6-3.2 3.2-5 7-5s6.4 1.8 7 5M17 4.5a4 4 0 0 1 0 7.5M22 20c-.4-2.4-1.8-4-4-4.6",
        "cloud": "M7 18a4 4 0 0 1 0-8 5 5 0 0 1 9.6-1.3A3.5 3.5 0 0 1 17 18H7Z",
    ]
}

// Forme d'icône (Shape) — mise à l'échelle depuis le viewBox 24x24.
struct IconShape: Shape {
    let name: String
    func path(in rect: CGRect) -> Path {
        let d = SolaIcons.paths[name] ?? SolaIcons.paths["sparkle"]!
        let raw = SVGPath.path(from: d)
        let scale = min(rect.width, rect.height) / 24.0
        let t = CGAffineTransform(scaleX: scale, y: scale)
            .concatenating(CGAffineTransform(translationX: rect.minX, y: rect.minY))
        return raw.applying(t)
    }
}

struct Icon: View {
    let name: String
    var size: CGFloat = 22
    var stroke: CGFloat = 1.7
    var filled: Bool = false

    var body: some View {
        if let asset = SolaIcons.clayAssets[name] {
            Image(asset)
                .resizable()
                .scaledToFit()
                .frame(width: size * 1.35, height: size * 1.35)
                .frame(width: size, height: size)
                .clipped()
        } else {
            let shape = IconShape(name: name)
            Group {
                if filled {
                    shape.fill(style: FillStyle(eoFill: true))
                } else {
                    shape.stroke(style: StrokeStyle(lineWidth: stroke * (size / 24),
                                                    lineCap: .round, lineJoin: .round))
                }
            }
            .frame(width: size, height: size)
        }
    }
}
