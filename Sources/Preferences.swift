import AppKit

final class PreferencesController: NSWindowController, NSTextViewDelegate, NSWindowDelegate {
    var settings: Settings
    var onChange: ((Settings) -> Void)?
    var onLockChange: ((Bool) -> Void)?
    var onClose: (() -> Void)?
    private var locked = true
    private let textEditor = NSTextView()
    private let sizeSlider = NSSlider(value: 24, minValue: 10, maxValue: 120, target: nil, action: nil)
    private let sizeValue = NSTextField(string: "24")
    private let weightPopup = NSPopUpButton()
    private let colorWell = NSColorWell()
    private let opacitySlider = NSSlider(value: 1, minValue: 0.1, maxValue: 1, target: nil, action: nil)
    private let widthSlider = NSSlider(value: 640, minValue: 120, maxValue: 1600, target: nil, action: nil)
    private let xSlider = NSSlider(value: 50, minValue: 0, maxValue: 100, target: nil, action: nil)
    private let ySlider = NSSlider(value: 68, minValue: 0, maxValue: 100, target: nil, action: nil)
    private let opacityValue = NSTextField(labelWithString: "100%")
    private let widthValue = NSTextField(labelWithString: "640 pt")
    private let xValue = NSTextField(labelWithString: "50%")
    private let yValue = NSTextField(labelWithString: "68%")
    private let offsetField = NSTextField(string: "0")
    private let bottomField = NSTextField(string: "250")
    private let offsetStepper = NSStepper()
    private let bottomStepper = NSStepper()
    private let coordinates = NSTextField(wrappingLabelWithString: "")
    private let screenPopup = NSPopUpButton()
    private let presetPopup = NSPopUpButton()
    private let presetName = NSTextField(string: "")
    private let applyButton = NSButton(title: "调用", target: nil, action: nil)
    private let presetNote = NSTextField(wrappingLabelWithString: "")
    private let lockButton = NSButton(title: "解锁并拖动文字", target: nil, action: nil)
    private let stateLabel = NSTextField(wrappingLabelWithString: "")
    private let saveLabel = NSTextField(labelWithString: "修改即时保存，重新打开后保留。")
    private var screenIDs: [UInt32] = []

    private var screen: NSScreen {
        NSScreen.screens.first { DesktopOverlay.id($0) == settings.screenID } ?? NSScreen.screens.first!
    }

    init(settings: Settings) {
        self.settings = settings
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 570, height: 730),
                              styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "桌面一句"
        window.isReleasedWhenClosed = false
        window.center()
        super.init(window: window)
        window.delegate = self
        buildUI()
        sync(settings: settings, locked: true)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func label(_ text: String, small: Bool = false) -> NSTextField {
        let field = NSTextField(wrappingLabelWithString: text)
        field.font = .systemFont(ofSize: small ? 11 : 13)
        if small { field.textColor = .secondaryLabelColor }
        return field
    }
    private func row(_ title: String, _ controls: [NSView]) -> NSStackView {
        let titleLabel = label(title)
        titleLabel.widthAnchor.constraint(equalToConstant: 66).isActive = true
        let row = NSStackView(views: [titleLabel] + controls)
        row.orientation = .horizontal; row.spacing = 10; row.alignment = .centerY
        return row
    }
    private func addFull(_ view: NSView, to stack: NSStackView) {
        stack.addArrangedSubview(view)
        view.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
    }
    private func form(in view: NSView) -> NSStackView {
        let stack = NSStackView()
        stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 18
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 18),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -18),
            stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 22)
        ])
        return stack
    }
    private func sliderRow(_ title: String, slider: NSSlider, value: NSTextField, action: Selector, in stack: NSStackView) {
        slider.target = self; slider.action = action; slider.setAccessibilityLabel(title)
        value.alignment = .right
        value.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        value.widthAnchor.constraint(equalToConstant: 60).isActive = true
        addFull(row(title, [slider, value]), to: stack)
    }
    private func buildUI() {
        guard let content = window?.contentView else { return }
        let root = form(in: content)
        root.spacing = 15
        let heading = label("让一句话，留在桌面。")
        heading.font = .systemFont(ofSize: 22, weight: .semibold)
        root.addArrangedSubview(heading)
        root.addArrangedSubview(label("透明背景 · 无边框 · 位于普通窗口后方", small: true))
        let tabs = NSTabView()
        let textTab = NSTabViewItem(identifier: "text"); textTab.label = "文字与样式"; textTab.view = NSView()
        let positionTab = NSTabViewItem(identifier: "position"); positionTab.label = "位置与保存槽"; positionTab.view = NSView()
        tabs.addTabViewItem(textTab); tabs.addTabViewItem(positionTab)
        addFull(tabs, to: root)
        tabs.heightAnchor.constraint(equalToConstant: 478).isActive = true
        buildTextForm(form(in: textTab.view!))
        buildPositionForm(form(in: positionTab.view!))
        lockButton.target = self; lockButton.action = #selector(toggleLock)
        lockButton.bezelStyle = .rounded
        let center = NSButton(title: "恢复居中", target: self, action: #selector(centerPosition))
        let done = NSButton(title: "完成并锁定", target: self, action: #selector(finish))
        done.keyEquivalent = "\r"; done.bezelStyle = .rounded
        root.addArrangedSubview(NSStackView(views: [lockButton, center, done]))
        stateLabel.font = .systemFont(ofSize: 11); stateLabel.textColor = .secondaryLabelColor
        addFull(stateLabel, to: root)
        saveLabel.font = .systemFont(ofSize: 11); saveLabel.textColor = .secondaryLabelColor
        root.addArrangedSubview(saveLabel)
    }

    private func buildTextForm(_ stack: NSStackView) {
        let scroll = NSScrollView()
        scroll.borderType = .bezelBorder; scroll.hasVerticalScroller = true; scroll.autohidesScrollers = true
        textEditor.isRichText = false; textEditor.allowsUndo = true
        textEditor.isAutomaticQuoteSubstitutionEnabled = false; textEditor.isAutomaticDashSubstitutionEnabled = false
        textEditor.font = .systemFont(ofSize: 17)
        textEditor.textContainerInset = NSSize(width: 10, height: 10)
        textEditor.isVerticallyResizable = true; textEditor.isHorizontallyResizable = false
        textEditor.autoresizingMask = [.width]
        textEditor.textContainer?.widthTracksTextView = true
        textEditor.delegate = self; textEditor.setAccessibilityLabel("桌面显示的文字")
        scroll.documentView = textEditor
        addFull(scroll, to: stack); scroll.heightAnchor.constraint(equalToConstant: 145).isActive = true
        sizeSlider.target = self; sizeSlider.action = #selector(sizeChanged); sizeSlider.setAccessibilityLabel("字号")
        sizeValue.alignment = .right; sizeValue.target = self; sizeValue.action = #selector(sizeTyped)
        sizeValue.setAccessibilityLabel("字号数值")
        sizeValue.widthAnchor.constraint(equalToConstant: 56).isActive = true
        sizeValue.formatter = numberFormatter(min: 10, max: 120)
        addFull(row("字号", [sizeSlider, sizeValue, label("pt", small: true)]), to: stack)
        weightPopup.addItems(withTitles: TextWeight.allCases.map(\.title))
        weightPopup.target = self; weightPopup.action = #selector(weightChanged); weightPopup.setAccessibilityLabel("字重")
        addFull(row("字重", [weightPopup]), to: stack)
        colorWell.target = self; colorWell.action = #selector(colorChanged); colorWell.supportsAlpha = false
        colorWell.setAccessibilityLabel("文字颜色"); colorWell.widthAnchor.constraint(equalToConstant: 52).isActive = true
        stack.addArrangedSubview(row("颜色", [colorWell,
            NSButton(title: "白色", target: self, action: #selector(whiteColor)),
            NSButton(title: "黑色", target: self, action: #selector(blackColor))]))
        sliderRow("不透明度", slider: opacitySlider, value: opacityValue, action: #selector(opacityChanged), in: stack)
        sliderRow("最大宽度", slider: widthSlider, value: widthValue, action: #selector(widthChanged), in: stack)
    }
    private func buildPositionForm(_ stack: NSStackView) {
        stack.spacing = 14
        sliderRow("水平位置", slider: xSlider, value: xValue, action: #selector(positionChanged), in: stack)
        sliderRow("垂直位置", slider: ySlider, value: yValue, action: #selector(positionChanged), in: stack)
        for (field, stepper, title, action) in [
            (offsetField, offsetStepper, "水平偏移", #selector(offsetStepped)),
            (bottomField, bottomStepper, "距屏幕底部", #selector(bottomStepped))
        ] {
            field.formatter = numberFormatter(min: -20000, max: 20000)
            field.target = self; field.action = #selector(coordinateTyped)
            field.alignment = .right; field.setAccessibilityLabel(title + "（pt）")
            field.widthAnchor.constraint(equalToConstant: 96).isActive = true
            stepper.minValue = -20000; stepper.maxValue = 20000
            stepper.target = self; stepper.action = action
            stepper.setAccessibilityLabel(title + "微调一个像素")
            addFull(row(title, [field, stepper, label("pt", small: true)]), to: stack)
        }
        coordinates.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        coordinates.textColor = .secondaryLabelColor
        addFull(coordinates, to: stack)
        screenPopup.target = self; screenPopup.action = #selector(screenChanged); screenPopup.setAccessibilityLabel("显示器")
        addFull(row("显示器", [screenPopup]), to: stack)
        let divider = NSBox(); divider.boxType = .separator; addFull(divider, to: stack)
        presetPopup.target = self; presetPopup.action = #selector(presetSelected); presetPopup.setAccessibilityLabel("位置保存槽")
        addFull(row("保存槽", [presetPopup]), to: stack)
        presetName.target = self; presetName.action = #selector(renamePreset)
        presetName.placeholderString = "给这个位置起个名字"; presetName.setAccessibilityLabel("位置槽名称")
        addFull(row("名称", [presetName]), to: stack)
        applyButton.target = self; applyButton.action = #selector(applyPreset)
        let save = NSButton(title: "将当前位置存入此槽", target: self, action: #selector(savePreset))
        let reset = NSButton(title: "还原锁屏槽", target: self, action: #selector(resetLockPreset))
        stack.addArrangedSubview(NSStackView(views: [applyButton, save, reset]))
        presetNote.font = .systemFont(ofSize: 11); presetNote.textColor = .secondaryLabelColor
        addFull(presetNote, to: stack)
    }
    private func numberFormatter(min: Double, max: Double) -> NumberFormatter {
        let formatter = NumberFormatter()
        formatter.minimum = NSNumber(value: min); formatter.maximum = NSNumber(value: max)
        formatter.allowsFloats = true; formatter.maximumFractionDigits = 2
        return formatter
    }
    func sync(settings: Settings, locked: Bool) {
        self.settings = settings
        if textEditor.string != settings.text { textEditor.string = settings.text }
        sizeSlider.doubleValue = settings.fontSize; sizeValue.doubleValue = settings.fontSize
        weightPopup.selectItem(at: TextWeight.allCases.firstIndex(of: settings.fontWeight) ?? 1)
        colorWell.color = settings.color.withAlphaComponent(1)
        opacitySlider.doubleValue = settings.opacity; widthSlider.doubleValue = settings.width
        updateValues(); refreshScreens(); refreshPresets(); syncLock(locked)
    }
    func refreshScreens() {
        screenIDs = NSScreen.screens.map(DesktopOverlay.id)
        screenPopup.removeAllItems()
        for (index, screen) in NSScreen.screens.enumerated() {
            screenPopup.addItem(withTitle: "\(screen.localizedName)\(index == 0 ? "（主屏幕）" : "")")
        }
        screenPopup.selectItem(at: screenIDs.firstIndex(of: settings.screenID) ?? 0)
        updateValues()
    }
    private func refreshPresets() {
        let selected = max(0, min(4, presetPopup.indexOfSelectedItem))
        presetPopup.removeAllItems()
        for (index, preset) in settings.presets.enumerated() {
            presetPopup.addItem(withTitle: "\(index + 1) · \(preset.name)\(preset.snapshot == nil ? "（空）" : "")")
        }
        presetPopup.selectItem(at: selected)
        updatePresetFields()
    }
    private func updatePresetFields() {
        let index = presetPopup.indexOfSelectedItem
        guard settings.presets.indices.contains(index) else { return }
        presetName.stringValue = settings.presets[index].name
        applyButton.isEnabled = settings.presets[index].snapshot != nil
        presetNote.stringValue = "每槽保存位置、字号、字重和换行宽度；不改句子与颜色。\n锁屏槽可按单像素微调后覆盖保存。"
    }
    func syncLock(_ locked: Bool) {
        self.locked = locked
        lockButton.title = locked ? "解锁并拖动文字" : "锁定位置"
        stateLabel.stringValue = locked ? "已锁定：鼠标穿透，不影响点击桌面和选择文件。" : "已解锁：在桌面上拖动文字；调整后请锁定。"
    }
    func showSaveError(_ error: Error?) {
        saveLabel.stringValue = error.map { "保存失败：\($0.localizedDescription)" } ?? "修改即时保存，重新打开后保留。"
        saveLabel.textColor = error == nil ? .secondaryLabelColor : .systemRed
    }
    private func updateValues() {
        opacityValue.stringValue = "\(Int((settings.opacity * 100).rounded()))%"
        widthValue.stringValue = "\(Int(settings.width)) pt"
        let frame = screen.frame
        let position = settings.screenPosition ?? ScreenPosition(horizontal: 0.5, bottom: frame.height * 0.3)
        xSlider.doubleValue = position.horizontal * 100
        ySlider.doubleValue = (1 - position.bottom / frame.height) * 100
        xValue.stringValue = String(format: "%.1f%%", xSlider.doubleValue)
        yValue.stringValue = String(format: "%.1f%%", ySlider.doubleValue)
        offsetField.doubleValue = (position.horizontal - 0.5) * frame.width
        bottomField.doubleValue = position.bottom
        offsetStepper.doubleValue = offsetField.doubleValue; bottomStepper.doubleValue = position.bottom
        let scale = screen.backingScaleFactor
        offsetStepper.increment = 1 / scale; bottomStepper.increment = 1 / scale
        let x = position.horizontal * frame.width, y = frame.height - position.bottom
        coordinates.stringValue = String(format: "文字中心（左上为原点）：%.1f, %.1f pt\n对应 %.0f× 像素：%.0f, %.0f px · Dock 显隐不改变位置", x, y, scale, x * scale, y * scale)
    }
    private func changed() { settings.normalize(); updateValues(); onChange?(settings) }
    func textDidChange(_ notification: Notification) { settings.text = textEditor.string; changed() }
    @objc private func sizeChanged() { settings.fontSize = (sizeSlider.doubleValue * 2).rounded() / 2; sizeValue.doubleValue = settings.fontSize; changed() }
    @objc private func sizeTyped() { settings.fontSize = sizeValue.doubleValue; settings.normalize(); sizeValue.doubleValue = settings.fontSize; sizeSlider.doubleValue = settings.fontSize; changed() }
    @objc private func weightChanged() { settings.fontWeight = TextWeight.allCases[weightPopup.indexOfSelectedItem]; changed() }
    @objc private func colorChanged() {
        guard let color = colorWell.color.usingColorSpace(.sRGB) else { return }
        settings.red = color.redComponent; settings.green = color.greenComponent; settings.blue = color.blueComponent; changed()
    }
    @objc private func whiteColor() { colorWell.color = .white; colorChanged() }
    @objc private func blackColor() { colorWell.color = .black; colorChanged() }
    @objc private func opacityChanged() { settings.opacity = opacitySlider.doubleValue; changed() }
    @objc private func widthChanged() { settings.width = widthSlider.doubleValue.rounded(); changed() }
    @objc private func positionChanged() {
        settings.screenPosition = ScreenPosition(horizontal: xSlider.doubleValue / 100,
                                                 bottom: screen.frame.height * (1 - ySlider.doubleValue / 100)); changed()
    }
    @objc private func coordinateTyped() {
        settings.screenPosition = ScreenPosition(horizontal: 0.5 + offsetField.doubleValue / screen.frame.width,
                                                 bottom: bottomField.doubleValue); changed()
    }
    @objc private func offsetStepped() { offsetField.doubleValue = offsetStepper.doubleValue; coordinateTyped() }
    @objc private func bottomStepped() { bottomField.doubleValue = bottomStepper.doubleValue; coordinateTyped() }
    @objc private func screenChanged() {
        guard screenIDs.indices.contains(screenPopup.indexOfSelectedItem) else { return }
        settings.screenID = screenIDs[screenPopup.indexOfSelectedItem]; changed()
    }
    @objc private func presetSelected() { updatePresetFields() }
    @objc private func renamePreset() {
        let index = presetPopup.indexOfSelectedItem
        guard settings.presets.indices.contains(index) else { return }
        settings.presets[index].name = presetName.stringValue; changed(); refreshPresets()
    }
    @objc private func savePreset() {
        window?.makeFirstResponder(nil)
        settings.savePreset(at: presetPopup.indexOfSelectedItem, name: presetName.stringValue)
        changed(); refreshPresets()
        presetNote.stringValue = "已将当前位置、字号、字重和换行宽度保存到此槽。"
    }
    @objc private func applyPreset() {
        settings.applyPreset(at: presetPopup.indexOfSelectedItem)
        changed(); sync(settings: settings, locked: locked)
    }
    @objc private func resetLockPreset() {
        settings.presets[0] = PositionPreset.defaults[0]
        presetPopup.selectItem(at: 0); changed(); refreshPresets()
        presetNote.stringValue = "已还原锁屏预设。点「调用」应用，也可以继续微调。"
    }
    @objc private func centerPosition() {
        settings.screenPosition = ScreenPosition(horizontal: 0.5, bottom: screen.frame.height / 2); changed()
    }
    @objc private func toggleLock() { onLockChange?(!locked) }
    @objc private func finish() { window?.makeFirstResponder(nil); onLockChange?(true); close() }
    func windowWillClose(_ notification: Notification) { colorWell.deactivate(); onLockChange?(true); onClose?() }
}
