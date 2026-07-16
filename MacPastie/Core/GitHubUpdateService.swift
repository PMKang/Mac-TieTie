//
//  GitHubUpdateService.swift
//  MacPastie
//

import AppKit
import Foundation

struct SemanticVersion: Comparable {
    private let components: [Int]

    init(_ value: String) {
        let cleaned = value.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "v", with: "", options: [.anchored, .caseInsensitive])
        let releasePart = cleaned.split(separator: "-", maxSplits: 1).first ?? Substring(cleaned)
        let numbers = releasePart.split(separator: ".").map { Int($0) ?? 0 }
        components = Array((numbers + [0, 0, 0]).prefix(3))
    }

    static func < (lhs: SemanticVersion, rhs: SemanticVersion) -> Bool {
        for index in 0..<3 where lhs.components[index] != rhs.components[index] {
            return lhs.components[index] < rhs.components[index]
        }
        return false
    }
}

struct UpdateRelease: Equatable, Sendable {
    let version: String
    let asset: UpdateAsset

    var displayVersion: String {
        version.lowercased().hasPrefix("v") ? version : "v\(version)"
    }
}

struct UpdateAsset: Equatable, Sendable {
    let name: String
    let downloadURL: URL
    let byteCount: Int

    var formattedByteCount: String {
        ByteCountFormatter.string(fromByteCount: Int64(byteCount), countStyle: .file)
    }
}

struct DownloadedUpdatePackage: Equatable {
    let version: String
    let stagedAppURL: URL
    let archiveURL: URL

    var displayVersion: String {
        version.lowercased().hasPrefix("v") ? version : "v\(version)"
    }
}

enum UpdateState: Equatable {
    case idle
    case checking
    case upToDate
    case noDownloadAvailable
    case available(UpdateRelease)
    case downloading(downloadedByteCount: Int64, totalByteCount: Int64)
    case preparing(UpdateRelease)
    case readyToRestart(DownloadedUpdatePackage)
    case failed(String)

    var isBusy: Bool {
        switch self {
        case .checking, .downloading, .preparing: true
        default: false
        }
    }
}

enum GitHubUpdateError: LocalizedError {
    case invalidResponse
    case noPublishedRelease
    case noMacOSArchive
    case invalidArchive
    case bundleMismatch
    case signatureInvalid
    case signerMismatch
    case installationDirectoryNotWritable(URL)

    var errorDescription: String? {
        switch self {
        case .invalidResponse: "更新服务返回的数据无法识别。"
        case .noPublishedRelease: "尚未发布可下载的新版本。"
        case .noMacOSArchive: "该版本未附带 macOS 安装包。"
        case .invalidArchive: "下载的更新包无法解压或内容不完整。"
        case .bundleMismatch: "更新包与当前应用不匹配，已停止安装。"
        case .signatureInvalid: "更新包的应用签名校验失败，已停止安装。"
        case .signerMismatch: "更新包签名与当前应用的开发者不一致，已停止安装。"
        case .installationDirectoryNotWritable(let directory): "更新已下载，但当前应用目录不可写：\(directory.path)。"
        }
    }
}

private struct GitHubReleasePayload: Decodable {
    let tagName: String
    let assets: [Asset]

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case assets
    }

    struct Asset: Decodable {
        let name: String
        let browserDownloadURL: URL
        let size: Int

        enum CodingKeys: String, CodingKey {
            case name
            case browserDownloadURL = "browser_download_url"
            case size
        }
    }
}

final class GitHubUpdateService: @unchecked Sendable {
    private let owner: String
    private let repository: String

    init(owner: String, repository: String) {
        self.owner = owner
        self.repository = repository
    }

    func fetchLatestRelease() async throws -> UpdateRelease {
        let url = URL(string: "https://api.github.com/repos/\(owner)/\(repository)/releases/latest")!
        var request = URLRequest(url: url)
        request.setValue("AkangMacPastie", forHTTPHeaderField: "User-Agent")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 12

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw GitHubUpdateError.invalidResponse }
        guard http.statusCode != 404 else { throw GitHubUpdateError.noPublishedRelease }
        guard (200..<300).contains(http.statusCode) else { throw GitHubUpdateError.invalidResponse }

        let payload = try JSONDecoder().decode(GitHubReleasePayload.self, from: data)
        guard let asset = payload.assets.first(where: { asset in
            let name = asset.name.lowercased()
            return name.hasSuffix(".zip") && name.contains("macos")
        }) ?? payload.assets.first(where: { $0.name.lowercased().hasSuffix(".zip") }) else {
            throw GitHubUpdateError.noMacOSArchive
        }

        return UpdateRelease(
            version: payload.tagName,
            asset: UpdateAsset(name: asset.name, downloadURL: asset.browserDownloadURL, byteCount: asset.size)
        )
    }

    func downloadAndPrepare(
        release: UpdateRelease,
        onPreparing: @escaping @Sendable () -> Void
    ) async throws -> DownloadedUpdatePackage {
        let (temporaryURL, response) = try await URLSession.shared.download(from: release.asset.downloadURL)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw GitHubUpdateError.invalidResponse
        }

        onPreparing()

        let updatesRoot = try updateRootDirectory()
        let versionDirectory = updatesRoot.appending(path: sanitizedVersion(release.version), directoryHint: .isDirectory)
        try? FileManager.default.removeItem(at: versionDirectory)
        try FileManager.default.createDirectory(at: versionDirectory, withIntermediateDirectories: true)

        let archiveURL = versionDirectory.appending(path: release.asset.name)
        try FileManager.default.copyItem(at: temporaryURL, to: archiveURL)

        let extractionURL = versionDirectory.appending(path: "extracted", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: extractionURL, withIntermediateDirectories: true)
        try runProcess("/usr/bin/ditto", arguments: ["-x", "-k", archiveURL.path, extractionURL.path], error: .invalidArchive)

        guard let appURL = firstAppBundle(in: extractionURL) else { throw GitHubUpdateError.invalidArchive }
        guard Bundle(url: appURL)?.bundleIdentifier == Bundle.main.bundleIdentifier else {
            throw GitHubUpdateError.bundleMismatch
        }

        try verifySignature(of: appURL)
        return DownloadedUpdatePackage(version: release.version, stagedAppURL: appURL, archiveURL: archiveURL)
    }

    @MainActor
    func scheduleInstallAndRestart(package: DownloadedUpdatePackage) throws {
        let targetAppURL = Bundle.main.bundleURL.standardizedFileURL
        let targetDirectory = targetAppURL.deletingLastPathComponent()
        guard FileManager.default.isWritableFile(atPath: targetDirectory.path) else {
            throw GitHubUpdateError.installationDirectoryNotWritable(targetDirectory)
        }

        let scriptURL = package.archiveURL.deletingLastPathComponent().appending(path: "install-update.sh")
        let script = """
        #!/bin/sh
        set -eu
        SOURCE_APP=\(shellQuote(package.stagedAppURL.path))
        TARGET_APP=\(shellQuote(targetAppURL.path))
        PID=\(ProcessInfo.processInfo.processIdentifier)
        while kill -0 "$PID" 2>/dev/null; do sleep 0.2; done
        TEMP_APP="$TARGET_APP.updating"
        /bin/rm -rf "$TEMP_APP"
        /usr/bin/ditto "$SOURCE_APP" "$TEMP_APP"
        /bin/rm -rf "$TARGET_APP"
        /bin/mv "$TEMP_APP" "$TARGET_APP"
        /usr/bin/open -n "$TARGET_APP"
        """
        try script.write(to: scriptURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: scriptURL.path)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = [scriptURL.path]
        try process.run()
        NSApplication.shared.terminate(nil)
    }

    private func verifySignature(of candidate: URL) throws {
        try runProcess("/usr/bin/codesign", arguments: ["--verify", "--deep", "--strict", candidate.path], error: .signatureInvalid)

        let currentTeam = try? teamIdentifier(of: Bundle.main.bundleURL)
        let candidateTeam = try? teamIdentifier(of: candidate)
        if let currentTeam, currentTeam != "not set", currentTeam != candidateTeam {
            throw GitHubUpdateError.signerMismatch
        }
    }

    private func teamIdentifier(of appURL: URL) throws -> String? {
        let output = try processOutput("/usr/bin/codesign", arguments: ["-d", "--verbose=4", appURL.path])
        return output
            .split(separator: "\n")
            .first(where: { $0.hasPrefix("TeamIdentifier=") })
            .map { String($0.dropFirst("TeamIdentifier=".count)) }
    }

    private func updateRootDirectory() throws -> URL {
        let root = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let updates = root
            .appending(path: "AkangMacPastie", directoryHint: .isDirectory)
            .appending(path: "Updates", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: updates, withIntermediateDirectories: true)
        return updates
    }

    private func firstAppBundle(in directory: URL) -> URL? {
        let enumerator = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])
        while let candidate = enumerator?.nextObject() as? URL, candidate.pathExtension == "app" {
            return candidate
        }
        return nil
    }

    private func runProcess(_ executable: String, arguments: [String], error: GitHubUpdateError) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { throw error }
    }

    private func processOutput(_ executable: String, arguments: [String]) throws -> String {
        let process = Process()
        let output = Pipe()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = output
        process.standardError = output
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { throw GitHubUpdateError.signatureInvalid }
        return String(decoding: output.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
    }

    private func sanitizedVersion(_ value: String) -> String {
        value.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: "\\", with: "-")
    }

    private func shellQuote(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\\\"'\\\"'"))'"
    }
}
