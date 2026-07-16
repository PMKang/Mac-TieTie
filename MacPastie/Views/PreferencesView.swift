//
//  PreferencesView.swift
//  MacPastie - 偏好设置（快捷键 Tab + 通用 Tab）
//  Author: akang
//

import SwiftUI
import Carbon
import Carbon.HIToolbox
import ServiceManagement

struct PreferencesView: View {
    var body: some View {
        TabView {
            HotkeyPrefsView()
                .tabItem { Label("快捷键", systemImage: "keyboard") }
                .tag(0)

            GeneralPrefsView()
                .tabItem { Label("通用", systemImage: "gearshape") }
                .tag(1)
        }
        .frame(width: 520, height: 420)
        .padding()
    }
}

// MARK: - 快捷键设置

/// The former standalone settings window now points to the Dock control center,
/// where recording and system registration are kept in one source of truth.
struct HotkeyPrefsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("快捷键配置已移至控制中心", systemImage: "command")
                .font(.headline)
            Text("在那里可以录制 15 个贴窗动作的快捷键，并在系统成功注册后立即应用。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button("打开快捷键配置") {
                AppDelegate.shared?.openControlCenter(section: .shortcuts)
            }
            .buttonStyle(.borderedProminent)
            Spacer()
        }
        .padding()
    }
}

// MARK: - 通用设置

struct GeneralPrefsView: View {
    @State private var launchAtLogin = UserDefaults.standard.bool(forKey: "launchAtLogin")
    @State private var launchAtLoginError: String? = nil
    @State private var accessibilityGranted = WindowManager.shared.hasAccessibilityPermission()

    var body: some View {
        Form {
            LabeledContent("辅助功能权限") {
                HStack(spacing: 8) {
                    Circle()
                        .fill(accessibilityGranted ? Color.green : Color.orange)
                        .frame(width: 8, height: 8)
                    Text(accessibilityGranted ? "已开启" : "未开启")
                        .foregroundColor(.secondary)
                    if !accessibilityGranted {
                        Button("打开系统设置") {
                            WindowManager.shared.openAccessibilitySettings()
                        }
                    }
                }
            }

            Divider()

            Toggle("登录时启动", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { val in
                    updateLaunchAtLogin(enabled: val)
                }

            if let launchAtLoginError {
                Text(launchAtLoginError)
                    .font(.caption)
                    .foregroundColor(.orange)
            }

            Divider()

            LabeledContent("版本") {
                Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.2")
                    .foregroundColor(.secondary)
            }

            LabeledContent("作者") {
                Text("akang · 阿康AI探索号")
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .onAppear {
            accessibilityGranted = WindowManager.shared.hasAccessibilityPermission()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            accessibilityGranted = WindowManager.shared.hasAccessibilityPermission()
        }
    }

    private func updateLaunchAtLogin(enabled: Bool) {
        do {
            if #available(macOS 13.0, *) {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
                UserDefaults.standard.set(enabled, forKey: "launchAtLogin")
                launchAtLoginError = nil
            } else {
                throw LaunchAtLoginError.unsupported
            }
        } catch {
            launchAtLogin = !enabled
            launchAtLoginError = "登录启动设置失败：\(error.localizedDescription)"
        }
    }
}

private enum LaunchAtLoginError: LocalizedError {
    case unsupported

    var errorDescription: String? {
        switch self {
        case .unsupported:
            return "当前系统版本不支持自动登录启动设置"
        }
    }
}
