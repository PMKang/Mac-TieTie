//
//  SnapPage.swift
//  MacPastie
//

import SwiftUI

@MainActor
struct SnapPage: View {
    @ObservedObject private var hotkeyStore: HotkeyStore

    init(hotkeyStore: HotkeyStore) {
        self.hotkeyStore = hotkeyStore
    }

    private let columns = Array(repeating: GridItem(.flexible(minimum: 130), spacing: 14), count: 3)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "keyboard")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 38, height: 38)
                        .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                    VStack(alignment: .leading, spacing: 4) {
                        Text("布局与快捷键说明")
                            .font(.headline)
                        Text("下方展示每个贴窗位置对应的全局快捷键。按下快捷键后，窗口会贴合所在显示器的可用区域。")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                layoutGroup(title: "常用位置", layouts: SnapLayoutCatalog.primaryRows.flatMap(\.self))

                Divider()

                layoutGroup(title: "更多布局", layouts: SnapLayoutCatalog.secondaryLayouts)
            }
            .padding(24)
            .frame(maxWidth: 850, alignment: .leading)
        }
        .scrollIndicators(.hidden)
        .accessibilityIdentifier("snap-page")
    }

    @ViewBuilder
    private func layoutGroup(title: String, layouts: [SnapLayout]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.headline)

            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(layouts) { layout in
                    SnapLayoutCard(
                        layout: layout,
                        config: hotkeyStore.activeConfigs[layout.action]
                    )
                }
            }
        }
    }
}

private struct SnapLayoutCard: View {
    let layout: SnapLayout
    let config: HotkeyConfig?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: layout.symbolName)
                .font(.system(size: 21, weight: .medium))
                .foregroundStyle(Color.accentColor)
                .frame(width: 30)

            Text(layout.title)
                .font(.subheadline.weight(.semibold))

            Spacer(minLength: 6)

            Text(shortcutText)
                .font(.system(.caption, design: .monospaced).weight(.medium))
                .foregroundStyle(config == nil ? .tertiary : .secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, minHeight: 58)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityLabel("\(layout.title)，快捷键 \(accessibilityShortcut)")
    }

    private var shortcutText: String {
        guard let config else { return "未设置" }
        return ShortcutFormatter.string(for: config)
    }

    private var accessibilityShortcut: String {
        guard let config else { return "未设置" }
        return ShortcutFormatter.accessibilityString(for: config)
    }
}

#Preview {
    SnapPage(hotkeyStore: .shared)
        .frame(width: 820, height: 620)
}
