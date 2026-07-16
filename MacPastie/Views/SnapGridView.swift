//
//  SnapGridView.swift
//  MacPastie - 3x3 可视化网格（核心差异化 UI）
//  Author: akang
//

import SwiftUI
import Carbon

@MainActor
struct SnapGridView: View {
    @State private var hoveredAction: HotkeyAction? = nil
    @ObservedObject private var hotkeyStore: HotkeyStore

    init(hotkeyStore: HotkeyStore) {
        self.hotkeyStore = hotkeyStore
    }

    var body: some View {
        VStack(spacing: 6) {
            // 3x3 主网格
            ForEach(SnapLayoutCatalog.primaryRows.indices, id: \.self) { row in
                HStack(spacing: 6) {
                    ForEach(SnapLayoutCatalog.primaryRows[row]) { item in
                        SnapCell(item: item, isHovered: hoveredAction == item.action) {
                            WindowManager.shared.snapFrontWindow(to: item.action.snapPosition)
                            closePopover()
                        } onHover: { hoveredAction = $0 ? item.action : nil }
                        .environmentObject(hotkeyStore)
                    }
                }
            }

            Divider().padding(.vertical, 4)

            // 三等分 + 2/3 + 居中
            HStack(spacing: 6) {
                ForEach(SnapLayoutCatalog.secondaryLayouts) { item in
                    SnapCell(item: item, isHovered: hoveredAction == item.action, size: 44) {
                        WindowManager.shared.snapFrontWindow(to: item.action.snapPosition)
                        closePopover()
                    } onHover: { hoveredAction = $0 ? item.action : nil }
                    .environmentObject(hotkeyStore)
                }
            }
        }
    }

    private func closePopover() {
        (NSApp.delegate as? AppDelegate)?.closePopover()
    }
}

// MARK: - Snap Cell

private struct SnapCell: View {
    @EnvironmentObject private var hotkeyStore: HotkeyStore

    let item: SnapLayout
    let isHovered: Bool
    var size: CGFloat = 80
    let onTap: () -> Void
    let onHover: (Bool) -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 2) {
                Image(systemName: item.symbolName)
                    .font(.system(size: size == 80 ? 18 : 14))
                    .foregroundColor(isHovered ? .white : .primary)
                Text(item.title)
                    .font(.system(size: 10))
                    .foregroundColor(isHovered ? .white : .secondary)
                Text(shortcutText)
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .foregroundColor(isHovered ? .white.opacity(0.9) : .secondary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: size == 80 ? 60 : 44)
            .background(isHovered ? Color.accentColor : Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .onHover(perform: onHover)
        .help(hotkeyHint(for: item.action))
    }

    private func hotkeyHint(for action: HotkeyAction) -> String {
        action.displayName + " · " + shortcutText
    }

    private var shortcutText: String {
        guard let config = hotkeyStore.activeConfigs[item.action] else { return "未设置" }
        return ShortcutFormatter.string(for: config)
    }
}
