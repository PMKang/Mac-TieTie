//
//  MenuPanelView.swift
//  MacPastie - Tab 式弹出面板
//  Author: akang
//
//  Tab：[贴窗] [截图] [资讯]  底部：二维码 + ⚙设置 ℹ关于 ✕退出
//

import SwiftUI

struct MenuPanelView: View {
    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            // Tab 切换栏
            tabBar
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 10)

            Divider()

            // 内容区（高度固定）
            tabContent
                .frame(height: 210)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

            Divider()

            // 公众号二维码引流条
            qrcodeStrip
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

            Divider()

            // 底部工具栏
            bottomBar
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
        }
        .frame(width: 400)
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
        HStack(spacing: 0) {
            TabButton(title: "贴窗", icon: "rectangle.3.group", index: 0,
                      selected: $selectedTab, locked: false)
            TabButton(title: "截图", icon: "camera", index: 1,
                      selected: $selectedTab, locked: false)
            TabButton(title: "资讯", icon: "newspaper", index: 2,
                      selected: $selectedTab, locked: false)
        }
    }

    // MARK: - 公众号引流条

    private var qrcodeStrip: some View {
        HStack(spacing: 14) {
            if let img = qrcodeImage {
                Image(nsImage: img)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 64, height: 64)
                    .cornerRadius(8)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("阿康AI探索号")
                    .font(.callout.bold())
                Text("AI资讯 · 金融科技 · PM踩坑 · AI养虾🦐")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
    }

    private var qrcodeImage: NSImage? {
        let devPath = "/Users/liangkang/PycharmProjects/Mactietie_MacPastie/qrcode.jpg"
        if FileManager.default.fileExists(atPath: devPath) {
            return NSImage(contentsOfFile: devPath)
        }
        let bundlePath = (Bundle.main.bundlePath as NSString).appendingPathComponent("qrcode.jpg")
        return NSImage(contentsOfFile: bundlePath)
    }

    // MARK: - Tab 内容

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case 0:
            SnapGridView()
        case 1:
            LockedFeatureView(name: "截图功能", description: "高级截图、标注、快传\n激活后解锁")
        case 2:
            LockedFeatureView(name: "资讯功能", description: "AI/PM 日报精选\n激活后解锁")
        default:
            EmptyView()
        }
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack {
            Button(action: openPreferences) {
                Label("设置", systemImage: "gearshape")
                    .labelStyle(.titleAndIcon)
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
            .font(.caption)

            Spacer()

            Button(action: showAbout) {
                Image(systemName: "info.circle")
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)

            Button(action: quit) {
                Image(systemName: "power")
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
        }
    }

    private func openPreferences() {
        print("[menu] openPreferences tapped, delegate=\(NSApp.delegate != nil ? "ok" : "nil"), asAppDelegate=\((AppDelegate.shared) != nil ? "ok" : "nil")")
        closePopover()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            print("[menu] calling openPreferences after delay")
            (AppDelegate.shared)?.openPreferences()
        }
    }

    private func showAbout() {
        print("[menu] showAbout tapped, delegate=\(NSApp.delegate != nil ? "ok" : "nil"), asAppDelegate=\((AppDelegate.shared) != nil ? "ok" : "nil")")
        closePopover()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            print("[menu] calling openAbout after delay")
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

// MARK: - Tab Button

private struct TabButton: View {
    let title: String
    let icon: String
    let index: Int
    @Binding var selected: Int
    let locked: Bool

    var body: some View {
        Button(action: { if !locked { selected = index } }) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                Text(title)
                    .font(.caption)
                if locked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 8))
                        .foregroundColor(.orange)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(selected == index ? Color.accentColor.opacity(0.15) : Color.clear)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .foregroundColor(selected == index ? .accentColor : .secondary)
    }
}

// MARK: - Locked Feature Placeholder

private struct LockedFeatureView: View {
    let name: String
    let description: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "lock.fill")
                .font(.system(size: 32))
                .foregroundColor(.orange)
            Text(name)
                .font(.headline)
            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
