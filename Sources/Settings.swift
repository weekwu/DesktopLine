import AppKit

enum TextWeight: String, Codable, CaseIterable {
    case regular, medium, semibold, bold
    var title: String {
        switch self { case .regular: return "常规"; case .medium: return "中等"; case .semibold: return "半粗"; case .bold: return "粗体" }
    }
    var value: NSFont.Weight {
        switch self { case .regular: return .regular; case .medium: return .medium; case .semibold: return .semibold; case .bold: return .bold }
    }
}

struct ScreenPosition: Codable, Equatable {
    var horizontal: Double
    // Text container center, in logical points measured from the full screen bottom.
    var bottom: Double
}

struct PositionSnapshot: Codable, Equatable {
    var position: ScreenPosition
    var fontSize: Double
    var weight: TextWeight
    var width: Double
    var screenID: UInt32

    static var lockScreen: PositionSnapshot {
        let frame = NSScreen.screens.first?.frame ?? NSRect(x: 0, y: 0, width: 1710, height: 1107)
        let font = NSFont.systemFont(ofSize: 13, weight: .regular)
        let descender = ceil(-font.descender)
        let layoutHeight = NSLayoutManager().defaultLineHeight(for: font)
        // LUI2's message scroll container has a 17pt minimum height; its text is top-aligned.
        let bottom = frame.height * 0.06 + floor(min(frame.width, frame.height) * 0.05)
            + 148.5 - descender + (17 - layoutHeight) / 2
        return PositionSnapshot(position: ScreenPosition(horizontal: 0.5, bottom: bottom),
                                fontSize: 13, weight: .regular, width: 408, screenID: 0)
    }
}

struct PositionPreset: Codable, Equatable {
    var name: String
    var snapshot: PositionSnapshot?
    static var defaults: [PositionPreset] {
        [PositionPreset(name: "锁屏对齐", snapshot: .lockScreen)] +
            (2...5).map { PositionPreset(name: "位置 \($0)", snapshot: nil) }
    }
}

struct Settings: Codable, Equatable {
    var text = "You’ll never be ready."
    var fontSize: Double = 24
    var red: Double = 1
    var green: Double = 1
    var blue: Double = 1
    var opacity: Double = 1
    // Normalized travel across the usable desktop, measured from its top left.
    var x: Double = 0.5
    var y: Double = 0.68
    var width: Double = 640
    var screenID: UInt32 = 0
    var visible = true
    var fontWeight: TextWeight = .medium
    var screenPosition: ScreenPosition?
    var presets = PositionPreset.defaults

    init() {}

    // decodeIfPresent migrates v1.0 files without discarding the user's text or position.
    enum CodingKeys: String, CodingKey {
        case text, fontSize, red, green, blue, opacity, x, y, width, screenID, visible
        case fontWeight, screenPosition, presets
    }
    init(from decoder: Decoder) throws {
        self.init()
        let c = try decoder.container(keyedBy: CodingKeys.self)
        text = try c.decodeIfPresent(String.self, forKey: .text) ?? text
        fontSize = try c.decodeIfPresent(Double.self, forKey: .fontSize) ?? fontSize
        red = try c.decodeIfPresent(Double.self, forKey: .red) ?? red
        green = try c.decodeIfPresent(Double.self, forKey: .green) ?? green
        blue = try c.decodeIfPresent(Double.self, forKey: .blue) ?? blue
        opacity = try c.decodeIfPresent(Double.self, forKey: .opacity) ?? opacity
        x = try c.decodeIfPresent(Double.self, forKey: .x) ?? x
        y = try c.decodeIfPresent(Double.self, forKey: .y) ?? y
        width = try c.decodeIfPresent(Double.self, forKey: .width) ?? width
        screenID = try c.decodeIfPresent(UInt32.self, forKey: .screenID) ?? screenID
        visible = try c.decodeIfPresent(Bool.self, forKey: .visible) ?? visible
        fontWeight = try c.decodeIfPresent(TextWeight.self, forKey: .fontWeight) ?? fontWeight
        screenPosition = try c.decodeIfPresent(ScreenPosition.self, forKey: .screenPosition)
        presets = try c.decodeIfPresent([PositionPreset].self, forKey: .presets) ?? presets
    }

    func snapshot() -> PositionSnapshot? {
        guard let position = screenPosition else { return nil }
        return PositionSnapshot(position: position, fontSize: fontSize, weight: fontWeight, width: width, screenID: screenID)
    }

    mutating func applyPreset(at index: Int) {
        guard presets.indices.contains(index), let preset = presets[index].snapshot else { return }
        screenPosition = preset.position
        fontSize = preset.fontSize
        fontWeight = preset.weight
        width = preset.width
        screenID = preset.screenID
        normalize()
    }

    mutating func savePreset(at index: Int, name: String) {
        guard presets.indices.contains(index), let snapshot = snapshot() else { return }
        presets[index] = PositionPreset(name: name, snapshot: snapshot)
        normalize()
    }

    var color: NSColor {
        NSColor(srgbRed: red, green: green, blue: blue, alpha: opacity)
    }

    mutating func normalize() {
        func clamp(_ value: Double, _ range: ClosedRange<Double>, fallback: Double) -> Double {
            value.isFinite ? min(max(value, range.lowerBound), range.upperBound) : fallback
        }
        fontSize = clamp(fontSize, 10...120, fallback: 24)
        width = clamp(width, 120...2400, fallback: 640)
        x = clamp(x, 0...1, fallback: 0.5)
        y = clamp(y, 0...1, fallback: 0.68)
        red = clamp(red, 0...1, fallback: 1)
        green = clamp(green, 0...1, fallback: 1)
        blue = clamp(blue, 0...1, fallback: 1)
        opacity = clamp(opacity, 0.1...1, fallback: 1)
        if var position = screenPosition {
            position.horizontal = clamp(position.horizontal, 0...1, fallback: 0.5)
            position.bottom = clamp(position.bottom, 0...20000, fallback: 250)
            screenPosition = position
        }
        presets = Array(presets.prefix(5))
        while presets.count < 5 { presets.append(PositionPreset.defaults[presets.count]) }
        for i in presets.indices {
            presets[i].name = String(presets[i].name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(32))
            if presets[i].name.isEmpty { presets[i].name = PositionPreset.defaults[i].name }
            if var snapshot = presets[i].snapshot {
                snapshot.position.horizontal = clamp(snapshot.position.horizontal, 0...1, fallback: 0.5)
                snapshot.position.bottom = clamp(snapshot.position.bottom, 0...20000, fallback: 250)
                snapshot.fontSize = clamp(snapshot.fontSize, 10...120, fallback: 13)
                snapshot.width = clamp(snapshot.width, 120...2400, fallback: 640)
                presets[i].snapshot = snapshot
            }
        }
    }
}

final class SettingsStore {
    let url: URL

    init(url: URL? = nil) {
        self.url = url ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("DesktopLine/settings.json")
    }

    func load() throws -> Settings {
        guard FileManager.default.fileExists(atPath: url.path) else { return Settings() }
        var settings = try JSONDecoder().decode(Settings.self, from: Data(contentsOf: url))
        settings.normalize()
        return settings
    }

    func lockMessage() -> String? {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: "/Library/Preferences/com.apple.loginwindow.plist")),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        else { return nil }
        return plist["LoginwindowText"] as? String
    }

    func save(_ settings: Settings) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(settings).write(to: url, options: .atomic)
    }
}

enum DesktopGeometry {
    static func anchoredOrigin(size: NSSize, screen: NSRect, position: ScreenPosition) -> NSPoint {
        let proposed = NSPoint(x: screen.minX + screen.width * position.horizontal - size.width / 2,
                               y: screen.minY + position.bottom - size.height / 2)
        return NSPoint(x: min(max(proposed.x, screen.minX), max(screen.minX, screen.maxX - size.width)),
                       y: min(max(proposed.y, screen.minY), max(screen.minY, screen.maxY - size.height)))
    }

    static func anchor(frame: NSRect, screen: NSRect) -> ScreenPosition {
        ScreenPosition(horizontal: (frame.midX - screen.minX) / screen.width, bottom: frame.midY - screen.minY)
    }
    static func origin(size: NSSize, visibleFrame: NSRect, x: Double, y: Double) -> NSPoint {
        NSPoint(x: visibleFrame.minX + max(0, visibleFrame.width - size.width) * x,
                y: visibleFrame.maxY - size.height - max(0, visibleFrame.height - size.height) * y)
    }

    static func position(frame: NSRect, visibleFrame: NSRect) -> (Double, Double) {
        let width = max(1, visibleFrame.width - frame.width)
        let height = max(1, visibleFrame.height - frame.height)
        return (min(1, max(0, (frame.minX - visibleFrame.minX) / width)),
                min(1, max(0, (visibleFrame.maxY - frame.maxY) / height)))
    }
}
