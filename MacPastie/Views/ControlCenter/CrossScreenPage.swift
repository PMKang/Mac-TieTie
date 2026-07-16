//
//  CrossScreenPage.swift
//  MacPastie
//

import SwiftUI

struct CrossScreenPage: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                HStack(alignment: .center, spacing: 20) {
                    screenIllustration

                    VStack(alignment: .leading, spacing: 8) {
                        Text("重复同一个贴边动作，即可跨到另一块显示器")
                            .font(.title3.weight(.semibold))
                        Text("例如，先把窗口贴到右半屏；当窗口已经在右边缘时，再按一次右半屏快捷键，窗口会进入系统布局中右侧方向的目标显示器左半屏。")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(22)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                VStack(alignment: .leading, spacing: 14) {
                    Text("如何使用")
                        .font(.headline)

                    CrossScreenStep(number: "1", title: "先贴边", detail: "使用左半、右半、上半、下半或四角等贴边位置。")
                    CrossScreenStep(number: "2", title: "重复同方向", detail: "窗口已在对应边缘时，再执行相同方向的操作。")
                    CrossScreenStep(number: "3", title: "落到目标屏", detail: "窗口会保持相近布局，移动到该方向算法选出的最近显示器。")
                }

                VStack(alignment: .leading, spacing: 9) {
                    Text("使用条件")
                        .font(.headline)
                    Text("需要连接至少两台显示器，并在“设置”中开启辅助功能权限。若该方向没有显示器，或窗口不允许调整大小，窗口会保持原位。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Text("跨屏目标会按显示器的相对方向选择最近的可用屏幕。")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.top, 2)
            }
            .padding(26)
            .frame(maxWidth: 850, alignment: .leading)
        }
        .scrollIndicators(.hidden)
        .accessibilityIdentifier("cross-screen-page")
    }

    private var screenIllustration: some View {
        HStack(spacing: 7) {
            DisplayDiagram(symbolName: "arrow.right", highlightedEdge: .trailing)
            Image(systemName: "arrow.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.accentColor)
            DisplayDiagram(symbolName: "arrow.left", highlightedEdge: .leading)
        }
        .frame(width: 190, height: 100)
        .accessibilityHidden(true)
    }

}

private struct CrossScreenStep: View {
    let number: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 23, height: 23)
                .background(Color.accentColor, in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(detail).font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }
}

private struct DisplayDiagram: View {
    enum Edge { case leading, trailing }

    let symbolName: String
    let highlightedEdge: Edge

    var body: some View {
        RoundedRectangle(cornerRadius: 7, style: .continuous)
            .strokeBorder(Color.secondary.opacity(0.65), lineWidth: 3)
            .overlay(alignment: highlightedEdge == .leading ? .leading : .trailing) {
                Rectangle()
                    .fill(Color.accentColor)
                    .frame(width: 14)
                    .padding(3)
            }
            .overlay {
                Image(systemName: symbolName)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
            }
            .frame(width: 76, height: 58)
    }
}

#Preview {
    CrossScreenPage()
        .frame(width: 820, height: 620)
}
