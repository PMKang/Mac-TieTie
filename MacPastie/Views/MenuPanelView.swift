//
//  MenuPanelView.swift
//  MacPastie - 贴窗弹出面板
//  Author: akang
//

import SwiftUI

struct MenuPanelView: View {
    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 18)
                .padding(.vertical, 14)

            Divider()

            SnapGridView(hotkeyStore: .shared)
                .frame(height: 260)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

            Divider()

            bottomBar
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
        }
        .frame(width: 400)
        .background(Color(NSColor.windowBackgroundColor))
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "rectangle.3.group.fill")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.tint)
                .frame(width: 34, height: 34)
                .background(Color.accentColor.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text("阿康的 Mac 贴贴")
                    .font(.headline)
                Text("把窗口放到刚刚好的位置")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack {
            Button(action: openControlCenter) {
                Label("控制中心", systemImage: "macwindow")
                    .labelStyle(.titleAndIcon)
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
            .font(.caption)

            Button(action: openPreferences) {
                Label("设置", systemImage: "gearshape")
                    .labelStyle(.titleAndIcon)
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
            .font(.caption)

            Spacer()

            Button(action: showAbout) {
                Label("关于", systemImage: "info.circle")
                    .labelStyle(.titleAndIcon)
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
            .font(.caption)

            Button(action: quit) {
                Image(systemName: "power")
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
        }
    }

    private func openControlCenter() {
        closePopover()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            AppDelegate.shared?.openControlCenter()
        }
    }

    private func openPreferences() {
        closePopover()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            (AppDelegate.shared)?.openPreferences()
        }
    }

    private func showAbout() {
        closePopover()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            (AppDelegate.shared)?.openAbout()
        }
    }

    private func quit() {
        NSApp.terminate(nil)
    }

    private func closePopover() {
        (AppDelegate.shared)?.closePopover()
    }
}
