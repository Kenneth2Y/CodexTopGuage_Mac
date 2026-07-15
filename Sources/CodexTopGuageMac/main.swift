import AppKit
import Foundation

struct UsageSnapshot {
    let primaryPercent: Int?
    let secondaryPercent: Int?
    let primaryWindowMinutes: Int?
    let secondaryWindowMinutes: Int?
    let primaryResetsAt: Date?
    let secondaryResetsAt: Date?
    let totalTokens: Int?
    let limitId: String?
    let limitName: String?
    let source: String
    let fetchedAt: Date
}

struct AppServerUsageProvider: Sendable {
    private static let codexExecutableCandidates = [
        "/Applications/ChatGPT.app/Contents/Resources/codex",
        "/Applications/Codex.app/Contents/Resources/codex"
    ]

    private let codexPath: String
    private let timeout: TimeInterval

    init(
        codexPath: String? = nil,
        timeout: TimeInterval = 5
    ) {
        self.codexPath = codexPath ?? Self.discoverCodexExecutable()
        self.timeout = timeout
    }

    private static func discoverCodexExecutable() -> String {
        codexExecutableCandidates.first(where: {
            FileManager.default.isExecutableFile(atPath: $0)
        }) ?? codexExecutableCandidates[0]
    }

    func fetch() async throws -> UsageSnapshot {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                do {
                    continuation.resume(returning: try self.fetchBlocking())
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func fetchBlocking() throws -> UsageSnapshot {
        guard FileManager.default.isExecutableFile(atPath: codexPath) else {
            throw UsageError.codexNotFound(codexPath)
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: codexPath)
        process.arguments = ["app-server", "--listen", "stdio://"]

        let input = Pipe()
        let output = Pipe()
        let errorOutput = Pipe()
        process.standardInput = input
        process.standardOutput = output
        process.standardError = errorOutput

        try process.run()
        defer {
            if process.isRunning {
                process.terminate()
            }
        }

        let messages: [[String: Any]] = [
            [
                "id": "codex-top-guage-init",
                "method": "initialize",
                "params": [
                    "clientInfo": [
                        "name": "codex-top-guage-mac",
                        "title": "CodexTopGuage Mac",
                        "version": "0.1.0"
                    ],
                    "capabilities": [
                        "experimentalApi": true,
                        "requestAttestation": false,
                        "optOutNotificationMethods": []
                    ]
                ]
            ],
            [
                "id": "codex-top-guage-usage",
                "method": "account/rateLimits/read"
            ]
        ]

        for message in messages {
            let data = try JSONSerialization.data(withJSONObject: message, options: [])
            input.fileHandleForWriting.write(data)
            input.fileHandleForWriting.write(Data([0x0a]))
        }

        let deadline = Date().addingTimeInterval(timeout)
        var buffer = Data()

        while Date() < deadline {
            let available = output.fileHandleForReading.availableData
            if available.isEmpty {
                Thread.sleep(forTimeInterval: 0.05)
                continue
            }

            buffer.append(available)
            let lines = String(decoding: buffer, as: UTF8.self).split(separator: "\n", omittingEmptySubsequences: true)

            for line in lines {
                guard
                    let data = String(line).data(using: .utf8),
                    let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                    object["id"] as? String == "codex-top-guage-usage"
                else {
                    continue
                }

                if let error = object["error"] {
                    throw UsageError.serverError(String(describing: error))
                }

                guard let result = object["result"] as? [String: Any] else {
                    throw UsageError.missingRateLimits
                }

                return try parseSnapshot(from: result)
            }
        }

        throw UsageError.timeout
    }

    private func parseSnapshot(from result: [String: Any]) throws -> UsageSnapshot {
        let selectedLimit: [String: Any]?

        if
            let preferredLimitId = result["preferredLimitId"] as? String,
            let limitsById = result["rateLimitsByLimitId"] as? [String: Any],
            let preferred = limitsById[preferredLimitId] as? [String: Any]
        {
            selectedLimit = preferred
        } else if let limits = result["rateLimits"] as? [[String: Any]] {
            selectedLimit = limits.first
        } else if let limitsById = result["rateLimitsByLimitId"] as? [String: Any] {
            selectedLimit = limitsById.values.compactMap { $0 as? [String: Any] }.first
        } else {
            selectedLimit = result
        }

        guard let limit = selectedLimit else {
            throw UsageError.missingRateLimits
        }

        let primary = limit["primary"] as? [String: Any]
        let secondary = limit["secondary"] as? [String: Any]

        return UsageSnapshot(
            primaryPercent: percentValue(from: primary?["usedPercent"] ?? primary?["used_percent"]),
            secondaryPercent: percentValue(from: secondary?["usedPercent"] ?? secondary?["used_percent"]),
            primaryWindowMinutes: int(from: primary?["windowDurationMins"] ?? primary?["window_duration_mins"]),
            secondaryWindowMinutes: int(from: secondary?["windowDurationMins"] ?? secondary?["window_duration_mins"]),
            primaryResetsAt: date(from: primary?["resetsAt"] ?? primary?["resets_at"]),
            secondaryResetsAt: date(from: secondary?["resetsAt"] ?? secondary?["resets_at"]),
            totalTokens: int(from: limit["totalTokens"] ?? limit["total_tokens"]),
            limitId: limit["limitId"] as? String ?? limit["limit_id"] as? String,
            limitName: limit["limitName"] as? String ?? limit["limit_name"] as? String,
            source: "app-server",
            fetchedAt: Date()
        )
    }

    private func percentValue(from value: Any?) -> Int? {
        guard let number = double(from: value) else {
            return nil
        }

        return min(100, max(0, Int(number.rounded())))
    }

    private func date(from value: Any?) -> Date? {
        guard let number = double(from: value), number > 0 else {
            return nil
        }

        return Date(timeIntervalSince1970: number)
    }

    private func int(from value: Any?) -> Int? {
        guard let number = double(from: value) else {
            return nil
        }

        return Int(number.rounded())
    }

    private func double(from value: Any?) -> Double? {
        switch value {
        case let number as Double:
            return number
        case let number as Int:
            return Double(number)
        case let number as NSNumber:
            return number.doubleValue
        case let string as String:
            return Double(string)
        default:
            return nil
        }
    }
}

enum UsageError: LocalizedError {
    case codexNotFound(String)
    case missingRateLimits
    case serverError(String)
    case timeout

    var errorDescription: String? {
        switch self {
        case .codexNotFound(let path):
            return "Codex executable not found: \(path)"
        case .missingRateLimits:
            return "Usage data unavailable"
        case .serverError(let message):
            return "Codex app-server error: \(message)"
        case .timeout:
            return "Codex app-server timed out"
        }
    }
}

@MainActor
final class MenuBarController: NSObject, NSApplicationDelegate {
    private struct DisplayWindow {
        let label: String
        let usedPercent: Int
        let resetsAt: Date?
    }

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let provider = AppServerUsageProvider()
    private var timer: Timer?
    private let refreshInterval: TimeInterval = 5
    private var latestSnapshot: UsageSnapshot?
    private var latestError: String?
    private var isRefreshing = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        statusItem.button?.title = "Codex: --"
        statusItem.button?.toolTip = "Codex usage"
        refresh()
        scheduleTimer()
    }

    private func scheduleTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refresh()
            }
        }
    }

    private func refresh() {
        guard !isRefreshing else {
            return
        }

        isRefreshing = true
        statusItem.button?.title = latestSnapshot.map(statusTitle) ?? "Codex: ..."

        Task {
            do {
                latestSnapshot = try await provider.fetch()
                latestError = nil
            } catch {
                latestError = error.localizedDescription
            }

            isRefreshing = false
            render()
        }
    }

    private func render() {
        if let snapshot = latestSnapshot {
            statusItem.button?.title = statusTitle(for: snapshot)
        } else {
            statusItem.button?.title = "Codex: --"
        }

        statusItem.menu = buildMenu()
    }

    private func statusTitle(for snapshot: UsageSnapshot) -> String {
        let values = displayWindows(for: snapshot).map {
            "\($0.label)\(remainingPercent(fromUsedPercent: $0.usedPercent))"
        }

        return values.isEmpty ? "Codex: --" : "Codex: \(values.joined(separator: " "))"
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false

        if let snapshot = latestSnapshot {
            let windows = displayWindows(for: snapshot)

            for window in windows {
                menu.addItem(infoItem("\(window.label) remaining: \(remainingPercent(fromUsedPercent: window.usedPercent))"))
            }

            for window in windows {
                menu.addItem(infoItem("\(window.label) reset: \(countdown(to: window.resetsAt))"))
            }

            menu.addItem(infoItem("Source: \(snapshot.source)"))
            menu.addItem(infoItem("Last updated: \(format(snapshot.fetchedAt))"))

            if let limitName = snapshot.limitName {
                menu.addItem(infoItem("Limit: \(limitName)"))
            }

            if let limitId = snapshot.limitId {
                menu.addItem(infoItem("Limit ID: \(limitId)"))
            }
        } else {
            menu.addItem(infoItem("Usage unavailable"))
        }

        if let latestError {
            menu.addItem(infoItem("Status: \(latestError)"))
        }

        let quitItem = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        return menu
    }

    private func infoItem(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = true
        return item
    }

    private func displayWindows(for snapshot: UsageSnapshot) -> [DisplayWindow] {
        var windows: [DisplayWindow] = []

        if let usedPercent = snapshot.primaryPercent {
            windows.append(DisplayWindow(
                label: durationLabel(minutes: snapshot.primaryWindowMinutes, fallback: "5h"),
                usedPercent: usedPercent,
                resetsAt: snapshot.primaryResetsAt
            ))
        }

        if let usedPercent = snapshot.secondaryPercent {
            windows.append(DisplayWindow(
                label: durationLabel(minutes: snapshot.secondaryWindowMinutes, fallback: "7d"),
                usedPercent: usedPercent,
                resetsAt: snapshot.secondaryResetsAt
            ))
        }

        return windows
    }

    private func durationLabel(minutes: Int?, fallback: String) -> String {
        guard let minutes, minutes > 0 else {
            return fallback
        }

        if minutes.isMultiple(of: 1_440) {
            return "\(minutes / 1_440)d"
        }

        if minutes.isMultiple(of: 60) {
            return "\(minutes / 60)h"
        }

        return "\(minutes)m"
    }

    private func remainingPercent(fromUsedPercent usedPercent: Int?) -> String {
        guard let usedPercent else {
            return "--"
        }

        return "\(max(0, min(100, 100 - usedPercent)))%"
    }

    private func countdown(to date: Date?) -> String {
        guard let date else {
            return "unavailable"
        }

        let seconds = max(0, Int(date.timeIntervalSinceNow))
        let days = seconds / 86_400
        let hours = (seconds % 86_400) / 3_600
        let minutes = (seconds % 3_600) / 60

        if days > 0 {
            return "\(days)d \(hours)h"
        }

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }

        return "\(minutes)m"
    }

    private func format(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

let app = NSApplication.shared
let delegate = MenuBarController()
app.delegate = delegate
app.run()
