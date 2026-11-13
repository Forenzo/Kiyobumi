import SwiftUI
import AppKit

/// Interface appearance is a local preference, never part of a notebook.
enum NotebookAppearance: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var title: String {
        switch self {
        case .system: return "Follow Mac"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }
}

@MainActor
final class AppearancePreferences: ObservableObject {
    static let shared = AppearancePreferences()
    private let key = "kiyobumi.interfaceAppearance"
    @Published var selection: NotebookAppearance {
        didSet {
            UserDefaults.standard.set(selection.rawValue, forKey: key)
            apply()
        }
    }

    @Published var theme: RetroTheme {
        didSet { UserDefaults.standard.set(theme.rawValue, forKey: "kiyobumi.retroTheme") }
    }

    private init() {
        theme = RetroTheme(rawValue: UserDefaults.standard.string(forKey: "kiyobumi.retroTheme") ?? "") ?? .classic
        selection = NotebookAppearance(rawValue: UserDefaults.standard.string(forKey: "kiyobumi.interfaceAppearance") ?? "") ?? .system
    }

    func apply() {
        // App-wide appearance also covers native panels and separately hosted
        // library/new-notebook windows. nil restores live system following.
        switch selection {
        case .system: NSApp.appearance = nil
        case .light: NSApp.appearance = NSAppearance(named: .aqua)
        case .dark: NSApp.appearance = NSAppearance(named: .darkAqua)
        }
    }
}
