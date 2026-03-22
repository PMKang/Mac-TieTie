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

struct HotkeyPrefsView: View {
    @State private var configs: [HotkeyAction: HotkeyConfig] = HotkeyManager.shared.configs
    @State private var recording: HotkeyAction? = nil

    private let groups: [(String, [HotkeyAction])] = [
        ("半屏", [.leftHalf, .rightHalf, .topHalf, .bottomHalf]),
        ("四角", [.topLeft, .topRight, .bottomLeft, .bottomRight]),
        ("三等分", [.leftThird, .centerThird, .rightThird]),
        ("2/3 & 其他", [.leftTwoThirds, .rightTwoThirds, .fullscreen, .center]),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(groups, id: \.0) { group in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(group.0)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.leading, 2)

                        ForEach(group.1, id: \.self) { action in
                            HotkeyRow(
                                action: action,
                                config: configs[action] ?? HotkeyConfig.defaults[action]!,
                                isRecording: recording == action
                            ) {
                                recording = (recording == action) ? nil : action
                            }
                        }
                    }
                }

                HStack {
                    Image(systemName: "info.circle")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("快捷键自定义功能即将支持")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
            .padding()
        }
    }
}

// MARK: - 单行快捷键

private struct HotkeyRow: View {
    let action: HotkeyAction
    let config: HotkeyConfig
    let isRecording: Bool
    let onTap: () -> Void

    var body: some View {
        HStack {
            Text(action.displayName)
                .frame(width: 100, alignment: .leading)
            Spacer()
            Text(hotkeyString)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(6)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(isRecording ? Color.orange.opacity(0.05) : Color.clear)
        .cornerRadius(6)
    }

    private var hotkeyString: String {
        var s = ""
        if config.modifiers & UInt32(controlKey) != 0 { s += "⌃" }
        if config.modifiers & UInt32(optionKey)  != 0 { s += "⌥" }
        if config.modifiers & UInt32(cmdKey)     != 0 { s += "⌘" }
        if config.modifiers & UInt32(shiftKey)   != 0 { s += "⇧" }
        return s + keyName(config.keyCode)
    }

    private func keyName(_ kc: UInt32) -> String {
        let map: [UInt32: String] = [
            UInt32(kVK_LeftArrow): "←", UInt32(kVK_RightArrow): "→",
            UInt32(kVK_UpArrow): "↑",   UInt32(kVK_DownArrow): "↓",
            UInt32(kVK_Return): "↩",
            UInt32(kVK_ANSI_U): "U", UInt32(kVK_ANSI_I): "I",
            UInt32(kVK_ANSI_J): "J", UInt32(kVK_ANSI_K): "K",
            UInt32(kVK_ANSI_D): "D", UInt32(kVK_ANSI_F): "F",
            UInt32(kVK_ANSI_G): "G", UInt32(kVK_ANSI_E): "E",
            UInt32(kVK_ANSI_T): "T", UInt32(kVK_ANSI_C): "C",
        ]
        return map[kc] ?? "?"
    }
}

// MARK: - 通用设置

struct GeneralPrefsView: View {
    @State private var launchAtLogin = UserDefaults.standard.bool(forKey: "launchAtLogin")
    @State private var launchAtLoginError: String? = nil

    var body: some View {
        Form {
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
