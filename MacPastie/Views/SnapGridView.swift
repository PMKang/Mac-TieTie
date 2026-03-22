//
//  SnapGridView.swift
//  MacPastie - 3x3 可视化网格（核心差异化 UI）
//  Author: akang
//

import SwiftUI
import Carbon

struct SnapGridView: View {
    @State private var hoveredAction: HotkeyAction? = nil

    // 3x3 网格布局定义
    private let gridItems: [[GridItem]] = [
        [
            GridItem(action: .leftHalf,    icon: "rectangle.lefthalf.filled",  label: "左半"),
            GridItem(action: .fullscreen,  icon: "rectangle.fill",             label: "全屏"),
            GridItem(action: .rightHalf,   icon: "rectangle.righthalf.filled", label: "右半"),
        ],
        [
            GridItem(action: .topLeft,     icon: "rectangle.topthird.inset.filled", label: "左上"),
            GridItem(action: .topHalf,     icon: "rectangle.tophalf.filled",         label: "上半"),
            GridItem(action: .topRight,    icon: "rectangle.topthird.inset.filled",  label: "右上"),
        ],
        [
            GridItem(action: .bottomLeft,  icon: "rectangle.bottomthird.inset.filled", label: "左下"),
            GridItem(action: .bottomHalf,  icon: "rectangle.bottomhalf.filled",         label: "下半"),
            GridItem(action: .bottomRight, icon: "rectangle.bottomthird.inset.filled",  label: "右下"),
        ],
    ]

    var body: some View {
        VStack(spacing: 6) {
            // 3x3 主网格
            ForEach(gridItems.indices, id: \.self) { row in
                HStack(spacing: 6) {
                    ForEach(gridItems[row]) { item in
                        SnapCell(item: item, isHovered: hoveredAction == item.action) {
                            WindowManager.shared.snapFrontWindow(to: item.action.snapPosition)
                            closePopover()
                        } onHover: { hoveredAction = $0 ? item.action : nil }
                    }
                }
            }

            Divider().padding(.vertical, 4)

            // 三等分 + 2/3 + 居中
            HStack(spacing: 6) {
                let extras: [GridItem] = [
                    GridItem(action: .leftThird,      icon: "rectangle.split.3x1", label: "左1/3"),
                    GridItem(action: .centerThird,    icon: "rectangle.center.inset.filled", label: "中1/3"),
                    GridItem(action: .rightThird,     icon: "rectangle.split.3x1", label: "右1/3"),
                    GridItem(action: .leftTwoThirds,  icon: "rectangle.leadingthird.inset.filled", label: "左2/3"),
                    GridItem(action: .rightTwoThirds, icon: "rectangle.trailingthird.inset.filled", label: "右2/3"),
                    GridItem(action: .center,         icon: "dot.square", label: "居中"),
                ]
                ForEach(extras) { item in
                    SnapCell(item: item, isHovered: hoveredAction == item.action, size: 44) {
                        WindowManager.shared.snapFrontWindow(to: item.action.snapPosition)
                        closePopover()
                    } onHover: { hoveredAction = $0 ? item.action : nil }
                }
            }
        }
    }

    private func closePopover() {
        (NSApp.delegate as? AppDelegate)?.closePopover()
    }
}

// MARK: - Grid Data

private struct GridItem: Identifiable {
    let id = UUID()
    let action: HotkeyAction
    let icon: String
    let label: String
}

// MARK: - Snap Cell

private struct SnapCell: View {
    let item: GridItem
    let isHovered: Bool
    var size: CGFloat = 80
    let onTap: () -> Void
    let onHover: (Bool) -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                Image(systemName: item.icon)
                    .font(.system(size: size == 80 ? 22 : 16))
                    .foregroundColor(isHovered ? .white : .primary)
                Text(item.label)
                    .font(.system(size: 10))
                    .foregroundColor(isHovered ? .white : .secondary)
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
        let config = HotkeyManager.shared.configs[action]
        return "\(action.displayName)  \(config.map { formatHotkey($0) } ?? "")"
    }

    private func formatHotkey(_ config: HotkeyConfig) -> String {
        var mods = ""
        if config.modifiers & UInt32(controlKey) != 0 { mods += "⌃" }
        if config.modifiers & UInt32(optionKey)  != 0 { mods += "⌥" }
        if config.modifiers & UInt32(cmdKey)     != 0 { mods += "⌘" }
        if config.modifiers & UInt32(shiftKey)   != 0 { mods += "⇧" }
        return mods + keyCodeName(config.keyCode)
    }

    private func keyCodeName(_ keyCode: UInt32) -> String {
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
        return map[keyCode] ?? "?"
    }
}
