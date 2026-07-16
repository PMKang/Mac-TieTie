//
//  AppDelegate.swift
//  MacPastie - 菜单栏图标 & 弹出面板管理
//  Author: akang
//

import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {

    static weak var shared: AppDelegate?

    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var preferencesWindow: NSWindow?
    private var aboutWindow: NSWindow?
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

        // 纯菜单栏应用，不显示 Dock 图标
        NSApp.setActivationPolicy(.accessory)

        setupStatusItem()
        setupPopover()
        registerHotkeys(attempt: 1)

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
            let succeeded = HotkeyManager.shared.registerAll()
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

    func openAbout() {
        if let win = aboutWindow, win.isVisible {
            win.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 430, height: 500),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        win.title = "关于阿康的 Mac 贴贴"
        win.contentViewController = NSHostingController(rootView: AboutView())
        win.center()
        win.isReleasedWhenClosed = false
        aboutWindow = win
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func closeAbout() {
        aboutWindow?.performClose(nil)
    }

    func openPreferences() {
        if let win = preferencesWindow, win.isVisible {
            win.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 460),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        win.title = "阿康的 Mac 贴贴设置"
        win.contentViewController = NSHostingController(rootView: PreferencesView())
        win.center()
        win.isReleasedWhenClosed = false
        preferencesWindow = win
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
