import SwiftUI
#if canImport(AppKit)
import AppKit
#endif

extension Color {
    init(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        var value: UInt64 = 0
        Scanner(string: s).scanHexInt64(&value)
        let r = Double((value >> 16) & 0xFF) / 255.0
        let g = Double((value >> 8) & 0xFF) / 255.0
        let b = Double(value & 0xFF) / 255.0
        let a = s.count == 8 ? Double((value >> 24) & 0xFF) / 255.0 : 1.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }

    var hex: String {
        #if canImport(AppKit)
        let c = NSColor(self).usingColorSpace(.sRGB)
        let r = Int(round((c?.redComponent ?? 0) * 255))
        let g = Int(round((c?.greenComponent ?? 0) * 255))
        let b = Int(round((c?.blueComponent ?? 0) * 255))
        return String(format: "#%02X%02X%02X", r, g, b)
        #else
        return "#000000"
        #endif
    }
}