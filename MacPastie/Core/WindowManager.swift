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

    // 记录上次 snap 的动作和窗口实际落点（App min-width 约束可能导致落点≠理想目标）
    private var lastSnapAction: SnapPosition? = nil
    private var lastSnapFrame: CGRect? = nil

    // MARK: - 权限检查

    func hasAccessibilityPermission() -> Bool {
        AXIsProcessTrusted()  // 静默检查，不自动弹系统对话框
    }

    // MARK: - 核心：吸附窗口（含边缘触发跳屏）

    func snapFrontWindow(to position: SnapPosition) {
        guard hasAccessibilityPermission() else { return }
        guard let currentScreen = getScreenContainingFrontWindow() else { return }

        let targetFrame = calculateFrame(for: position, screen: currentScreen)

        if let currentFrame = getFrontWindowFrame() {
            let byFrame = framesApproximatelyEqual(currentFrame, targetFrame)

            // byLastSnap：上次 snap 了同一个位置，且窗口没动（处理 App min-width 导致实际尺寸偏离目标）
            // - lastSnapFrame 有值：用精确比对（窗口已稳定）
            // - lastSnapFrame 为 nil：刚做完 snap/jump 但 readback 未返回（快速连按），改用宽松尺寸容差（50%）
            let byLastSnap: Bool
            if position == lastSnapAction {
                if let lastFrame = lastSnapFrame {
                    byLastSnap = framesApproximatelyEqual(currentFrame, lastFrame)
                } else {
                    byLastSnap = abs(currentFrame.minX - targetFrame.minX) <= 20 &&
                                 abs(currentFrame.minY - targetFrame.minY) <= 20 &&
                                 abs(currentFrame.width  - targetFrame.width)  <= max(targetFrame.width  * 0.5, 20) &&
                                 abs(currentFrame.height - targetFrame.height) <= max(targetFrame.height * 0.5, 20)
                }
            } else {
                byLastSnap = false
            }

            let approxEqual = byFrame || byLastSnap

            print("[snap] action=\(position.rawValue)")
            print("[snap] currentWindow  TL(\(Int(currentFrame.minX)),\(Int(currentFrame.maxY)))  BR(\(Int(currentFrame.maxX)),\(Int(currentFrame.minY)))  size(\(Int(currentFrame.width))x\(Int(currentFrame.height)))")
            print("[snap] targetFrame    TL(\(Int(targetFrame.minX)),\(Int(targetFrame.maxY)))  BR(\(Int(targetFrame.maxX)),\(Int(targetFrame.minY)))  size(\(Int(targetFrame.width))x\(Int(targetFrame.height)))")
            print("[snap] alreadyAtTarget=\(approxEqual)(byFrame=\(byFrame) byLastSnap=\(byLastSnap))  screens=\(NSScreen.screens.count)  currentScreen=\(Int(currentScreen.frame.minX)),\(Int(currentScreen.frame.minY)) \(Int(currentScreen.frame.width))x\(Int(currentScreen.frame.height))")

            if approxEqual,
               let (adjacentScreen, landingPosition) = findAdjacentScreenJump(for: position, from: currentScreen) {
                let newFrame = calculateFrame(for: landingPosition, screen: adjacentScreen)
                let primaryH = NSScreen.screens.first?.frame.height ?? 0
                print("[snap] JUMP → screen(\(Int(adjacentScreen.frame.minX)),\(Int(adjacentScreen.frame.minY))) \(Int(adjacentScreen.frame.width))x\(Int(adjacentScreen.frame.height))  landing=\(landingPosition.rawValue)")
                print("[snap] JUMP   newFrame TL(\(Int(newFrame.minX)),\(Int(newFrame.maxY))) BR(\(Int(newFrame.maxX)),\(Int(newFrame.minY)))  size(\(Int(newFrame.width))x\(Int(newFrame.height)))")
                print("[snap] JUMP   axOrigin(\(Int(newFrame.minX)),\(Int(primaryH - newFrame.maxY)))  primaryH=\(Int(primaryH))")
                setFrontWindowFrame(newFrame, crossScreen: true)
                lastSnapAction = landingPosition
                lastSnapFrame = nil          // 立即清空，快速连按时走宽松路径
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    self.lastSnapFrame = self.getFrontWindowFrame()
                    if let actual = self.lastSnapFrame {
                        print("[snap] POST-JUMP actual TL(\(Int(actual.minX)),\(Int(actual.maxY))) BR(\(Int(actual.maxX)),\(Int(actual.minY)))  size(\(Int(actual.width))x\(Int(actual.height)))")
                    }
                }
                return
            }

            if approxEqual {
                print("[snap] alreadyAtTarget but no adjacent screen → no-op")
            }
        }

        setFrontWindowFrame(targetFrame)
        lastSnapAction = position
        lastSnapFrame = nil              // 立即清空，异步回填实际落点
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.lastSnapFrame = self.getFrontWindowFrame()
        }
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

    // crossScreen=true：pos→size→pos（跨屏必须先定位才能越过边界）
    // crossScreen=false：size→pos→size（同屏更稳定，避免字符网格 App 高度撑出屏幕）
    private func setFrontWindowFrame(_ frame: CGRect, crossScreen: Bool = false) {
        guard let window = getFrontWindow() else { return }

        let screenHeight = NSScreen.screens.first?.frame.height ?? 0
        var axOrigin = CGPoint(x: frame.minX, y: screenHeight - frame.maxY)
        var axSize = CGSize(width: frame.width, height: frame.height)

        let posValue = AXValueCreate(.cgPoint, &axOrigin)!
        let sizeValue = AXValueCreate(.cgSize, &axSize)!

        let e1, e2, e3: AXError
        if crossScreen {
            e1 = AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, posValue)
            e2 = AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeValue)
            e3 = AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, posValue)
            // 字符网格 App 在处理 size 时可能顺带移位，100ms 后再补一次位置校正
            let capturedWindow = window
            var retryOrigin = axOrigin
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if let rv = AXValueCreate(.cgPoint, &retryOrigin) {
                    let re = AXUIElementSetAttributeValue(capturedWindow, kAXPositionAttribute as CFString, rv)
                    print("[AX] crossScreen retry pos: \(re.rawValue)")
                }
            }
        } else {
            e1 = AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeValue)
            e2 = AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, posValue)
            e3 = AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeValue)
        }
        print("[AX] e1=\(e1.rawValue) e2=\(e2.rawValue) e3=\(e3.rawValue)  crossScreen=\(crossScreen)  axOrigin(\(Int(axOrigin.x)),\(Int(axOrigin.y))) axSize(\(Int(axSize.width))x\(Int(axSize.height)))")
    }

    // MARK: - 读取前台窗口当前 Frame（NSScreen 坐标系）

    private func getFrontWindowFrame() -> CGRect? {
        guard let window = getFrontWindow() else { return nil }

        var posRef: CFTypeRef?
        AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &posRef)
        var axPos = CGPoint.zero
        guard let pv = posRef else { return nil }
        AXValueGetValue(pv as! AXValue, .cgPoint, &axPos)

        var sizeRef: CFTypeRef?
        AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeRef)
        var axSize = CGSize.zero
        guard let sv = sizeRef else { return nil }
        AXValueGetValue(sv as! AXValue, .cgSize, &axSize)

        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        return CGRect(x: axPos.x,
                      y: primaryHeight - axPos.y - axSize.height,
                      width: axSize.width,
                      height: axSize.height)
    }

    private func framesApproximatelyEqual(_ a: CGRect, _ b: CGRect, tolerance: CGFloat = 20) -> Bool {
        let posOK  = abs(a.minX - b.minX) <= tolerance && abs(a.minY - b.minY) <= tolerance
        // 尺寸用相对误差（目标的20%），避免App最小宽度约束导致无法触发跳屏
        let widthOK  = abs(a.width  - b.width)  <= max(b.width  * 0.2, tolerance)
        let heightOK = abs(a.height - b.height) <= max(b.height * 0.2, tolerance)
        return posOK && widthOK && heightOK
    }

    // MARK: - 获取前台窗口所在屏幕

    private func getScreenContainingFrontWindow() -> NSScreen? {
        guard let frame = getFrontWindowFrame() else { return NSScreen.main }
        let center = CGPoint(x: frame.midX, y: frame.midY)
        return NSScreen.screens.first { $0.frame.contains(center) } ?? NSScreen.main
    }

    // MARK: - 多屏跳跃：找相邻屏幕 + 落点位置

    private func findAdjacentScreenJump(for position: SnapPosition, from current: NSScreen) -> (NSScreen, SnapPosition)? {
        let others = NSScreen.screens.filter { $0 != current }
        guard !others.isEmpty else { return nil }

        var bestScreen: NSScreen? = nil
        var bestDist = CGFloat.infinity
        var bestLanding: SnapPosition = position

        for screen in others {
            let hDiff = screen.frame.midX - current.frame.midX  // 正 = 右边
            let vDiff = screen.frame.midY - current.frame.midY  // 正 = 上方（NSScreen Y 向上）
            let hGap = abs(hDiff)
            let vGap = abs(vDiff)

            // 水平距离 >= 垂直距离 → 视为左右排列，否则视为上下排列
            let isHorizontal = hGap >= vGap
            let toRight = hDiff > 0
            let above = vDiff > 0

            let landing: SnapPosition
            let dist: CGFloat

            if isHorizontal {
                if toRight && isRightEdge(position) {
                    landing = mirrorHorizontal(position); dist = hGap
                } else if !toRight && isLeftEdge(position) {
                    landing = mirrorHorizontal(position); dist = hGap
                } else {
                    continue
                }
            } else {
                if above && isTopEdge(position) {
                    landing = mirrorVertical(position); dist = vGap
                } else if !above && isBottomEdge(position) {
                    landing = mirrorVertical(position); dist = vGap
                } else {
                    continue
                }
            }

            if dist < bestDist {
                bestDist = dist; bestScreen = screen; bestLanding = landing
            }
        }

        guard let screen = bestScreen else { return nil }
        return (screen, bestLanding)
    }

    // MARK: - 位置边缘判断

    private func isRightEdge(_ p: SnapPosition) -> Bool {
        switch p {
        case .rightHalf, .topRight, .bottomRight, .rightThird, .rightTwoThirds: return true
        default: return false
        }
    }

    private func isLeftEdge(_ p: SnapPosition) -> Bool {
        switch p {
        case .leftHalf, .topLeft, .bottomLeft, .leftThird, .leftTwoThirds: return true
        default: return false
        }
    }

    private func isTopEdge(_ p: SnapPosition) -> Bool {
        switch p {
        case .topHalf, .topLeft, .topRight: return true
        default: return false
        }
    }

    private func isBottomEdge(_ p: SnapPosition) -> Bool {
        switch p {
        case .bottomHalf, .bottomLeft, .bottomRight: return true
        default: return false
        }
    }

    // MARK: - 位置对称映射

    private func mirrorHorizontal(_ p: SnapPosition) -> SnapPosition {
        switch p {
        case .leftHalf:       return .rightHalf
        case .rightHalf:      return .leftHalf
        case .topLeft:        return .topRight
        case .topRight:       return .topLeft
        case .bottomLeft:     return .bottomRight
        case .bottomRight:    return .bottomLeft
        case .leftThird:      return .rightThird
        case .rightThird:     return .leftThird
        case .leftTwoThirds:  return .rightTwoThirds
        case .rightTwoThirds: return .leftTwoThirds
        default:              return p
        }
    }

    private func mirrorVertical(_ p: SnapPosition) -> SnapPosition {
        switch p {
        case .topHalf:    return .bottomHalf
        case .bottomHalf: return .topHalf
        case .topLeft:    return .bottomLeft
        case .bottomLeft: return .topLeft
        case .topRight:   return .bottomRight
        case .bottomRight: return .topRight
        default:          return p
        }
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
        let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [promptKey: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else {
            return
        }
        NSWorkspace.shared.open(url)
    }
}
