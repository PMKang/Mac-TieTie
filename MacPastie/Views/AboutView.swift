//
//  AboutView.swift
//  MacPastie - 关于面板
//  Author: akang
//

import SwiftUI

struct AboutView: View {
    private let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0"

    private let changelog: [(String, [String])] = [
        ("V0.2", [
            "新增关于面板（版本 + 更新日志 + 公众号二维码）",
            "修复设置/关于窗口点不开的问题",
            "移除下一屏功能（单显示器场景无效）",
            "补充首次安装 Gatekeeper 解除说明",
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
            // 顶部：App 信息 + 二维码
            HStack(spacing: 16) {
                if let img = qrcodeImage {
                    Image(nsImage: img)
                        .resizable()
                        .interpolation(.high)
                        .frame(width: 90, height: 90)
                        .cornerRadius(8)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("Mac贴贴")
                        .font(.title3.bold())
                    Text("V\(version) · 窗口管理工具")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("作者：akang")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Divider()
                    Text("微信扫码关注「阿康AI探索号」")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("AI资讯 · 金融科技 · PM踩坑 · AI养虾🦐")
                        .font(.caption2)
                        .foregroundColor(.accentColor)
                }
            }
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
                .frame(height: 160)
            }

        }
        .frame(width: 340)
    }

    private var qrcodeImage: NSImage? {
        let devPath = "/Users/liangkang/PycharmProjects/Mactietie_MacPastie/qrcode.jpg"
        if FileManager.default.fileExists(atPath: devPath) {
            return NSImage(contentsOfFile: devPath)
        }
        let bundlePath = (Bundle.main.bundlePath as NSString).appendingPathComponent("qrcode.jpg")
        return NSImage(contentsOfFile: bundlePath)
    }
}
