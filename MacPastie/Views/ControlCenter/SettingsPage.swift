//
//  SettingsPage.swift
//  MacPastie
//

import AppKit
import ServiceManagement
import SwiftUI

/// System-facing preferences for the control center.  Accessibility is only
/// observed here: the one-time system prompt remains owned by AppDelegate so
/// merely visiting Settings never becomes a repeated authorization prompt.
struct SettingsPage: View {
    @State private var accessibilityGranted = WindowManager.shared.hasAccessibilityPermission()
    @State private var launchAtLoginEnabled = false
    @State private var launchAtLoginMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                accessibilityCard
                launchAtLoginCard

                Text("权限状态会在你从系统设置回到应用时自动刷新。阿康的 Mac 贴贴只在首次启动时主动请求一次辅助功能权限，之后不会反复弹出授权提醒。")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(32)
            .frame(maxWidth: 760, alignment: .leading)
        }
        .onAppear(perform: refreshSystemStatus)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refreshSystemStatus()
        }
        .accessibilityIdentifier("settings-page")
    }

    private var accessibilityCard: some View {
        SettingsCard(
            symbolName: "accessibility",
            title: "辅助功能权限",
            subtitle: accessibilityGranted
                ? "已开启。现在可以移动和调整其他应用的窗口。"
                : "未开启。贴窗和跨屏功能需要此权限才能操作其他应用的窗口。"
        ) {
            StatusBadge(isGood: accessibilityGranted, goodText: "已开启", warningText: "未开启")

            if !accessibilityGranted {
                Button("打开系统设置") {
                    WindowManager.shared.openAccessibilitySettings()
                }
                .buttonStyle(.borderedProminent)
                .accessibilityHint("打开 macOS 的辅助功能权限页面")
            }
        }
    }

    private var launchAtLoginCard: some View {
        SettingsCard(
            symbolName: "power",
            title: "登录时启动",
            subtitle: "登录 Mac 后自动启动阿康的 Mac 贴贴，菜单栏与快捷键即可使用。"
        ) {
            Toggle("登录时启动", isOn: Binding(
                get: { launchAtLoginEnabled },
                set: { updateLaunchAtLogin(enabled: $0) }
            ))
            .toggleStyle(.switch)
            .labelsHidden()
            .accessibilityLabel("登录时启动")

            if let launchAtLoginMessage {
                Text(launchAtLoginMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 2)
            }
        }
    }

    private func refreshSystemStatus() {
        accessibilityGranted = WindowManager.shared.hasAccessibilityPermission()

        if #available(macOS 13.0, *) {
            let status = SMAppService.mainApp.status
            launchAtLoginEnabled = status == .enabled || status == .requiresApproval
            launchAtLoginMessage = launchAtLoginStatusMessage(status)
        } else {
            launchAtLoginEnabled = false
            launchAtLoginMessage = "当前系统版本不支持登录启动设置。"
        }
    }

    private func updateLaunchAtLogin(enabled: Bool) {
        guard #available(macOS 13.0, *) else {
            launchAtLoginEnabled = false
            launchAtLoginMessage = "当前系统版本不支持登录启动设置。"
            return
        }

        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            refreshSystemStatus()
        } catch {
            refreshSystemStatus()
            launchAtLoginMessage = "登录启动设置失败：\(error.localizedDescription)"
        }
    }

    @available(macOS 13.0, *)
    private func launchAtLoginStatusMessage(_ status: SMAppService.Status) -> String? {
        switch status {
        case .enabled:
            return "已开启，登录 Mac 后会自动启动。"
        case .requiresApproval:
            return "系统正在等待你确认登录启动设置。"
        case .notFound:
            return "系统暂时无法找到登录启动服务。"
        case .notRegistered:
            return nil
        @unknown default:
            return "登录启动状态暂时无法确认。"
        }
    }
}

private struct SettingsCard<Accessory: View>: View {
    let symbolName: String
    let title: String
    let subtitle: String
    @ViewBuilder let accessory: () -> Accessory

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: symbolName)
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 42, height: 42)
                    .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            accessory()
        }
        .padding(20)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct StatusBadge: View {
    let isGood: Bool
    let goodText: String
    let warningText: String

    var body: some View {
        Label(isGood ? goodText : warningText, systemImage: isGood ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
            .font(.subheadline.weight(.medium))
            .foregroundStyle(isGood ? Color.green : Color.orange)
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .background((isGood ? Color.green : Color.orange).opacity(0.12), in: Capsule())
            .accessibilityLabel(isGood ? goodText : warningText)
    }
}

#Preview {
    SettingsPage()
        .frame(width: 820, height: 620)
}
