import Carbon.HIToolbox
import XCTest
@testable import MacPastie

@MainActor
final class HotkeyStoreTests: XCTestCase {
    func testInitialStateHasNoActiveConfigsBeforeRegistration() {
        let initial = HotkeyConfig.defaults
        let store = HotkeyStore(registrar: TestRegistrar(), initialConfigs: initial)

        XCTAssertEqual(store.configs, initial)
        XCTAssertEqual(store.activeConfigs, [:])
        XCTAssertNil(store.lastRegistrationError)
    }

    func testActivationFailureClearsActiveConfigs() {
        let registrar = TestRegistrar(results: [.failure(.registrationFailed(.leftHalf, -9876))])
        let initial = HotkeyConfig.defaults
        let store = HotkeyStore(registrar: registrar, initialConfigs: initial)

        XCTAssertFalse(store.activateStoredConfigs())
        XCTAssertEqual(store.configs, initial)
        XCTAssertEqual(store.activeConfigs, [:])
        XCTAssertEqual(registrar.requests, [initial])
        XCTAssertTrue(store.lastRegistrationError?.contains("无法注册") == true)
    }

    func testActivationSuccessPublishesActiveConfigs() {
        let registrar = TestRegistrar()
        let initial = HotkeyConfig.defaults
        let store = HotkeyStore(registrar: registrar, initialConfigs: initial)

        XCTAssertTrue(store.activateStoredConfigs())
        XCTAssertEqual(store.activeConfigs, initial)
        XCTAssertEqual(registrar.requests, [initial])
        XCTAssertNil(store.lastRegistrationError)
    }

    func testRecordingSuspensionUnregistersAndRestoresThePreviouslyActiveBindings() {
        let registrar = TestRegistrar()
        let initial = HotkeyConfig.defaults
        let store = HotkeyStore(registrar: registrar, initialConfigs: initial)
        XCTAssertTrue(store.activateStoredConfigs())

        XCTAssertTrue(store.suspendActiveBindings())
        XCTAssertEqual(registrar.unregisterCount, 1)
        XCTAssertEqual(store.activeConfigs, [:])

        XCTAssertTrue(store.restoreSuspendedBindings())
        XCTAssertEqual(registrar.requests, [initial, initial])
        XCTAssertEqual(store.activeConfigs, initial)
        XCTAssertNil(store.lastRegistrationError)
    }

    func testRecordingRestoreFailureLeavesNoShortcutClaimedAsActive() {
        let registrar = TestRegistrar(results: [.success(()), .failure(.registrationFailed(.leftHalf, -999))])
        let initial = HotkeyConfig.defaults
        let store = HotkeyStore(registrar: registrar, initialConfigs: initial)
        XCTAssertTrue(store.activateStoredConfigs())

        XCTAssertTrue(store.suspendActiveBindings())
        XCTAssertFalse(store.restoreSuspendedBindings())
        XCTAssertEqual(store.activeConfigs, [:])
        XCTAssertTrue(store.lastRegistrationError?.contains("无法恢复原快捷键") == true)
    }

    func testRecordingFinishPathIsIdempotentAfterRepeatedExitActions() {
        let registrar = TestRegistrar()
        let initial = HotkeyConfig.defaults
        let store = HotkeyStore(registrar: registrar, initialConfigs: initial)
        XCTAssertTrue(store.activateStoredConfigs())

        // Models a recorder being ended by one toolbar action and then again
        // by view disappearance. Global bindings must only be paused/restored
        // once and remain active afterwards.
        XCTAssertTrue(store.suspendActiveBindings())
        XCTAssertTrue(store.restoreSuspendedBindings())
        XCTAssertTrue(store.restoreSuspendedBindings())

        XCTAssertEqual(registrar.unregisterCount, 1)
        XCTAssertEqual(registrar.requests, [initial, initial])
        XCTAssertEqual(store.activeConfigs, initial)
    }

    func testDuplicateShortcutIsRejectedBeforeRegistration() {
        let registrar = TestRegistrar()
        let initial = HotkeyConfig.defaults
        let store = HotkeyStore(registrar: registrar, initialConfigs: initial)
        XCTAssertTrue(store.activateStoredConfigs())
        var proposed = initial
        proposed[.rightHalf] = proposed[.leftHalf]

        XCTAssertFalse(store.save(proposed))
        XCTAssertEqual(registrar.requests, [initial])
        XCTAssertEqual(store.activeConfigs, initial)
        XCTAssertEqual(store.lastRegistrationError, "快捷键不能重复")
    }

    func testDuplicateDetectionTreatsModifierChangesAsDistinctRecording() {
        var proposed = HotkeyConfig.defaults
        // The same physical key remains valid when a recorder captured a
        // different modifier set; only the complete shortcut must be unique.
        proposed[.rightHalf] = HotkeyConfig(
            keyCode: proposed[.leftHalf]!.keyCode,
            modifiers: UInt32(controlKey | optionKey | shiftKey)
        )

        XCTAssertFalse(HotkeyStore.hasDuplicateShortcut(in: proposed))
    }

    func testFailedRegistrationRestoresPreviouslyActiveConfiguration() {
        let registrar = TestRegistrar(results: [.success(()), .failure(.registrationFailed(.leftHalf, -9876)), .success(())])
        let initial = HotkeyConfig.defaults
        var persisted: [[HotkeyAction: HotkeyConfig]] = []
        let store = HotkeyStore(registrar: registrar, initialConfigs: initial) { persisted.append($0) }
        XCTAssertTrue(store.activateStoredConfigs())
        var proposed = initial
        proposed[.leftHalf] = HotkeyConfig(keyCode: UInt32(kVK_ANSI_A), modifiers: UInt32(controlKey | optionKey))

        XCTAssertFalse(store.save(proposed))
        XCTAssertEqual(store.activeConfigs, initial)
        XCTAssertEqual(store.configs, initial)
        XCTAssertEqual(registrar.requests, [initial, proposed, initial])
        XCTAssertEqual(persisted.count, 0)
    }

    func testDoubleRegistrationFailureClearsActiveConfiguration() {
        let registrar = TestRegistrar(results: [
            .success(()),
            .failure(.registrationFailed(.leftHalf, -9876)),
            .failure(.registrationFailed(.rightHalf, -8765)),
        ])
        let initial = HotkeyConfig.defaults
        var persisted: [[HotkeyAction: HotkeyConfig]] = []
        let store = HotkeyStore(registrar: registrar, initialConfigs: initial) { persisted.append($0) }
        XCTAssertTrue(store.activateStoredConfigs())
        var proposed = initial
        proposed[.leftHalf] = HotkeyConfig(keyCode: UInt32(kVK_ANSI_A), modifiers: UInt32(controlKey | optionKey))

        XCTAssertFalse(store.save(proposed))
        XCTAssertEqual(store.configs, initial)
        XCTAssertEqual(store.activeConfigs, [:])
        XCTAssertTrue(store.lastRegistrationError?.contains("无法恢复旧快捷键") == true)
        XCTAssertEqual(persisted.count, 0)
    }

    func testSuccessfulRegistrationPersistsCompleteProposedConfigurationOnce() {
        let registrar = TestRegistrar()
        let initial = HotkeyConfig.defaults
        var persisted: [[HotkeyAction: HotkeyConfig]] = []
        let store = HotkeyStore(registrar: registrar, initialConfigs: initial) { persisted.append($0) }
        var proposed = initial
        proposed[.leftHalf] = HotkeyConfig(keyCode: UInt32(kVK_ANSI_A), modifiers: UInt32(controlKey | optionKey))

        XCTAssertTrue(store.save(proposed))
        XCTAssertEqual(persisted, [proposed])
        XCTAssertEqual(store.configs, proposed)
        XCTAssertEqual(store.activeConfigs, proposed)
    }

    func testFormatsControlOptionLeftArrow() {
        let config = HotkeyConfig(keyCode: UInt32(kVK_LeftArrow), modifiers: UInt32(controlKey | optionKey))

        XCTAssertEqual(ShortcutFormatter.string(for: config), "⌃⌥←")
    }

    func testFormatsNonDefaultLetterShortcut() {
        let config = HotkeyConfig(keyCode: UInt32(kVK_ANSI_A), modifiers: UInt32(controlKey | optionKey))

        XCTAssertEqual(ShortcutFormatter.string(for: config), "⌃⌥A")
    }

    func testHistoricalDuplicateConfigurationFallsBackToDefaultsBeforeStartupRegistration() {
        var historical = HotkeyConfig.defaults
        historical[.rightHalf] = historical[.leftHalf]

        XCTAssertEqual(HotkeyConfig.sanitized(historical), HotkeyConfig.defaults)
        XCTAssertEqual(HotkeyManager.registrationError(for: historical), .duplicateConfiguration)
    }

    func testTargetEligibilityRejectsThisApplicationEvenWhenItHasAFocusedWindow() {
        XCTAssertFalse(
            WindowManager.isEligibleExternalTarget(
                frontmostPID: 4242,
                selfPID: 4242,
                hasFocusedWindow: true
            )
        )
    }

    func testTargetEligibilityRequiresAFocusedExternalWindow() {
        XCTAssertFalse(
            WindowManager.isEligibleExternalTarget(
                frontmostPID: 4243,
                selfPID: 4242,
                hasFocusedWindow: false
            )
        )
        XCTAssertTrue(
            WindowManager.isEligibleExternalTarget(
                frontmostPID: 4243,
                selfPID: 4242,
                hasFocusedWindow: true
            )
        )
    }

    func testExternalFrontmostWindowAlwaysWinsOverPreviousCapture() {
        XCTAssertEqual(
            WindowTargetSelectionPolicy.decision(
                frontmostIsSelf: false,
                hasFocusedExternalWindow: true,
                hasValidCapturedTarget: true
            ),
            .useFrontmostExternal
        )
    }

    func testMacPastieFrontmostPreservesAValidCapturedExternalWindow() {
        XCTAssertEqual(
            WindowTargetSelectionPolicy.decision(
                frontmostIsSelf: true,
                hasFocusedExternalWindow: false,
                hasValidCapturedTarget: true
            ),
            .useCapturedTarget
        )
    }

    func testMissingFrontmostWindowOrStaleCaptureClearsTheTarget() {
        XCTAssertEqual(
            WindowTargetSelectionPolicy.decision(
                frontmostIsSelf: false,
                hasFocusedExternalWindow: false,
                hasValidCapturedTarget: true
            ),
            .clearTarget
        )
        XCTAssertEqual(
            WindowTargetSelectionPolicy.decision(
                frontmostIsSelf: true,
                hasFocusedExternalWindow: false,
                hasValidCapturedTarget: false
            ),
            .clearTarget
        )
    }
}

private final class TestRegistrar: HotkeyRegistering {
    var requests: [[HotkeyAction: HotkeyConfig]] = []
    var unregisterCount = 0
    private var results: [Result<Void, HotkeyRegistrationError>]

    init(results: [Result<Void, HotkeyRegistrationError>] = []) {
        self.results = results
    }

    func registerAll(configs: [HotkeyAction: HotkeyConfig]) -> Result<Void, HotkeyRegistrationError> {
        requests.append(configs)
        return results.isEmpty ? .success(()) : results.removeFirst()
    }

    func unregisterAll() {
        unregisterCount += 1
    }
}
