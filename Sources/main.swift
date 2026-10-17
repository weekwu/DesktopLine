import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    let store = SettingsStore()
    var settings = Settings()
    var overlay: DesktopOverlay!
    var preferences: PreferencesController?
    var statusItem: NSStatusItem!
    var lockItem: NSMenuItem!
    var visibleItem: NSMenuItem!
    var observers: [NSObjectProtocol] = []
    var saveError: Error?
    var presetMenus: [NSMenu] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let existing = NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier ?? "local.week.DesktopLine")
            .first(where: { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }) {
            existing.activate()
            NSApp.terminate(nil)
            return
        }
        let firstRun = !FileManager.default.fileExists(atPath: store.url.path)
        do { settings = try store.load() } catch { saveError = error }
        overlay = DesktopOverlay()
        overlay.didMove = { [weak self] position in
            guard let self else { return }
            settings.screenPosition = position
            save()
            preferences?.sync(settings: settings, locked: overlay.locked)
        }
        overlay.apply(settings)
        if settings.screenPosition == nil {
            settings.screenPosition = DesktopGeometry.anchor(frame: overlay.window.frame, screen: overlay.screen.frame)
            settings.savePreset(at: 1, name: "原桌面位置")
            settings.applyPreset(at: 0)
            if settings.text == "You’ll never be ready.", let message = store.lockMessage(), !message.isEmpty {
                settings.text = message
            }
            overlay.apply(settings)
            save()
        }
        buildMenu()
        buildEditMenu()
        observers.append(NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
                            object: nil, queue: .main) { [weak self] _ in self?.refreshDesktop() })
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.activeSpaceDidChangeNotification,
                            object: nil, queue: .main) { [weak self] _ in
            guard let self else { return }; overlay.apply(settings)
        })
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification,
                            object: nil, queue: .main) { [weak self] _ in self?.refreshDesktop() })
        if firstRun { save(); edit() }
        if saveError != nil { edit() }
    }

    private func buildMenu() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "text.quote", accessibilityDescription: "桌面一句")
            button.image?.isTemplate = true
            button.toolTip = "桌面一句 · 修改文字与位置"
            button.setAccessibilityLabel("桌面一句")
        }
        let menu = NSMenu()
        menu.delegate = self
        menu.addItem(withTitle: "桌面一句", action: nil, keyEquivalent: "")
        menu.addItem(.separator())
        let editItem = menu.addItem(withTitle: "编辑文字与样式…", action: #selector(edit), keyEquivalent: ",")
        editItem.target = self
        lockItem = menu.addItem(withTitle: "解锁位置（拖动文字）", action: #selector(toggleLock), keyEquivalent: "")
        lockItem.target = self
        visibleItem = menu.addItem(withTitle: "显示桌面文字", action: #selector(toggleVisible), keyEquivalent: "")
        visibleItem.target = self
        let presetRoot = NSMenuItem(title: "调用保存的位置", action: nil, keyEquivalent: "")
        let presetMenu = NSMenu(title: "调用保存的位置")
        presetMenus.append(presetMenu); presetRoot.submenu = presetMenu; menu.addItem(presetRoot)
        let center = menu.addItem(withTitle: "恢复居中", action: #selector(centerPosition), keyEquivalent: "")
        center.target = self
        menu.addItem(.separator())
        let about = menu.addItem(withTitle: "关于桌面一句", action: #selector(showAbout), keyEquivalent: "")
        about.target = self
        let quit = menu.addItem(withTitle: "退出桌面一句", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        statusItem.menu = menu
        menuNeedsUpdate(menu)
    }

    // Accessory apps still need a real Edit menu for standard text-editor shortcuts.
    private func buildEditMenu() {
        let main = NSMenu()
        let appRoot = NSMenuItem(title: "桌面一句", action: nil, keyEquivalent: "")
        let appMenu = NSMenu(title: "桌面一句")
        appMenu.delegate = self
        let preferencesItem = appMenu.addItem(withTitle: "编辑文字与样式…", action: #selector(edit), keyEquivalent: ",")
        preferencesItem.target = self
        let positionItem = appMenu.addItem(withTitle: "切换位置锁定", action: #selector(toggleLock), keyEquivalent: "")
        positionItem.target = self
        let presetRoot = NSMenuItem(title: "调用保存的位置", action: nil, keyEquivalent: "")
        let presetMenu = NSMenu(title: "调用保存的位置")
        presetMenus.append(presetMenu); presetRoot.submenu = presetMenu; appMenu.addItem(presetRoot)
        appMenu.addItem(.separator())
        let quitItem = appMenu.addItem(withTitle: "退出桌面一句", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        appRoot.submenu = appMenu
        main.addItem(appRoot)
        let root = NSMenuItem(title: "编辑", action: nil, keyEquivalent: "")
        let edit = NSMenu(title: "编辑")
        for (title, action, key) in [
            ("撤销", Selector(("undo:")), "z"), ("剪切", #selector(NSText.cut(_:)), "x"),
            ("拷贝", #selector(NSText.copy(_:)), "c"), ("粘贴", #selector(NSText.paste(_:)), "v"),
            ("全选", #selector(NSText.selectAll(_:)), "a")
        ] { edit.addItem(withTitle: title, action: action, keyEquivalent: key) }
        root.submenu = edit
        main.addItem(root)
        NSApp.mainMenu = main
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        lockItem.title = overlay.locked ? "解锁位置（拖动文字）" : "锁定位置（恢复鼠标穿透）"
        visibleItem.state = settings.visible ? .on : .off
        for submenu in presetMenus {
            submenu.removeAllItems()
            for (index, preset) in settings.presets.enumerated() {
                let item = submenu.addItem(withTitle: "\(index + 1) · \(preset.name)\(preset.snapshot == nil ? "（未保存）" : "")",
                                           action: #selector(applyPresetFromMenu(_:)), keyEquivalent: "")
                item.target = self; item.tag = index
                item.isEnabled = preset.snapshot != nil
            }
            submenu.autoenablesItems = false
        }
    }

    func save() {
        do { try store.save(settings); saveError = nil } catch { saveError = error }
        preferences?.showSaveError(saveError)
        statusItem?.button?.toolTip = saveError == nil ? "桌面一句 · 修改文字与位置" : "桌面一句 · 设置保存失败"
    }

    func refreshDesktop() {
        overlay.apply(settings)
        preferences?.refreshScreens()
    }

    func setLocked(_ locked: Bool) {
        overlay.setLocked(locked)
        preferences?.syncLock(locked)
        statusItem.button?.image = NSImage(systemSymbolName: locked ? "text.quote" : "hand.draw",
                                         accessibilityDescription: locked ? "桌面一句" : "桌面一句 · 位置已解锁")
        statusItem.button?.image?.isTemplate = true
        statusItem.button?.toolTip = locked ? "桌面一句 · 修改文字与位置" : "桌面一句 · 可拖动文字，点击菜单锁定"
    }

    @objc func edit() {
        if preferences == nil {
            preferences = PreferencesController(settings: settings)
            preferences?.onChange = { [weak self] updated in
                guard let self else { return }
                settings = updated; overlay.apply(settings); save()
            }
            preferences?.onLockChange = { [weak self] locked in self?.setLocked(locked) }
            preferences?.onClose = { [weak self] in
                DispatchQueue.main.async { [weak self] in self?.preferences = nil }
            }
        }
        preferences?.sync(settings: settings, locked: overlay.locked)
        preferences?.showSaveError(saveError)
        NSApp.activate(ignoringOtherApps: true)
        preferences?.showWindow(nil)
        preferences?.window?.makeKeyAndOrderFront(nil)
    }

    @objc func toggleLock() { setLocked(!overlay.locked) }
    @objc func toggleVisible() {
        settings.visible.toggle(); overlay.apply(settings); save()
        preferences?.sync(settings: settings, locked: overlay.locked)
    }
    @objc func centerPosition() {
        settings.screenPosition = ScreenPosition(horizontal: 0.5, bottom: overlay.screen.frame.height / 2)
        overlay.apply(settings); save()
        preferences?.sync(settings: settings, locked: overlay.locked)
    }
    @objc func applyPresetFromMenu(_ sender: NSMenuItem) {
        settings.applyPreset(at: sender.tag); overlay.apply(settings); save()
        preferences?.sync(settings: settings, locked: overlay.locked)
    }
    @objc func showAbout() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "桌面一句 1.1"
        alert.informativeText = "原生桌面文字工具。无网络请求，无定时轮询，无第三方依赖。\n\n设置保存在：\n\(store.url.path)"
        alert.addButton(withTitle: "好")
        alert.runModal()
    }
    @objc func quit() { NSApp.terminate(nil) }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { edit(); return false }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationWillTerminate(_ notification: Notification) { NSColorPanel.shared.close() }
}

if CommandLine.arguments.contains("--self-test") {
    runSelfTests()
} else if CommandLine.arguments.contains("--screen-info") {
    for screen in NSScreen.screens {
        let preset = PositionSnapshot.lockScreen
        print("\(screen.localizedName): frame=\(screen.frame), scale=\(screen.backingScaleFactor), lockCenterBottom=\(preset.position.bottom)pt, font=13 regular")
    }
} else {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.setActivationPolicy(.accessory)
    app.delegate = delegate
    app.run()
}
