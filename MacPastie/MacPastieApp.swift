//
//  MacPastieApp.swift
//  MacPastie - macOS 窗口管理工具
//  Author: akang
//

import SwiftUI

@main
struct MacPastieApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // 纯菜单栏 App，所有 UI 由 AppDelegate 管理
        // Settings scene 留空避免与自定义 NSWindow 冲突
        Settings {
            EmptyView()
        }
    }
}
