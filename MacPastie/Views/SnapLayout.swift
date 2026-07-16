//
//  SnapLayout.swift
//  MacPastie
//
//  贴窗布局的共享展示信息：菜单栏快速面板与控制中心使用同一份定义。
//

import Foundation

struct SnapLayout: Identifiable, Hashable {
    let action: HotkeyAction
    let symbolName: String
    let title: String

    var id: HotkeyAction { action }
}

enum SnapLayoutCatalog {
    static let primaryRows: [[SnapLayout]] = [
        [
            SnapLayout(action: .leftHalf, symbolName: "rectangle.lefthalf.filled", title: "左半"),
            SnapLayout(action: .fullscreen, symbolName: "rectangle.fill", title: "全屏"),
            SnapLayout(action: .rightHalf, symbolName: "rectangle.righthalf.filled", title: "右半"),
        ],
        [
            SnapLayout(action: .topLeft, symbolName: "rectangle.topthird.inset.filled", title: "左上"),
            SnapLayout(action: .topHalf, symbolName: "rectangle.tophalf.filled", title: "上半"),
            SnapLayout(action: .topRight, symbolName: "rectangle.topthird.inset.filled", title: "右上"),
        ],
        [
            SnapLayout(action: .bottomLeft, symbolName: "rectangle.bottomthird.inset.filled", title: "左下"),
            SnapLayout(action: .bottomHalf, symbolName: "rectangle.bottomhalf.filled", title: "下半"),
            SnapLayout(action: .bottomRight, symbolName: "rectangle.bottomthird.inset.filled", title: "右下"),
        ],
    ]

    static let secondaryLayouts: [SnapLayout] = [
        SnapLayout(action: .leftThird, symbolName: "rectangle.split.3x1", title: "左1/3"),
        SnapLayout(action: .centerThird, symbolName: "rectangle.center.inset.filled", title: "中1/3"),
        SnapLayout(action: .rightThird, symbolName: "rectangle.split.3x1", title: "右1/3"),
        SnapLayout(action: .leftTwoThirds, symbolName: "rectangle.leadingthird.inset.filled", title: "左2/3"),
        SnapLayout(action: .rightTwoThirds, symbolName: "rectangle.trailingthird.inset.filled", title: "右2/3"),
        SnapLayout(action: .center, symbolName: "dot.square", title: "居中"),
    ]

    static var all: [SnapLayout] {
        primaryRows.flatMap(\.self) + secondaryLayouts
    }
}
