import AppKit

final class TextWindow: NSWindow {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

final class DesktopTextView: NSView {
    var attributedText = NSAttributedString()
    var unlocked = false { didSet { window?.invalidateCursorRects(for: self) } }
    var didMove: ((NSRect) -> Void)?
    private var dragMouse = NSPoint.zero
    private var dragOrigin = NSPoint.zero
    var dragBounds = NSRect.zero

    override var isOpaque: Bool { false }
    override var acceptsFirstResponder: Bool { false }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { unlocked }

    override func draw(_ dirtyRect: NSRect) {
        attributedText.draw(with: bounds.insetBy(dx: 4, dy: 4),
                            options: [.usesLineFragmentOrigin, .usesFontLeading])
    }

    override func resetCursorRects() {
        if unlocked { addCursorRect(bounds, cursor: .openHand) }
    }

    override func mouseDown(with event: NSEvent) {
        guard unlocked, let window else { return }
        dragMouse = NSEvent.mouseLocation
        dragOrigin = window.frame.origin
        NSCursor.closedHand.push()
    }

    override func mouseDragged(with event: NSEvent) {
        guard unlocked, let window else { return }
        let mouse = NSEvent.mouseLocation
        let origin = NSPoint(
            x: min(max(dragOrigin.x + mouse.x - dragMouse.x, dragBounds.minX),
                   max(dragBounds.minX, dragBounds.maxX - window.frame.width)),
            y: min(max(dragOrigin.y + mouse.y - dragMouse.y, dragBounds.minY),
                   max(dragBounds.minY, dragBounds.maxY - window.frame.height)))
        window.setFrameOrigin(origin)
    }

    override func mouseUp(with event: NSEvent) {
        guard unlocked, let window else { return }
        NSCursor.pop()
        didMove?(window.frame)
    }
}

final class DesktopOverlay {
    let window: TextWindow
    let textView = DesktopTextView()
    private(set) var settings = Settings()
    private(set) var locked = true
    var didMove: ((ScreenPosition) -> Void)?

    init() {
        window = TextWindow(contentRect: .zero, styleMask: .borderless, backing: .buffered, defer: false)
        window.title = "桌面一句 · 文字"
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.isReleasedWhenClosed = false
        window.hidesOnDeactivate = false
        window.canHide = false
        window.animationBehavior = .none
        // Stay in the desktop layer, above Finder's transparent desktop hit surface.
        // Otherwise Finder can intercept dragging even when our window is unlocked.
        window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        window.contentView = textView
        textView.didMove = { [weak self] frame in
            guard let self else { return }
            didMove?(DesktopGeometry.anchor(frame: frame, screen: screen.frame))
        }
    }

    var screen: NSScreen {
        NSScreen.screens.first { Self.id($0) == settings.screenID } ?? NSScreen.screens.first!
    }

    static func id(_ screen: NSScreen) -> UInt32 {
        (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? 0
    }

    func setLocked(_ locked: Bool) {
        self.locked = locked
        window.ignoresMouseEvents = locked
        textView.unlocked = !locked
    }

    func apply(_ settings: Settings) {
        self.settings = settings
        let screenFrame = settings.screenPosition == nil ? screen.visibleFrame : screen.frame
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineBreakMode = .byWordWrapping
        let string = NSAttributedString(string: settings.text, attributes: [
            .font: NSFont.systemFont(ofSize: settings.fontSize, weight: settings.fontWeight.value),
            .foregroundColor: settings.color,
            .paragraphStyle: paragraph
        ])
        let availableWidth = max(40, min(settings.width, screenFrame.width - 32))
        let measured = string.boundingRect(with: NSSize(width: availableWidth - 8, height: .greatestFiniteMagnitude),
                                          options: [.usesLineFragmentOrigin, .usesFontLeading])
        let size = NSSize(width: min(availableWidth, max(24, ceil(measured.width) + 8)),
                          height: min(screenFrame.height, max(24, ceil(measured.height) + 8)))
        let origin = settings.screenPosition.map { DesktopGeometry.anchoredOrigin(size: size, screen: screenFrame, position: $0) }
            ?? DesktopGeometry.origin(size: size, visibleFrame: screenFrame, x: settings.x, y: settings.y)
        window.setFrame(NSRect(origin: origin, size: size), display: false)
        textView.frame = NSRect(origin: .zero, size: size)
        textView.attributedText = string
        textView.dragBounds = screenFrame
        textView.needsDisplay = true
        if settings.visible && !settings.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            window.orderFrontRegardless()
        } else {
            window.orderOut(nil)
        }
    }
}
