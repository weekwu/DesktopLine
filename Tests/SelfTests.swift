import AppKit

func runSelfTests() {
    var checks = 0
    func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        guard condition() else { fputs("FAIL: \(message)\n", stderr); exit(1) }
        checks += 1
    }
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("DesktopLine-tests-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = SettingsStore(url: directory.appendingPathComponent("settings.json"))
    do {
        let defaults = try store.load()
        expect(defaults == Settings(), "Missing settings use defaults")
        var settings = Settings()
        settings.text = "第一句。\nA new line — 中文与 emoji 🌙"
        settings.fontSize = 37; settings.x = 0.23; settings.y = 0.81
        settings.red = 0.25; settings.green = 0.5; settings.blue = 0.75
        settings.opacity = 0.6; settings.screenID = 123; settings.visible = false
        try store.save(settings)
        let reloaded = try store.load()
        expect(reloaded == settings, "All user settings survive save / reload")
        let legacyData = Data(#"{"text":"My old sentence","fontSize":24,"x":0.23,"y":0.81,"red":0.4}"#.utf8)
        let legacy = try JSONDecoder().decode(Settings.self, from: legacyData)
        expect(legacy.text == "My old sentence" && legacy.x == 0.23 && legacy.red == 0.4,
               "Upgrade preserves v1.0 text, color and position")
        expect(legacy.screenPosition == nil && legacy.fontWeight == .medium && legacy.presets.count == 5,
               "Legacy files receive missing new fields without losing data")
        var slotted = settings
        slotted.screenPosition = ScreenPosition(horizontal: 0.41, bottom: 267.5)
        slotted.fontSize = 13.5; slotted.fontWeight = .semibold
        slotted.savePreset(at: 4, name: "我的固定位置")
        try store.save(slotted)
        var restoredSlots = try store.load()
        expect(restoredSlots == slotted, "Five slots, names, subpoint position and font weight survive restart")
        restoredSlots.screenPosition = ScreenPosition(horizontal: 0.9, bottom: 99)
        restoredSlots.fontSize = 70; restoredSlots.text = "Keep this new sentence"; restoredSlots.red = 0.8
        restoredSlots.applyPreset(at: 4)
        expect(restoredSlots.screenPosition == slotted.screenPosition && restoredSlots.fontSize == 13.5
               && restoredSlots.fontWeight == .semibold, "Applying saved slot restores position, size and weight")
        expect(restoredSlots.text == "Keep this new sentence" && restoredSlots.red == 0.8,
               "Applying a slot preserves the current sentence and color")
        let beforeEmpty = restoredSlots
        restoredSlots.applyPreset(at: 2); restoredSlots.applyPreset(at: 99)
        expect(restoredSlots == beforeEmpty, "Empty and invalid slots do not change the desktop")
        expect(slotted.presets[0].snapshot?.fontSize == 13 && slotted.presets[0].snapshot?.weight == .regular,
               "Lock-screen reference uses observed 13pt regular font")
        try Data("bad JSON".utf8).write(to: store.url)
        do { _ = try store.load(); expect(false, "Corrupt settings must report an error") } catch { checks += 1 }
        settings.fontSize = -8; settings.width = .infinity; settings.x = 2; settings.y = -.infinity
        settings.opacity = 0; settings.red = -1
        settings.normalize()
        expect(settings.fontSize == 10 && settings.width == 640, "Invalid sizes normalize")
        expect(settings.x == 1 && settings.y == 0.68 && settings.opacity == 0.1 && settings.red == 0,
               "Invalid positions / colors normalize")
        for screen in [NSRect(x: 0, y: 0, width: 1512, height: 945),
                       NSRect(x: -1920, y: -300, width: 1920, height: 1080)] {
            for (x, y) in [(0.0, 0.0), (1.0, 1.0), (0.23, 0.81)] {
                let size = NSSize(width: 400, height: 45)
                let frame = NSRect(origin: DesktopGeometry.origin(size: size, visibleFrame: screen, x: x, y: y), size: size)
                expect(screen.contains(frame), "Position stays inside each display")
                let (actualX, actualY) = DesktopGeometry.position(frame: frame, visibleFrame: screen)
                expect(abs(actualX - x) < 0.000001 && abs(actualY - y) < 0.000001,
                       "Drag coordinates round-trip across display origins")
                let anchor = DesktopGeometry.anchor(frame: frame, screen: screen)
                let anchored = DesktopGeometry.anchoredOrigin(size: size, screen: screen, position: anchor)
                expect(abs(anchored.x - frame.minX) < 0.000001 && abs(anchored.y - frame.minY) < 0.000001,
                       "Full-screen anchors preserve positions on displays with negative origins")
            }
        }
        _ = NSApplication.shared
        let overlay = DesktopOverlay()
        overlay.apply(Settings())
        expect(overlay.window.styleMask == .borderless, "Overlay is borderless")
        expect(!overlay.window.isOpaque && overlay.window.backgroundColor == NSColor.clear && !overlay.window.hasShadow,
               "Overlay is transparent and has no shadow")
        expect(overlay.window.level.rawValue > Int(CGWindowLevelForKey(.desktopWindow))
               && overlay.window.level.rawValue < NSWindow.Level.normal.rawValue,
               "Text is above wallpaper and below normal windows")
        expect(overlay.window.ignoresMouseEvents, "Mouse passes through by default")
        var lockStyle = Settings(); lockStyle.applyPreset(at: 0)
        overlay.apply(lockStyle)
        let placedAnchor = DesktopGeometry.anchor(frame: overlay.window.frame, screen: overlay.screen.frame)
        expect(abs(placedAnchor.bottom - lockStyle.screenPosition!.bottom) < 1,
               "Lock reference is positioned from full-screen bottom, independent of Dock")
        overlay.apply(Settings())
        let bitmap = overlay.textView.bitmapImageRepForCachingDisplay(in: overlay.textView.bounds)!
        overlay.textView.cacheDisplay(in: overlay.textView.bounds, to: bitmap)
        var clearPixels = 0
        var inkPixels = 0
        for x in 0..<bitmap.pixelsWide {
            for y in 0..<bitmap.pixelsHigh {
                let alpha = bitmap.colorAt(x: x, y: y)?.alphaComponent ?? 0
                if alpha == 0 { clearPixels += 1 }
                if alpha > 0.05 { inkPixels += 1 }
            }
        }
        expect(clearPixels > bitmap.pixelsWide * bitmap.pixelsHigh / 2 && inkPixels > 20,
               "Rendered text contains real transparent pixels around visible glyphs")
        expect(bitmap.colorAt(x: 0, y: 0)?.alphaComponent == 0,
               "No background or border is painted at window corners")
        overlay.setLocked(false)
        expect(!overlay.window.ignoresMouseEvents && overlay.textView.unlocked, "Unlock enables dragging")
        overlay.setLocked(true)
        expect(overlay.window.ignoresMouseEvents && !overlay.textView.unlocked, "Lock restores click-through")
        var hidden = Settings(); hidden.visible = false; overlay.apply(hidden)
        expect(!overlay.window.isVisible, "Hide removes overlay")
        hidden.visible = true; hidden.text = " \n "; overlay.apply(hidden)
        expect(!overlay.window.isVisible, "Blank content does not create an invisible click target")
        overlay.window.orderOut(nil)
        if let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns") {
            expect(NSImage(contentsOf: iconURL)?.representations.count ?? 0 >= 8,
                   "AppKit loads the bundled multi-resolution application icon")
        } else { expect(false, "Application icon must exist in the bundle") }
        print("PASS: \(checks) checks (migration, presets, pixel anchors, icon, persistence, transparency, lock, hide)")
    } catch {
        fputs("FAIL: \(error)\n", stderr)
        exit(1)
    }
}
