//
//  AboutPage.swift
//  MacPastie
//

import AppKit
import SwiftUI

/// A readable, contact-first About surface. Nothing here blocks the core
/// window-snapping experience; links only open in the user's default browser.
struct AboutPage: View {
    @ObservedObject private var updater = UpdaterManager.shared

    private let githubURL = URL(string: "https://github.com/PMKang/Mac-TieTie")!
    private let voiceInputURL = URL(string: "https://github.com/PMKang/akang-ai-voice-input/releases/latest")!

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.1"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                updatePanel
                introductionPanel
                recommendedToolsPanel
                changelogPanel
            }
            .padding(36)
            .frame(maxWidth: 980, alignment: .leading)
        }
        .scrollIndicators(.hidden)
        .accessibilityIdentifier("about-page")
    }

    private var updatePanel: some View {
        HStack(alignment: .center, spacing: 16) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.title2)
                .foregroundStyle(Color.accentColor)
                .frame(width: 44, height: 44)
                .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 5) {
                Text("版本与更新")
                    .font(.headline)
                Text(updateDetail)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 16)

            updateAction
        }
        .padding(20)
        .aboutPanel()
    }

    private var updateDetail: String {
        switch updater.state {
        case .idle:
            "当前版本 v\(version) · 已重置 Project，并新增跨屏贴边能力。"
        case .checking:
            "正在检查 GitHub Release…"
        case .upToDate:
            "当前版本 v\(version)，已是最新。"
        case .noDownloadAvailable:
            "暂未发布可下载的新版本。"
        case .available(let release):
            "发现 \(release.displayVersion)，安装包 \(release.asset.formattedByteCount)。"
        case .downloading:
            "正在下载更新包，请保持应用开启。"
        case .preparing(let release):
            "\(release.displayVersion) 下载完成，正在解压并验证应用签名…"
        case .readyToRestart(let package):
            "\(package.displayVersion) 已下载并通过签名验证，可重启安装。"
        case .failed(let message):
            "更新失败：\(message)"
        }
    }

    @ViewBuilder
    private var updateAction: some View {
        switch updater.state {
        case .checking:
            Label("正在检查…", systemImage: "arrow.triangle.2.circlepath")
                .foregroundStyle(.secondary)
        case .downloading:
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text("正在下载…")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        case .preparing:
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text("正在验证…")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        case .available:
            Button {
                updater.downloadAvailableUpdate()
            } label: {
                Label("下载更新", systemImage: "arrow.down.circle.fill")
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("update.download")
        case .readyToRestart:
            Button {
                updater.installDownloadedUpdate()
            } label: {
                Label("重启并安装", systemImage: "arrow.clockwise.circle.fill")
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("update.install")
        default:
            Button {
                updater.checkForUpdates()
            } label: {
                Label("检查更新", systemImage: "arrow.triangle.2.circlepath")
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("update.check")
            .help("在当前页面检查、下载并安装已签名的新版本")
        }
    }

    private var introductionPanel: some View {
        ViewThatFits(in: .horizontal) {
            introductionContent
            VStack(alignment: .leading, spacing: 24) {
                introductionText
                socialCodes
            }
        }
        .padding(24)
        .aboutPanel()
    }

    private var introductionContent: some View {
        HStack(alignment: .top, spacing: 30) {
            introductionText
                .frame(maxWidth: .infinity, alignment: .leading)
            socialCodes
        }
    }

    private var introductionText: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(nsImage: NSApplication.shared.applicationIconImage)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 52, height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text("阿康的 Mac 贴贴")
                        .font(.title2.weight(.semibold))
                    Text("一个由个人开发和维护的 macOS 窗口贴窗工具。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            Text("开发者说明")
                .font(.headline)

            Text("看到一款专业贴窗软件很好用，但需要付费。付款时突然卡顿了一下，心想：要不让 AI 写一个？结果发现还真行，省下一大笔钱，也顺手把跨屏贴边这类自己最常用的功能补上了。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Text("我是阿康，平时做产品，也负责追着 Bug 跑。这里没有大团队：产品、开发、测试和客服目前是同一个人。项目会持续慢慢打磨，每条反馈都会认真看。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            githubCallout
            feedbackCallout
        }
        .frame(minWidth: 350, alignment: .leading)
    }

    private var githubCallout: some View {
        HStack(spacing: 12) {
            Image(systemName: "star.fill")
                .font(.title3)
                .foregroundStyle(.yellow)

            VStack(alignment: .leading, spacing: 2) {
                Text("觉得好用，欢迎在 GitHub 点个 Star")
                    .font(.subheadline.weight(.medium))
                Text("每一个 Star，都是对这次探索的一份认可。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Button {
                NSWorkspace.shared.open(githubURL)
            } label: {
                Label("打开 GitHub", systemImage: "arrow.up.right")
            }
            .buttonStyle(.borderedProminent)
            .accessibilityHint("在浏览器打开阿康的 Mac 贴贴 GitHub 项目")
        }
        .padding(14)
        .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var feedbackCallout: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(.title3)
                .foregroundStyle(Color.accentColor)

            VStack(alignment: .leading, spacing: 4) {
                Text("来吐槽，也来聊聊")
                    .font(.subheadline.weight(.medium))
                Text("觉得哪里不好用、想加什么功能，或者恰好觉得好用？关注右侧公众号后私信我；想进讨论群也可以留言，我会回复。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var socialCodes: some View {
        Group {
            if let image = resourceImage(named: "social_qrcodes", extension: "png") {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: 330, height: 280)
                    .accessibilityLabel("阿康公众号与视频号二维码")
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "qrcode")
                        .font(.system(size: 36, weight: .medium))
                    Text("二维码图片缺失")
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
                .frame(width: 330, height: 280)
            }
        }
        .frame(width: 330)
    }

    private var recommendedToolsPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("阿康的好用工具", systemImage: "sparkles")
                .font(.headline)

            Divider()

            ToolRecommendation(
                symbol: "waveform.circle.fill",
                title: "阿康的 AI 语音输入法",
                description: "开源的 macOS AI 语音输入工具。全局快捷键说话、实时识别，并将整理后的文字写入当前输入框。",
                action: { NSWorkspace.shared.open(voiceInputURL) }
            )
        }
        .padding(20)
        .aboutPanel()
    }

    private var changelogPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("更新日志", systemImage: "clock.arrow.circlepath")
                .font(.headline)

            Divider()

            ChangelogRow(
                version: "v1.0.1",
                date: "7 月 16 日",
                details: "重置 Project 修复窗口贴靠与跨屏场景的遗留问题；新增跨屏贴边、主控制中心与快捷键配置。"
            )

            Divider()

            ChangelogRow(
                version: "v1.0",
                date: "2026 年 5 月",
                details: "首个公开版本：支持常用贴窗布局、全局快捷键，以及多显示器的窗口操作。"
            )
        }
        .padding(20)
        .aboutPanel()
    }

    private func resourceImage(named name: String, extension fileExtension: String = "jpg") -> NSImage? {
        guard let url = Bundle.main.url(forResource: name, withExtension: fileExtension) else { return nil }
        return NSImage(contentsOf: url)
    }
}

private struct ToolRecommendation: View {
    let symbol: String
    let title: String
    let description: String
    let action: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 30))
                .foregroundStyle(Color.accentColor)
                .frame(width: 50, height: 50)
                .background(Color.accentColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 12)

            Button("下载使用", action: action)
                .buttonStyle(.borderedProminent)
        }
    }
}

private struct ChangelogRow: View {
    let version: String
    let date: String
    let details: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Text(version)
                .font(.subheadline.weight(.semibold))
                .frame(width: 58, alignment: .leading)

            VStack(alignment: .leading, spacing: 4) {
                Text(date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(details)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private extension View {
    func aboutPanel() -> some View {
        padding(0)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color(nsColor: .separatorColor).opacity(0.42), lineWidth: 1)
            }
    }
}

#Preview {
    AboutPage()
        .frame(width: 980, height: 760)
}
