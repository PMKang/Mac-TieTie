//
//  ShortcutConfigurationPage.swift
//  MacPastie
//

import AppKit
import Carbon.HIToolbox
import SwiftUI

/// Local shortcut editor. It deliberately captures events only while its AppKit
/// view is first responder, so it never competes with Carbon's global hotkeys.
@MainActor
struct ShortcutConfigurationPage: View {
    @ObservedObject private var hotkeyStore: HotkeyStore
    @State private var draftConfigs: [HotkeyAction: HotkeyConfig]
    @State private var recordingAction: HotkeyAction?
    @State private var feedback: Feedback?
    @State private var hasUnsavedChanges = false

    private let groups: [(String, [HotkeyAction])] = [
        ("半屏", [.leftHalf, .rightHalf, .topHalf, .bottomHalf]),
        ("四角", [.topLeft, .topRight, .bottomLeft, .bottomRight]),
        ("三等分", [.leftThird, .centerThird, .rightThird]),
        ("更多布局", [.leftTwoThirds, .rightTwoThirds, .fullscreen, .center]),
    ]

    init() {
        self.init(hotkeyStore: HotkeyStore.shared)
    }

    init(hotkeyStore: HotkeyStore) {
        self.hotkeyStore = hotkeyStore
        _draftConfigs = State(initialValue: hotkeyStore.configs)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                editorHeader

                if let feedback {
                    FeedbackBanner(feedback: feedback)
                }

                if duplicateAction != nil {
                    Label("存在重复快捷键。请为重复项目录制其他组合后再保存。", systemImage: "exclamationmark.triangle.fill")
                        .font(.subheadline)
                        .foregroundStyle(.orange)
                        .accessibilityLabel("存在重复快捷键，无法保存")
                }

                ForEach(groups, id: \.0) { group in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(group.0)
                            .font(.headline)

                        ForEach(group.1, id: \.self) { action in
                            ShortcutConfigurationRow(
                                action: action,
                                config: draftConfigs[action],
                                activeConfig: hotkeyStore.activeConfigs[action],
                                isRecording: recordingAction == action,
                                isDuplicate: isDuplicate(action),
                                beginRecording: { beginRecording(action) },
                                cancelRecording: { cancelRecording() },
                                receivedShortcut: { receive($0, for: action) }
                            )
                        }
                    }
                }

                HStack(spacing: 12) {
                    Button("恢复为默认快捷键") {
                        draftConfigs = HotkeyConfig.defaults
                        hasUnsavedChanges = draftConfigs != hotkeyStore.configs
                        feedback = nil
                        finishRecordingAndRestore()
                    }
                    .accessibilityHint("恢复后仍需点击保存并应用")

                    Spacer()

                    Button("放弃更改") {
                        draftConfigs = hotkeyStore.configs
                        hasUnsavedChanges = false
                        feedback = nil
                        finishRecordingAndRestore()
                    }
                    .disabled(!hasUnsavedChanges)

                    Button("保存并应用") {
                        save()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!hasUnsavedChanges || duplicateAction != nil || recordingAction != nil)
                    .accessibilityHint("系统注册成功后，菜单栏和贴窗页会立即使用新快捷键")
                }
            }
            .padding(32)
            .frame(maxWidth: 850, alignment: .leading)
        }
        .onChange(of: hotkeyStore.configs) { configs in
            // Another UI can update the source of truth. Never overwrite an edit
            // the user has not explicitly applied or abandoned in this page.
            guard !hasUnsavedChanges, recordingAction == nil else { return }
            draftConfigs = configs
        }
        .onDisappear {
            finishRecordingAndRestore()
        }
        .accessibilityIdentifier("shortcut-configuration-page")
    }

    private var editorHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("每项快捷键都需要至少一个修饰键")
                .font(.headline)
            Text("点按“录制”后，直接按下新的组合键；按 Esc 可取消。保存时会先由系统重新注册，成功后才会替换菜单栏和贴窗页中显示的快捷键。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var duplicateAction: HotkeyAction? {
        guard HotkeyStore.hasDuplicateShortcut(in: draftConfigs) else { return nil }
        return HotkeyAction.allCases.first(where: { isDuplicate($0) })
    }

    private func isDuplicate(_ action: HotkeyAction) -> Bool {
        guard let config = draftConfigs[action] else { return false }
        return draftConfigs.filter { $0.key != action && $0.value == config }.isEmpty == false
    }

    private func beginRecording(_ action: HotkeyAction) {
        guard hotkeyStore.suspendActiveBindings() else {
            feedback = .error(hotkeyStore.lastRegistrationError ?? "无法暂停现有快捷键。")
            return
        }
        feedback = nil
        recordingAction = action
    }

    private func cancelRecording() {
        finishRecordingAndRestore()
    }

    private func receive(_ config: HotkeyConfig, for action: HotkeyAction) {
        draftConfigs[action] = config
        hasUnsavedChanges = draftConfigs != hotkeyStore.configs
        feedback = nil
        finishRecordingAndRestore()
    }

    private func save() {
        recordingAction = nil
        guard !HotkeyStore.hasDuplicateShortcut(in: draftConfigs) else {
            feedback = .error("快捷键不能重复。请修改重复的组合后再保存。")
            return
        }

        if hotkeyStore.save(draftConfigs) {
            hasUnsavedChanges = false
            feedback = .success("已保存并生效。菜单栏与贴窗页已更新。")
        } else {
            feedback = .error(hotkeyStore.lastRegistrationError ?? "系统未能注册快捷键，已保留原有设置。")
        }
    }

    /// The single exit path for recording. It is deliberately idempotent so
    /// toolbar actions (restore defaults/discard), Escape, capture and view
    /// disappearance can all safely call it.
    private func finishRecordingAndRestore() {
        recordingAction = nil
        guard !hotkeyStore.restoreSuspendedBindings() else { return }
        feedback = .error(hotkeyStore.lastRegistrationError ?? "无法恢复原快捷键。")
    }
}

private struct ShortcutConfigurationRow: View {
    let action: HotkeyAction
    let config: HotkeyConfig?
    let activeConfig: HotkeyConfig?
    let isRecording: Bool
    let isDuplicate: Bool
    let beginRecording: () -> Void
    let cancelRecording: () -> Void
    let receivedShortcut: (HotkeyConfig) -> Void

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text(action.displayName)
                    .font(.subheadline.weight(.medium))
                Text(activeStatus)
                    .font(.caption)
                    .foregroundStyle(activeConfig == nil ? .orange : .secondary)
            }
            .frame(minWidth: 92, alignment: .leading)

            if isRecording {
                ShortcutRecorder(
                    onShortcut: receivedShortcut,
                    onCancel: cancelRecording
                )
                .frame(maxWidth: .infinity, minHeight: 32)
                .accessibilityLabel("正在为\(action.displayName)录制快捷键")
            } else {
                VStack(alignment: .leading, spacing: 3) {
                    Text(displayedShortcut)
                        .font(.system(.subheadline, design: .monospaced).weight(.medium))
                        .foregroundStyle(config == nil ? .tertiary : .primary)

                    if config != activeConfig {
                        Text(activeConfig.map { "当前生效：\(ShortcutFormatter.string(for: $0))" } ?? "当前未设置")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                .accessibilityLabel("\(action.displayName)快捷键：\(accessibilityShortcut)")
            }

            if isDuplicate {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .accessibilityLabel("与其他项目重复")
            }

            Button(isRecording ? "取消" : "录制") {
                isRecording ? cancelRecording() : beginRecording()
            }
            .frame(width: 58)
            .accessibilityLabel(isRecording ? "取消录制\(action.displayName)快捷键" : "录制\(action.displayName)快捷键")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(isRecording ? Color.accentColor.opacity(0.11) : Color(nsColor: .controlBackgroundColor).opacity(0.45), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(isDuplicate ? Color.orange.opacity(0.75) : (isRecording ? Color.accentColor.opacity(0.55) : .clear), lineWidth: 1)
        }
    }

    private var displayedShortcut: String {
        config.map(ShortcutFormatter.string(for:)) ?? "未设置"
    }

    private var accessibilityShortcut: String {
        config.map(ShortcutFormatter.accessibilityString(for:)) ?? "未设置"
    }

    private var activeStatus: String {
        activeConfig == nil ? "当前未生效" : "当前已生效"
    }
}

private struct ShortcutRecorder: NSViewRepresentable {
    let onShortcut: (HotkeyConfig) -> Void
    let onCancel: () -> Void

    func makeNSView(context: Context) -> ShortcutRecorderView {
        let view = ShortcutRecorderView()
        view.onShortcut = onShortcut
        view.onCancel = onCancel
        DispatchQueue.main.async {
            view.window?.makeFirstResponder(view)
        }
        return view
    }

    func updateNSView(_ nsView: ShortcutRecorderView, context: Context) {
        nsView.onShortcut = onShortcut
        nsView.onCancel = onCancel
        DispatchQueue.main.async {
            if nsView.window?.firstResponder !== nsView {
                nsView.window?.makeFirstResponder(nsView)
            }
        }
    }
}

private final class ShortcutRecorderView: NSView {
    var onShortcut: ((HotkeyConfig) -> Void)?
    var onCancel: (() -> Void)?

    override var acceptsFirstResponder: Bool { true }
    override var canBecomeKeyView: Bool { true }

    override func keyDown(with event: NSEvent) {
        capture(event)
    }

    /// Command key equivalents are normally consumed by menu commands before
    /// `keyDown`. Keep those events inside the recorder too; command-only
    /// combinations are deliberately rejected so app menu shortcuts cannot be
    /// accidentally reassigned here.
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard flags.contains(.command) else {
            return super.performKeyEquivalent(with: event)
        }
        capture(event)
        return true
    }

    private func capture(_ event: NSEvent) {
        if event.keyCode == UInt16(kVK_Escape) {
            onCancel?()
            return
        }

        let independentFlags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let modifiers = carbonModifiers(from: independentFlags)
        // Reserve Command-only combinations for standard macOS menus such as
        // Command-C and Command-W. Control/Option/Shift remain recordable.
        guard modifiers != 0, independentFlags != [.command] else {
            NSSound.beep()
            return
        }
        onShortcut?(HotkeyConfig(keyCode: UInt32(event.keyCode), modifiers: modifiers))
    }

    private func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var result: UInt32 = 0
        if flags.contains(.control) { result |= UInt32(controlKey) }
        if flags.contains(.option) { result |= UInt32(optionKey) }
        if flags.contains(.command) { result |= UInt32(cmdKey) }
        if flags.contains(.shift) { result |= UInt32(shiftKey) }
        return result
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let text = "正在录制… 按 Esc 取消"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: NSFont.smallSystemFontSize, weight: .medium),
            .foregroundColor: NSColor.controlAccentColor,
        ]
        let size = text.size(withAttributes: attributes)
        text.draw(at: NSPoint(x: 9, y: max(0, (bounds.height - size.height) / 2)), withAttributes: attributes)
    }
}

private enum Feedback: Equatable {
    case success(String)
    case error(String)

    var message: String {
        switch self {
        case let .success(message), let .error(message): message
        }
    }

    var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }
}

private struct FeedbackBanner: View {
    let feedback: Feedback

    var body: some View {
        Label(feedback.message, systemImage: feedback.isSuccess ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
            .font(.subheadline)
            .foregroundStyle(feedback.isSuccess ? Color.green : Color.orange)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background((feedback.isSuccess ? Color.green : Color.orange).opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
