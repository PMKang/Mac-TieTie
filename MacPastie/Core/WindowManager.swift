//
//  WindowManager.swift
//  MacPastie - 窗口吸附核心逻辑
//  Author: akang
//
//  依赖：Accessibility API（需要用户授权）
//

import AppKit
import ApplicationServices

// 16种吸附位置
enum SnapPosition: String, CaseIterable {
    case leftHalf    = "左半屏"
    case rightHalf   = "右半屏"
    case topHalf     = "上半屏"
    case bottomHalf  = "下半屏"
    case topLeft     = "左上角"
    case topRight    = "右上角"
    case bottomLeft  = "左下角"
    case bottomRight = "右下角"
    case leftThird   = "左三等分"
    case centerThird = "中三等分"
    case rightThird  = "右三等分"
    case leftTwoThirds  = "左2/3"
    case rightTwoThirds = "右2/3"
    case fullscreen  = "全屏"
    case center      = "居中"
}

class WindowManager {
    static let shared = WindowManager()
    private init() {}

    // MARK: - 权限检查

    func hasAccessibilityPermission() -> Bool {
        AXIsProcessTrusted()  // 静默检查，不自动弹系统对话框
    }

    // MARK: - 核心：吸附窗口

    func snapFrontWindow(to position: SnapPosition) {
        guard hasAccessibilityPermission() else { return }

        guard let screen = getTargetScreen(for: position) else { return }
        let frame = calculateFrame(for: position, screen: screen)
        setFrontWindowFrame(frame)
    }

    // MARK: - 计算目标 Frame

    private func calculateFrame(for position: SnapPosition, screen: NSScreen) -> CGRect {
        // 使用 visibleFrame 避开菜单栏和 Dock
        let sf = screen.visibleFrame
        let w = sf.width
        let h = sf.height
        let x = sf.minX
        let y = sf.minY

        switch position {
        case .leftHalf:       return CGRect(x: x, y: y, width: w/2, height: h)
        case .rightHalf:      return CGRect(x: x + w/2, y: y, width: w/2, height: h)
        case .topHalf:        return CGRect(x: x, y: y + h/2, width: w, height: h/2)
        case .bottomHalf:     return CGRect(x: x, y: y, width: w, height: h/2)
        case .topLeft:        return CGRect(x: x, y: y + h/2, width: w/2, height: h/2)
        case .topRight:       return CGRect(x: x + w/2, y: y + h/2, width: w/2, height: h/2)
        case .bottomLeft:     return CGRect(x: x, y: y, width: w/2, height: h/2)
        case .bottomRight:    return CGRect(x: x + w/2, y: y, width: w/2, height: h/2)
        case .leftThird:      return CGRect(x: x, y: y, width: w/3, height: h)
        case .centerThird:    return CGRect(x: x + w/3, y: y, width: w/3, height: h)
        case .rightThird:     return CGRect(x: x + w*2/3, y: y, width: w/3, height: h)
        case .leftTwoThirds:  return CGRect(x: x, y: y, width: w*2/3, height: h)
        case .rightTwoThirds: return CGRect(x: x + w/3, y: y, width: w*2/3, height: h)
        case .fullscreen:     return CGRect(x: x, y: y, width: w, height: h)
        case .center:
            let cw = min(w * 0.7, 1200)
            let ch = min(h * 0.7, 800)
            return CGRect(x: x + (w - cw)/2, y: y + (h - ch)/2, width: cw, height: ch)
        }
    }

    // MARK: - 设置窗口 Frame（通过 AXUIElement）

    private func setFrontWindowFrame(_ frame: CGRect) {
        guard let window = getFrontWindow() else { return }

        // macOS Accessibility 坐标系：原点在左上角（与 NSScreen 相反）
        let screenHeight = NSScreen.screens.first?.frame.height ?? 0
        var axOrigin = CGPoint(
            x: frame.minX,
            y: screenHeight - frame.maxY
        )
        var axSize = CGSize(width: frame.width, height: frame.height)

        var posValue = AXValueCreate(.cgPoint, &axOrigin)!
        var sizeValue = AXValueCreate(.cgSize, &axSize)!

        // 先设置 size 避免窗口超出屏幕约束导致 position 偏移
        AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeValue)
        AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, posValue)
        // 再设置一次 size 确保精确
        AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeValue)
    }

    // MARK: - 获取目标屏幕（前台窗口所在屏幕，非 NSScreen.main）

    private func getTargetScreen(for position: SnapPosition) -> NSScreen? {
        guard let window = getFrontWindow() else { return NSScreen.main }

        // 读取前台窗口当前 AX position
        var posRef: CFTypeRef?
        AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &posRef)
        var axPos = CGPoint.zero
        if let pv = posRef { AXValueGetValue(pv as! AXValue, .cgPoint, &axPos) }

        // 读取窗口 size
        var sizeRef: CFTypeRef?
        AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeRef)
        var axSize = CGSize.zero
        if let sv = sizeRef { AXValueGetValue(sv as! AXValue, .cgSize, &axSize) }

        // AX → NSScreen 坐标转换（AX 原点在主屏左上角，NSScreen 原点在主屏左下角）
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        let windowCenter = CGPoint(
            x: axPos.x + axSize.width / 2,
            y: primaryHeight - axPos.y - axSize.height / 2
        )

        // 找包含窗口中心点的屏幕，找不到就回退到 NSScreen.main
        return NSScreen.screens.first { $0.frame.contains(windowCenter) } ?? NSScreen.main
    }

    // MARK: - 获取前台窗口

    private func getFrontWindow() -> AXUIElement? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        var windowRef: CFTypeRef?
        AXUIElementCopyAttributeValue(axApp, kAXFocusedWindowAttribute as CFString, &windowRef)
        return windowRef as! AXUIElement?
    }

    // MARK: - 请求权限

    func requestAccessibilityPermission() {
        let alert = NSAlert()
        alert.messageText = "需要辅助功能权限"
        alert.informativeText = "Mac贴贴 需要辅助功能权限来控制窗口位置。\n请在「系统偏好设置 → 安全性与隐私 → 隐私 → 辅助功能」中授权 Mac贴贴。"
        alert.addButton(withTitle: "打开系统偏好设置")
        alert.addButton(withTitle: "取消")
        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
        }
    }
}
