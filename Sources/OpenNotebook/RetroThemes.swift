import SwiftUI
import AppKit

/// Original Kiyobumi patterns inspired by the era of Kaleidoscope schemes.
enum RetroTheme: String, CaseIterable, Identifiable {
    case classic, cinema, geometry, jazz
    var id: String { rawValue }
    var title: String {
        switch self {
        case .classic: return "Classic"
        case .cinema: return "Cinema Confetti"
        case .geometry: return "Deco Triangles"
        case .jazz: return "Jazz Swirls"
        }
    }
    var detail: String {
        switch self {
        case .classic: return "Plain native appearance"
        case .cinema: return "Neon confetti on midnight blue"
        case .geometry: return "Layered triangles and teal diamonds"
        case .jazz: return "Turquoise ribbons and mauve spirals"
        }
    }
    func sidebarHex(dark: Bool, pages: Bool) -> String {
        switch self {
        case .classic: return "#808080" // Native background is used instead.
        case .cinema: return dark ? (pages ? "#22213D" : "#17182F") : (pages ? "#F0EDF7" : "#E5E1F2")
        case .geometry: return dark ? (pages ? "#1B474C" : "#173E43") : (pages ? "#E5F2ED" : "#D7ECE8")
        case .jazz: return dark ? (pages ? "#423455" : "#352B50") : (pages ? "#F4E9F2" : "#E9DEED")
        }
    }
    func controlHex(dark: Bool) -> String {
        switch self {
        case .classic: return "#808080"
        case .cinema: return dark ? "#484365" : "#DDD7EE"
        case .geometry: return dark ? "#285B60" : "#C7E3DC"
        case .jazz: return dark ? "#574469" : "#E4D3E9"
        }
    }
    var highlightHex: String {
        switch self {
        case .classic: return "#007AFF"
        case .cinema: return "#C3B3F3"
        case .geometry: return "#9DDCD3"
        case .jazz: return "#D9B9EA"
        }
    }
    var selectionHex: String {
        switch self {
        case .classic: return "#007AFF"
        case .cinema: return "#6043A4"
        case .geometry: return "#25666D"
        case .jazz: return "#71518D"
        }
    }

    var baseHex: String {
        switch self {
        case .classic: return "#808080"
        case .cinema: return "#17182F"
        case .geometry: return "#173E43"
        case .jazz: return "#352B50"
        }
    }
}

@MainActor
private enum ThemeTileCache {
    static let images: [RetroTheme: NSImage] = {
        var result: [RetroTheme: NSImage] = [:]
        for theme in RetroTheme.allCases where theme != .classic {
            guard let url = Bundle.main.url(forResource: theme.rawValue, withExtension: "png", subdirectory: "Themes"),
                  let image = NSImage(contentsOf: url) else { continue }
            // Two pixels per logical point. Tiling avoids a stretched wallpaper.
            image.size = NSSize(width: 192, height: 160)
            result[theme] = image
        }
        return result
    }()
}

@MainActor
struct RetroThemeTile: View {
    let theme: RetroTheme
    var body: some View {
        ZStack {
            if theme == .classic {
                Color(nsColor: .windowBackgroundColor)
            } else {
                Color(hex: theme.baseHex)
                if let image = ThemeTileCache.images[theme] {
                    Image(nsImage: image).resizable(resizingMode: .tile)
                }
            }
        }
        .clipped()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

@MainActor
struct RetroThemeBackground: View {
    @ObservedObject private var appearance = AppearancePreferences.shared
    var body: some View { RetroThemeTile(theme: appearance.theme) }
}

@MainActor
struct RetroThemeRibbon: View {
    @ObservedObject private var appearance = AppearancePreferences.shared
    var body: some View {
        if appearance.theme != .classic {
            RetroThemeTile(theme: appearance.theme).frame(height: 18)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(.black.opacity(0.25)).frame(height: 1)
                }
                .allowsHitTesting(false)
        }
    }
}

@MainActor
struct RetroThemePicker: View {
    @ObservedObject private var appearance = AppearancePreferences.shared
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Theme").font(.headline)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(RetroTheme.allCases) { theme in
                    Button { appearance.theme = theme } label: {
                        VStack(spacing: 0) {
                            RetroThemeTile(theme: theme).frame(height: 70)
                            HStack {
                                Text(theme.title).font(.system(size: 13, weight: .medium))
                                Spacer(minLength: 4)
                                Image(systemName: appearance.theme == theme ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(appearance.theme == theme ? Color.accentColor : Color.secondary)
                            }
                            .padding(10)
                            .background(Color(nsColor: .controlBackgroundColor))
                        }
                        .foregroundStyle(.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .overlay(RoundedRectangle(cornerRadius: 6)
                            .stroke(appearance.theme == theme ? Color.accentColor : Color(nsColor: .separatorColor),
                                    lineWidth: appearance.theme == theme ? 2 : 1))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help(theme.detail)
                    .accessibilityLabel(theme.title)
                    .accessibilityValue(appearance.theme == theme ? "Selected" : "Not selected")
                }
            }
            Text("Patterns decorate the workspace, toolbar and notebook trim. Paper stays clear for writing. Themes work with Light, Dark and Follow Mac.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}
