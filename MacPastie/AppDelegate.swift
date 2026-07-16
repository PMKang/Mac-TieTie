//
//  AppDelegate.swift
//  MacPastie - 菜单栏图标 & 弹出面板管理
//  Author: akang
//

import AppKit
import SwiftUI

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {

    static weak var shared: AppDelegate?

    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var preferencesWindow: NSWindow?
    private var aboutWindow: NSWindow?
    private var controlCenterWindow: NSWindow?
    private let accessibilityPromptedKey = "accessibilityPrompted.designatedRequirement.v1"
    private var didStart = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        start()
    }

    func start() {
        guard !didStart else { return }
        didStart = true
        AppDelegate.shared = self
        ProcessInfo.processInfo.disableAutomaticTermination("阿康的 Mac 贴贴需要持续监听全局快捷键")

        // 同时保留 Dock 与菜单栏入口：Dock 负责打开完整控制中心，菜单栏负责快速贴窗。
        NSApp.setActivationPolicy(.regular)

        // 预热页内 GitHub Release 更新器；实际联网检查只在用户点击时发生。
        _ = UpdaterManager.shared

        setupStatusItem()
        setupPopover()
        registerHotkeys(attempt: 1)

        // 这是一个带 Dock 图标的完整应用，不让用户第一次打开时只看到
        // 一个没有反应的图标。菜单栏仍保留为快速贴窗入口。
        DispatchQueue.main.async {
            self.openControlCenter()
        }

        // 首次安装只主动请求一次；用户拒绝后不在每次启动时重复弹窗。
        if !WindowManager.shared.hasAccessibilityPermission(),
           !UserDefaults.standard.bool(forKey: accessibilityPromptedKey) {
            UserDefaults.standard.set(true, forKey: accessibilityPromptedKey)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                WindowManager.shared.requestAccessibilityPermission()
            }
        }
    }

    private func registerHotkeys(attempt: Int) {
        // 等主运行循环就绪后注册；如果系统仍在释放旧进程的热键，有限重试。
        DispatchQueue.main.asyncAfter(deadline: .now() + (attempt == 1 ? 0.25 : 0.75)) {
            let succeeded = HotkeyStore.shared.activateStoredConfigs()
            if !succeeded, attempt < 4 {
                self.registerHotkeys(attempt: attempt + 1)
            }
        }
    }

    // MARK: - Status Bar

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "rectangle.3.group", accessibilityDescription: "阿康的 Mac 贴贴")
            button.image?.isTemplate = true
            button.action = #selector(togglePopover)
            button.target = self
        }
    }

    @objc private func togglePopover() {
        if let button = statusItem.button {
            if popover.isShown {
                popover.performClose(nil)
            } else {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                popover.contentViewController?.view.window?.makeKey()
            }
        }
    }

    // MARK: - Popover

    private func setupPopover() {
        popover = NSPopover()
        popover.contentSize = NSSize(width: 400, height: 380)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: MenuPanelView())
    }

    func closePopover() {
        popover.performClose(nil)
    }

    // MARK: - Control Center

    /// Opens the one persistent control-center window and optionally brings a
    /// specific page to the foreground. Menu/Dock callers use the default
    /// `snap` page; deep links such as Preferences can select another page.
    func openControlCenter(section: ControlCenterView.Section = .snap) {
        // Must happen before `activate`: once MacPastie is key, the system's
        // frontmost app is our own control center rather than the window the
        // user intended to arrange. The manager refuses to capture ourselves.
        _ = WindowManager.shared.captureFrontmostTarget()

        if let window = controlCenterWindow {
            requestControlCenterSection(section)
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1120, height: 720),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "阿康的 Mac 贴贴"
        window.minSize = NSSize(width: 860, height: 580)
        window.contentViewController = NSHostingController(rootView: ControlCenterView(initialSection: section))
        window.center()
        window.isReleasedWhenClosed = false
        window.setFrameAutosaveName("MacPastieControlCenter")
        controlCenterWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func requestControlCenterSection(_ section: ControlCenterView.Section) {
        NotificationCenter.default.post(
            name: ControlCenterView.sectionRequestNotification,
            object: section
        )
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        // 控制中心被关闭后，从 Dock 回来时要恢复它。点菜单栏图标只打开
        // Popover，不额外打断用户；真正已有窗口时也不重复创建。
        guard didStart,
              !popover.isShown,
              controlCenterWindow?.isVisible != true else { return }
        openControlCenter()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            openControlCenter()
        }
        return true
    }

    func openAbout() {
        openControlCenter(section: .about)
    }

    func closeAbout() {
        aboutWindow?.performClose(nil)
    }

    func openPreferences() {
        openControlCenter(section: .settings)
    }
}
