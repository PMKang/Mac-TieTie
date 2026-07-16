//
//  UpdaterManager.swift
//  MacPastie
//
//  GitHub Release 更新状态与安装调度。下载包在替换应用前必须通过
//  macOS Code Signing 校验；正式版还会比对 Team ID，防止错误来源的包安装。
//

import AppKit
import Combine

@MainActor
final class UpdaterManager: ObservableObject {
    static let shared = UpdaterManager()

    @Published private(set) var state: UpdateState = .idle

    private let service = GitHubUpdateService(owner: "PMKang", repository: "Mac-TieTie")
    private var downloadedPackage: DownloadedUpdatePackage?
    private var checkTask: Task<Void, Never>?

    /// Retained for the legacy menu-popover About view. Direct GitHub updates
    /// do not depend on a separately injected Sparkle key.
    var isAvailable: Bool { true }
    var unavailableMessage: String? { nil }
    var isBusy: Bool { state.isBusy }

    func checkForUpdates() {
        guard !state.isBusy else { return }
        state = .checking
        let currentVersion = currentVersion
        let service = service

        checkTask?.cancel()
        checkTask = Task { [weak self] in
            do {
                let release = try await service.fetchLatestRelease()
                guard !Task.isCancelled else { return }
                self?.state = SemanticVersion(release.version) > SemanticVersion(currentVersion)
                    ? .available(release)
                    : .upToDate
            } catch is CancellationError {
                self?.state = .failed("更新检查已取消，请重试。")
            } catch GitHubUpdateError.noPublishedRelease, GitHubUpdateError.noMacOSArchive {
                self?.state = .noDownloadAvailable
            } catch {
                self?.state = .failed(error.localizedDescription)
            }
        }
    }

    func downloadAvailableUpdate() {
        guard case .available(let release) = state else { return }
        state = .downloading(downloadedByteCount: 0, totalByteCount: Int64(release.asset.byteCount))
        let service = service

        Task { [weak self] in
            do {
                let package = try await service.downloadAndPrepare(release: release) { [weak self] in
                    Task { @MainActor in
                        self?.state = .preparing(release)
                    }
                }
                guard !Task.isCancelled else { return }
                self?.downloadedPackage = package
                self?.state = .readyToRestart(package)
            } catch {
                self?.state = .failed(error.localizedDescription)
            }
        }
    }

    func installDownloadedUpdate() {
        guard let downloadedPackage else {
            state = .failed("更新包尚未准备完成，请重新下载。")
            return
        }

        do {
            try service.scheduleInstallAndRestart(package: downloadedPackage)
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    private var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.1"
    }
}
