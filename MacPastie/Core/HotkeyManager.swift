//
//  HotkeyManager.swift
//  MacPastie - 全局热键管理（Carbon RegisterEventHotKey）
//  Author: akang
//
//  默认前缀：⌃⌥（Control + Option）
//  支持自定义，配置持久化到 UserDefaults
//

import AppKit
import Carbon

// 热键动作标识
enum HotkeyAction: String, CaseIterable {
    case leftHalf    = "leftHalf"
    case rightHalf   = "rightHalf"
    case topHalf     = "topHalf"
    case bottomHalf  = "bottomHalf"
    case topLeft     = "topLeft"
    case topRight    = "topRight"
    case bottomLeft  = "bottomLeft"
    case bottomRight = "bottomRight"
    case leftThird   = "leftThird"
    case centerThird = "centerThird"
    case rightThird  = "rightThird"
    case leftTwoThirds  = "leftTwoThirds"
    case rightTwoThirds = "rightTwoThirds"
    case fullscreen  = "fullscreen"
    case center      = "center"

    var snapPosition: SnapPosition {
        switch self {
        case .leftHalf:         return .leftHalf
        case .rightHalf:        return .rightHalf
        case .topHalf:          return .topHalf
        case .bottomHalf:       return .bottomHalf
        case .topLeft:          return .topLeft
        case .topRight:         return .topRight
        case .bottomLeft:       return .bottomLeft
        case .bottomRight:      return .bottomRight
        case .leftThird:        return .leftThird
        case .centerThird:      return .centerThird
        case .rightThird:       return .rightThird
        case .leftTwoThirds:    return .leftTwoThirds
        case .rightTwoThirds:   return .rightTwoThirds
        case .fullscreen:       return .fullscreen
        case .center:           return .center
        }
    }

    var displayName: String { snapPosition.rawValue }
}

// 热键配置
struct HotkeyConfig: Codable, Equatable {
    var keyCode: UInt32
    var modifiers: UInt32

    // 默认配置：⌃⌥ + 按键
    static let defaults: [HotkeyAction: HotkeyConfig] = {
        let ctrlOpt: UInt32 = UInt32(controlKey | optionKey)
        let ctrlOptCmd: UInt32 = UInt32(controlKey | optionKey | cmdKey)
        return [
            .leftHalf:         HotkeyConfig(keyCode: UInt32(kVK_LeftArrow),  modifiers: ctrlOpt),
            .rightHalf:        HotkeyConfig(keyCode: UInt32(kVK_RightArrow), modifiers: ctrlOpt),
            .topHalf:          HotkeyConfig(keyCode: UInt32(kVK_UpArrow),    modifiers: ctrlOpt),
            .bottomHalf:       HotkeyConfig(keyCode: UInt32(kVK_DownArrow),  modifiers: ctrlOpt),
            .topLeft:          HotkeyConfig(keyCode: UInt32(kVK_ANSI_U),     modifiers: ctrlOpt),
            .topRight:         HotkeyConfig(keyCode: UInt32(kVK_ANSI_I),     modifiers: ctrlOpt),
            .bottomLeft:       HotkeyConfig(keyCode: UInt32(kVK_ANSI_J),     modifiers: ctrlOpt),
            .bottomRight:      HotkeyConfig(keyCode: UInt32(kVK_ANSI_K),     modifiers: ctrlOpt),
            .leftThird:        HotkeyConfig(keyCode: UInt32(kVK_ANSI_D),     modifiers: ctrlOpt),
            .centerThird:      HotkeyConfig(keyCode: UInt32(kVK_ANSI_F),     modifiers: ctrlOpt),
            .rightThird:       HotkeyConfig(keyCode: UInt32(kVK_ANSI_G),     modifiers: ctrlOpt),
            .leftTwoThirds:    HotkeyConfig(keyCode: UInt32(kVK_ANSI_E),     modifiers: ctrlOpt),
            .rightTwoThirds:   HotkeyConfig(keyCode: UInt32(kVK_ANSI_T),     modifiers: ctrlOpt),
            .fullscreen:       HotkeyConfig(keyCode: UInt32(kVK_Return),     modifiers: ctrlOpt),
            .center:           HotkeyConfig(keyCode: UInt32(kVK_ANSI_C),     modifiers: ctrlOpt),
        ]
    }()
}

class HotkeyManager {
    static let shared = HotkeyManager()
    private init() {}

    private var registeredHotkeys: [HotkeyAction: EventHotKeyRef] = [:]
    private var eventHandler: EventHandlerRef?

    // UserDefaults 中存储的自定义配置
    var configs: [HotkeyAction: HotkeyConfig] {
        get { loadConfigs() }
        set { saveConfigs(newValue) }
    }

    // MARK: - 注册所有热键

    func registerAll() {
        unregisterAll()
        installEventHandler()

        let current = configs
        var count = 0
        for action in HotkeyAction.allCases {
            if let config = current[action] {
                register(action: action, config: config)
                count += 1
            }
        }
        print("[hotkey] registerAll: registered \(count) hotkeys, trusted=\(AXIsProcessTrusted())")
    }

    func unregisterAll() {
        for (_, ref) in registeredHotkeys {
            UnregisterEventHotKey(ref)
        }
        registeredHotkeys.removeAll()
    }

    // MARK: - 单个注册

    private func register(action: HotkeyAction, config: HotkeyConfig) {
        let id = EventHotKeyID(signature: OSType(fourCharCode("MPST")), id: actionID(for: action))
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(config.keyCode, config.modifiers, id,
                                         GetApplicationEventTarget(), 0, &ref)
        if status == noErr, let ref = ref {
            registeredHotkeys[action] = ref
        }
    }

    // MARK: - Carbon 事件处理
    // InstallApplicationEventHandler 是 C 宏，Swift 不可直接调用。
    // 等效展开：InstallEventHandler(GetApplicationEventTarget(), handler, ...)

    private func installEventHandler() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                      eventKind: UInt32(kEventHotKeyPressed))
        // 非捕获闭包（访问静态属性不算捕获），可作为 C 函数指针传入
        let callback: EventHandlerUPP = { _, event, _ -> OSStatus in
            var hotkeyID = EventHotKeyID()
            if let event {
                GetEventParameter(event, EventParamName(kEventParamDirectObject),
                                  EventParamType(typeEventHotKeyID), nil,
                                  MemoryLayout<EventHotKeyID>.size, nil, &hotkeyID)
            }
            HotkeyManager.shared.handleHotkey(id: hotkeyID.id)
            return noErr
        }
        InstallEventHandler(GetApplicationEventTarget(), callback,
                            1, &eventType,
                            nil, &eventHandler)
    }

    private func handleHotkey(id: UInt32) {
        guard let action = action(forID: id) else {
            print("[hotkey] handleHotkey: unknown id=\(id)")
            return
        }
        print("[hotkey] handleHotkey: action=\(action)")
        WindowManager.shared.snapFrontWindow(to: action.snapPosition)
    }

    // MARK: - Action ↔ ID 映射

    private func actionID(for action: HotkeyAction) -> UInt32 {
        UInt32(HotkeyAction.allCases.firstIndex(of: action) ?? 0) + 1
    }

    private func action(forID id: UInt32) -> HotkeyAction? {
        let idx = Int(id) - 1
        guard idx >= 0, idx < HotkeyAction.allCases.count else { return nil }
        return HotkeyAction.allCases[idx]
    }

    // MARK: - 持久化

    private func loadConfigs() -> [HotkeyAction: HotkeyConfig] {
        guard let data = UserDefaults.standard.data(forKey: "hotkeyConfigs"),
              let decoded = try? JSONDecoder().decode([String: HotkeyConfig].self, from: data)
        else { return HotkeyConfig.defaults }

        var result = HotkeyConfig.defaults
        for (key, value) in decoded {
            if let action = HotkeyAction(rawValue: key) {
                result[action] = value
            }
        }
        return result
    }

    private func saveConfigs(_ configs: [HotkeyAction: HotkeyConfig]) {
        let dict = Dictionary(uniqueKeysWithValues: configs.map { ($0.key.rawValue, $0.value) })
        if let data = try? JSONEncoder().encode(dict) {
            UserDefaults.standard.set(data, forKey: "hotkeyConfigs")
        }
    }
}

// FourCharCode helper
private func fourCharCode(_ string: String) -> FourCharCode {
    var result: FourCharCode = 0
    for char in string.utf16.prefix(4) {
        result = (result << 8) + FourCharCode(char)
    }
    return result
}
