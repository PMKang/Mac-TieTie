//
//  AboutView.swift
//  MacPastie - 关于面板
//  Author: akang
//

import SwiftUI

struct AboutView: View {
    private let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0"
    private let voiceInputURL = URL(string: "https://github.com/PMKang/akang-ai-voice-input/releases/latest")!
    @State private var updateMessage: String?

    private let changelog: [(String, [String])] = [
        ("V1.0", [
            "品牌升级为「阿康的 Mac 贴贴」",
            "聚焦贴窗体验，移除未完成的截图与资讯入口",
            "优化菜单栏面板与产品推荐方式",
        ]),
        ("V0.1", [
            "首个可用版本",
            "15 种窗口吸附位置（半屏/四角/三等分/全屏/居中）",
            "全局热键，默认前缀 ⌃⌥",
            "菜单栏 Popover 面板，Tab 式布局",
        ]),
    ]

    var body: some View {
        VStack(spacing: 0) {
            // 顶部：App 信息
            HStack(spacing: 16) {
                Image(nsImage: NSApplication.shared.applicationIconImage)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 72, height: 72)
                VStack(alignment: .leading, spacing: 6) {
                    Text("阿康的 Mac 贴贴")
                        .font(.title3.bold())
                    Text("V\(version) · macOS 贴窗工具")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("把窗口放到刚刚好的位置。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(16)

            Divider()

            recommendedProduct
                .padding(16)

            Divider()

            // 更新日志
            VStack(alignment: .leading, spacing: 0) {
                Text("更新日志")
                    .font(.caption.bold())
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 6)

                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(changelog, id: \.0) { version, items in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(version)
                                    .font(.caption.bold())
                                    .foregroundColor(.primary)
                                ForEach(items, id: \.self) { item in
                                    HStack(alignment: .top, spacing: 4) {
                                        Text("·")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Text(item)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                }
                .frame(height: 145)
            }

            Divider()

            officialAccountFooter
                .padding(14)

            updateControls
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
        }
        .frame(width: 430)
    }

    private var recommendedProduct: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("阿康的好用工具")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.tint)

                VStack(alignment: .leading, spacing: 3) {
                    Text("阿康的 AI 语音输入法")
                        .font(.subheadline.weight(.semibold))
                    Text("自然说话，直接成文。按需了解，不捆绑安装。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 12)

                VStack(alignment: .trailing) {
                    Spacer(minLength: 0)
                    Button("了解一下") {
                        NSWorkspace.shared.open(voiceInputURL)
                    }
                    .controlSize(.small)
                    Spacer(minLength: 0)
                }
            }
            .padding(12)
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    private var updateControls: some View {
        VStack(alignment: .trailing, spacing: 5) {
            Button("检查更新") {
                let updater = UpdaterManager.shared
                guard updater.isAvailable else {
                    updateMessage = updater.unavailableMessage
                    return
                }
                updateMessage = nil
                updater.checkForUpdates()
            }
            .controlSize(.small)

            if let updateMessage {
                Text(updateMessage)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.trailing)
            }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private var officialAccountFooter: some View {
        HStack(spacing: 12) {
            if let img = qrcodeImage {
                Image(nsImage: img)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("阿康 AI 探索号")
                    .font(.subheadline.weight(.medium))
                Text("开发记录、AI 工具和产品实测")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private var qrcodeImage: NSImage? {
        guard let url = Bundle.main.url(forResource: "qrcode", withExtension: "jpg") else { return nil }
        return NSImage(contentsOf: url)
    }
}
