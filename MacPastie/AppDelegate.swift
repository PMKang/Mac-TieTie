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

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.shared = self
        // 纯菜单栏应用，不显示 Dock 图标
        NSApp.setActivationPolicy(.accessory)

        setupStatusItem()
        setupPopover()
        HotkeyManager.shared.registerAll()

        // 启动时检查一次 Accessibility 权限，没有才引导
        if !WindowManager.shared.hasAccessibilityPermission() {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                WindowManager.shared.requestAccessibilityPermission()
            }
        }
    }

    // MARK: - Status Bar

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "rectangle.3.group", accessibilityDescription: "Mac贴贴")
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
        popover.contentSize = NSSize(width: 400, height: 430)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: MenuPanelView())
    }

    func closePopover() {
        popover.performClose(nil)
    }

    func openAbout() {
        print("[about] openAbout called, existing=\(aboutWindow != nil), visible=\(aboutWindow?.isVisible ?? false)")
        if let win = aboutWindow, win.isVisible {
            win.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 360),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        win.title = "关于 Mac贴贴"
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
        print("[prefs] openPreferences called, existing=\(preferencesWindow != nil), visible=\(preferencesWindow?.isVisible ?? false)")
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
        win.title = "Mac贴贴 设置"
        win.contentViewController = NSHostingController(rootView: PreferencesView())
        win.center()
        win.isReleasedWhenClosed = false
        preferencesWindow = win
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
