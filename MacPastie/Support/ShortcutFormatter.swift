//
//  ShortcutFormatter.swift
//  MacPastie
//

import Carbon.HIToolbox

enum ShortcutFormatter {
    static func string(for config: HotkeyConfig) -> String {
        modifierString(for: config.modifiers) + keyName(for: config.keyCode)
    }

    static func modifierString(for modifiers: UInt32) -> String {
        var result = ""
        if modifiers & UInt32(controlKey) != 0 { result += "⌃" }
        if modifiers & UInt32(optionKey) != 0 { result += "⌥" }
        if modifiers & UInt32(cmdKey) != 0 { result += "⌘" }
        if modifiers & UInt32(shiftKey) != 0 { result += "⇧" }
        return result
    }

    static func keyName(for keyCode: UInt32) -> String {
        let names: [UInt32: String] = [
            UInt32(kVK_LeftArrow): "←", UInt32(kVK_RightArrow): "→",
            UInt32(kVK_UpArrow): "↑", UInt32(kVK_DownArrow): "↓",
            UInt32(kVK_Return): "↩",
            UInt32(kVK_ANSI_A): "A", UInt32(kVK_ANSI_B): "B",
            UInt32(kVK_ANSI_C): "C", UInt32(kVK_ANSI_D): "D",
            UInt32(kVK_ANSI_E): "E", UInt32(kVK_ANSI_F): "F",
            UInt32(kVK_ANSI_G): "G", UInt32(kVK_ANSI_H): "H",
            UInt32(kVK_ANSI_I): "I", UInt32(kVK_ANSI_J): "J",
            UInt32(kVK_ANSI_K): "K", UInt32(kVK_ANSI_L): "L",
            UInt32(kVK_ANSI_M): "M", UInt32(kVK_ANSI_N): "N",
            UInt32(kVK_ANSI_O): "O", UInt32(kVK_ANSI_P): "P",
            UInt32(kVK_ANSI_Q): "Q", UInt32(kVK_ANSI_R): "R",
            UInt32(kVK_ANSI_S): "S", UInt32(kVK_ANSI_T): "T",
            UInt32(kVK_ANSI_U): "U", UInt32(kVK_ANSI_V): "V",
            UInt32(kVK_ANSI_W): "W", UInt32(kVK_ANSI_X): "X",
            UInt32(kVK_ANSI_Y): "Y", UInt32(kVK_ANSI_Z): "Z",
            UInt32(kVK_ANSI_0): "0", UInt32(kVK_ANSI_1): "1",
            UInt32(kVK_ANSI_2): "2", UInt32(kVK_ANSI_3): "3",
            UInt32(kVK_ANSI_4): "4", UInt32(kVK_ANSI_5): "5",
            UInt32(kVK_ANSI_6): "6", UInt32(kVK_ANSI_7): "7",
            UInt32(kVK_ANSI_8): "8", UInt32(kVK_ANSI_9): "9",
        ]
        // Recording can receive any virtual key code. Keep uncommon keys intelligible
        // rather than displaying an unhelpful question mark.
        return names[keyCode] ?? "键码\(keyCode)"
    }

    static func accessibilityString(for config: HotkeyConfig) -> String {
        var modifiers: [String] = []
        if config.modifiers & UInt32(controlKey) != 0 { modifiers.append("Control") }
        if config.modifiers & UInt32(optionKey) != 0 { modifiers.append("Option") }
        if config.modifiers & UInt32(cmdKey) != 0 { modifiers.append("Command") }
        if config.modifiers & UInt32(shiftKey) != 0 { modifiers.append("Shift") }
        modifiers.append(accessibilityKeyName(for: config.keyCode))
        return modifiers.joined(separator: " ")
    }

    private static func accessibilityKeyName(for keyCode: UInt32) -> String {
        switch keyCode {
        case UInt32(kVK_LeftArrow): "左箭头"
        case UInt32(kVK_RightArrow): "右箭头"
        case UInt32(kVK_UpArrow): "上箭头"
        case UInt32(kVK_DownArrow): "下箭头"
        case UInt32(kVK_Return): "回车"
        default: keyName(for: keyCode)
        }
    }
}
