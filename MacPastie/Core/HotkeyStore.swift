//
//  HotkeyStore.swift
//  MacPastie
//

import Combine
import Carbon

protocol HotkeyRegistering: AnyObject {
    func registerAll(configs: [HotkeyAction: HotkeyConfig]) -> Result<Void, HotkeyRegistrationError>
    func unregisterAll()
}

enum HotkeyRegistrationError: Error, Equatable, LocalizedError {
    case invalidConfiguration
    case duplicateConfiguration
    case eventHandlerInstallationFailed(OSStatus)
    case registrationFailed(HotkeyAction, OSStatus)
    indirect case restorationFailed(original: HotkeyRegistrationError, restoration: HotkeyRegistrationError)

    var errorDescription: String? {
        switch self {
        case .invalidConfiguration:
            return "快捷键配置不完整"
        case .duplicateConfiguration:
            return "快捷键不能重复"
        case let .eventHandlerInstallationFailed(status):
            return "无法安装快捷键事件处理器（错误码 \(status)）"
        case let .registrationFailed(action, status):
            return "无法注册\(action.displayName)快捷键（错误码 \(status)）"
        case let .restorationFailed(original, restoration):
            return "\(original.localizedDescription)；无法恢复旧快捷键：\(restoration.localizedDescription)"
        }
    }
}

@MainActor
final class HotkeyStore: ObservableObject {
    /// The menu bar panel and the control center both observe this one source of truth.
    static let shared = HotkeyStore()

    @Published private(set) var configs: [HotkeyAction: HotkeyConfig]
    @Published private(set) var activeConfigs: [HotkeyAction: HotkeyConfig]
    @Published private(set) var lastRegistrationError: String?

    private let registrar: HotkeyRegistering
    private let persist: ([HotkeyAction: HotkeyConfig]) -> Void
    /// Snapshot retained only while a local recorder owns the keyboard focus.
    /// Keeping it in the store makes the visible "active" state truthful while
    /// Carbon registrations are deliberately paused.
    private var suspendedActiveConfigs: [HotkeyAction: HotkeyConfig]?

    convenience init() {
        self.init(
            registrar: HotkeyManager.shared,
            initialConfigs: HotkeyManager.shared.configs,
            persist: { HotkeyManager.shared.configs = $0 }
        )
    }

    init(
        registrar: HotkeyRegistering,
        initialConfigs: [HotkeyAction: HotkeyConfig],
        persist: @escaping ([HotkeyAction: HotkeyConfig]) -> Void = { _ in }
    ) {
        self.registrar = registrar
        self.persist = persist
        self.configs = initialConfigs
        // Do not claim a shortcut is active before Carbon accepts it at launch.
        self.activeConfigs = [:]
        self.lastRegistrationError = nil
    }

    /// Activates the persisted bindings during app launch and publishes only the
    /// shortcuts that Carbon has actually accepted.
    @discardableResult
    func activateStoredConfigs() -> Bool {
        switch registrar.registerAll(configs: configs) {
        case .success:
            activeConfigs = configs
            lastRegistrationError = nil
            return true
        case let .failure(error):
            // HotkeyManager clears partial registrations before returning a failure.
            activeConfigs = [:]
            lastRegistrationError = error.localizedDescription
            return false
        }
    }

    /// Registers every proposed shortcut before changing the persisted configuration.
    @discardableResult
    func save(_ proposedConfigs: [HotkeyAction: HotkeyConfig]) -> Bool {
        guard HotkeyConfig.isComplete(proposedConfigs) else {
            lastRegistrationError = HotkeyRegistrationError.invalidConfiguration.localizedDescription
            return false
        }

        guard !HotkeyConfig.hasDuplicateShortcut(in: proposedConfigs) else {
            lastRegistrationError = HotkeyRegistrationError.duplicateConfiguration.localizedDescription
            return false
        }

        let previousActiveConfigs = activeConfigs
        switch registrar.registerAll(configs: proposedConfigs) {
        case .success:
            persist(proposedConfigs)
            configs = proposedConfigs
            activeConfigs = proposedConfigs
            lastRegistrationError = nil
            return true
        case let .failure(error):
            // Registration is transactional from the user's perspective: restore the
            // previously active bindings and leave persisted settings untouched.
            switch registrar.registerAll(configs: previousActiveConfigs) {
            case .success:
                lastRegistrationError = error.localizedDescription
            case let .failure(restorationError):
                // HotkeyManager clears partial registrations before returning a failure.
                // Do not claim the old bindings are still active when restoration fails.
                activeConfigs = [:]
                lastRegistrationError = HotkeyRegistrationError.restorationFailed(
                    original: error,
                    restoration: restorationError
                ).localizedDescription
            }
            return false
        }
    }

    static func hasDuplicateShortcut(in configs: [HotkeyAction: HotkeyConfig]) -> Bool {
        HotkeyConfig.hasDuplicateShortcut(in: configs)
    }

    /// Prevents a key typed into the app's local recorder from reaching a
    /// matching Carbon global hotkey. The caller must always balance this with
    /// `restoreSuspendedBindings()`, including on cancellation/disappearance.
    @discardableResult
    func suspendActiveBindings() -> Bool {
        guard suspendedActiveConfigs == nil else { return true }

        suspendedActiveConfigs = activeConfigs
        registrar.unregisterAll()
        activeConfigs = [:]
        lastRegistrationError = nil
        return true
    }

    /// Restores precisely the bindings that were active before recording. A
    /// failed restore is surfaced and leaves `activeConfigs` empty rather than
    /// pretending a shortcut still works.
    @discardableResult
    func restoreSuspendedBindings() -> Bool {
        guard let configsToRestore = suspendedActiveConfigs else { return true }
        suspendedActiveConfigs = nil

        guard !configsToRestore.isEmpty else {
            activeConfigs = [:]
            return true
        }

        switch registrar.registerAll(configs: configsToRestore) {
        case .success:
            activeConfigs = configsToRestore
            lastRegistrationError = nil
            return true
        case let .failure(error):
            activeConfigs = [:]
            lastRegistrationError = "录制结束后无法恢复原快捷键：\(error.localizedDescription)"
            return false
        }
    }
}
