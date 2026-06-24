//
//  AppLogger.swift
//  XYDevTool
//

import AppKit
import Foundation

final class AppLogOperation {
    private let category: AppLogCategory
    private let name: String
    private let startedAt = ProcessInfo.processInfo.systemUptime
    private let initialMetadata: [String: String]
    private let lock = NSLock()
    private var isFinished = false

    init(category: AppLogCategory, name: String, metadata: [String: String]) {
        self.category = category
        self.name = name
        self.initialMetadata = metadata
    }

    func finish(
        result: AppLogResult,
        level: AppLogLevel? = nil,
        metadata: [String: String] = [:]
    ) {
        lock.lock()
        guard isFinished == false else {
            lock.unlock()
            return
        }
        isFinished = true
        lock.unlock()

        let duration = (ProcessInfo.processInfo.systemUptime - startedAt) * 1_000
        AppLogger.shared.track(
            category: category,
            name: name,
            level: level ?? (result == .failure ? .error : .info),
            result: result,
            durationMS: duration,
            metadata: initialMetadata.merging(metadata) { _, new in new }
        )
    }
}

final class AppLogger {
    static let shared = AppLogger()

    private let queue = DispatchQueue(label: "com.xiaoyou.XYDevTool.app-logger")
    private let store = AppLogStore()
    private let sessionID = UUID()
    private let sessionStartedAt = ProcessInfo.processInfo.systemUptime
    private var sequence = 0
    private var sessionStarted = false

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
    }

    private var buildVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown"
    }

    private init() {}

    func startSession() {
        queue.sync {
            beginSessionIfNeeded()
        }
    }

    func finishSession() {
        queue.sync {
            guard sessionStarted else { return }
            let duration = (ProcessInfo.processInfo.systemUptime - sessionStartedAt) * 1_000
            append(
                category: .app,
                name: "app_finished",
                result: .success,
                durationMS: duration
            )
            store.clearActiveSession()
            sessionStarted = false
        }
    }

    func track(
        category: AppLogCategory,
        name: String,
        level: AppLogLevel = .info,
        result: AppLogResult? = nil,
        durationMS: Double? = nil,
        metadata: [String: String] = [:]
    ) {
        queue.async { [weak self] in
            guard let self else { return }
            self.beginSessionIfNeeded()
            self.append(
                category: category,
                name: name,
                level: level,
                result: result,
                durationMS: durationMS,
                metadata: metadata
            )
        }
    }

    func begin(
        category: AppLogCategory,
        name: String,
        metadata: [String: String] = [:]
    ) -> AppLogOperation {
        AppLogOperation(category: category, name: name, metadata: metadata)
    }

    func loadEvents(limit: Int = 5_000, completion: @escaping ([AppLogEvent]) -> Void) {
        queue.async { [store] in
            let events = store.readEvents(limit: limit)
            DispatchQueue.main.async {
                completion(events)
            }
        }
    }

    func clearLogs(completion: (() -> Void)? = nil) {
        queue.async { [store] in
            store.clearEventFiles()
            DispatchQueue.main.async {
                completion?()
            }
        }
    }

    func revealLogDirectory() {
        let url = store.logDirectoryURL
        queue.async { [store] in
            store.prepare()
            DispatchQueue.main.async {
                NSWorkspace.shared.activateFileViewerSelecting([url])
            }
        }
    }

    private func append(
        category: AppLogCategory,
        name: String,
        level: AppLogLevel = .info,
        result: AppLogResult? = nil,
        durationMS: Double? = nil,
        metadata: [String: String] = [:]
    ) {
        sequence += 1
        let event = AppLogEvent(
            id: UUID(),
            timestamp: Date(),
            sessionID: sessionID,
            sequence: sequence,
            level: level,
            category: category,
            name: name,
            result: result,
            durationMS: durationMS,
            metadata: metadata,
            appVersion: appVersion,
            buildVersion: buildVersion
        )
        store.append(event)
    }

    private func beginSessionIfNeeded() {
        guard sessionStarted == false else { return }
        sessionStarted = true
        store.prepare()

        let previousSessionID = store.activeSessionID()
        store.markSessionActive(sessionID)
        append(
            category: .app,
            name: "app_started",
            metadata: [
                "osVersion": ProcessInfo.processInfo.operatingSystemVersionString,
                "processorCount": String(ProcessInfo.processInfo.processorCount)
            ]
        )

        if let previousSessionID, previousSessionID != sessionID {
            append(
                category: .app,
                name: "previous_session_abnormally_terminated",
                level: .warning,
                result: .failure,
                metadata: ["previousSessionID": previousSessionID.uuidString]
            )
        }
    }
}

private final class AppLogStore {
    let logDirectoryURL: URL

    private let fileManager = FileManager.default
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }()
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private let maximumFileSize: UInt64 = 10 * 1_024 * 1_024
    private let maximumTotalSize: UInt64 = 100 * 1_024 * 1_024
    private let retentionDays = 14
    private let activeSessionFileName = "active-session.json"

    init() {
        if let overridePath = ProcessInfo.processInfo.environment["XYDEVTOOL_LOG_DIRECTORY"],
           overridePath.isEmpty == false {
            logDirectoryURL = URL(fileURLWithPath: overridePath, isDirectory: true)
            return
        }

        let libraryURL = fileManager.urls(for: .libraryDirectory, in: .userDomainMask).first
            ?? fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Library", isDirectory: true)
        logDirectoryURL = libraryURL
            .appendingPathComponent("Logs", isDirectory: true)
            .appendingPathComponent("XYDevTool", isDirectory: true)
    }

    func prepare() {
        try? fileManager.createDirectory(at: logDirectoryURL, withIntermediateDirectories: true)
        removeExpiredFiles()
    }

    func append(_ event: AppLogEvent) {
        prepareDirectoryIfNeeded()
        guard var data = try? encoder.encode(event) else { return }
        data.append(0x0A)

        let fileURL = writableEventFileURL()
        if fileManager.fileExists(atPath: fileURL.path) == false {
            fileManager.createFile(atPath: fileURL.path, contents: nil)
        }

        do {
            let handle = try FileHandle(forWritingTo: fileURL)
            try handle.seekToEnd()
            try handle.write(contentsOf: data)
            try handle.synchronize()
            try handle.close()
        } catch {
            NSLog("XYDevTool log write failed: %@", error.localizedDescription)
        }
    }

    func readEvents(limit: Int) -> [AppLogEvent] {
        let files = eventFileURLs().sorted { $0.lastPathComponent > $1.lastPathComponent }
        var events: [AppLogEvent] = []

        for fileURL in files {
            guard let data = try? Data(contentsOf: fileURL),
                  let content = String(data: data, encoding: .utf8) else { continue }

            for line in content.split(whereSeparator: \.isNewline).reversed() {
                guard let lineData = line.data(using: .utf8),
                      let event = try? decoder.decode(AppLogEvent.self, from: lineData) else { continue }
                events.append(event)
                if events.count >= limit {
                    return events.sorted { $0.timestamp > $1.timestamp }
                }
            }
        }

        return events.sorted { $0.timestamp > $1.timestamp }
    }

    func activeSessionID() -> UUID? {
        let url = logDirectoryURL.appendingPathComponent(activeSessionFileName)
        guard let data = try? Data(contentsOf: url),
              let value = try? decoder.decode(ActiveSession.self, from: data) else { return nil }
        return value.sessionID
    }

    func markSessionActive(_ sessionID: UUID) {
        prepareDirectoryIfNeeded()
        let url = logDirectoryURL.appendingPathComponent(activeSessionFileName)
        let value = ActiveSession(sessionID: sessionID, startedAt: Date())
        guard let data = try? encoder.encode(value) else { return }
        try? data.write(to: url, options: .atomic)
    }

    func clearActiveSession() {
        let url = logDirectoryURL.appendingPathComponent(activeSessionFileName)
        try? fileManager.removeItem(at: url)
    }

    func clearEventFiles() {
        eventFileURLs().forEach { try? fileManager.removeItem(at: $0) }
    }

    private func prepareDirectoryIfNeeded() {
        if fileManager.fileExists(atPath: logDirectoryURL.path) == false {
            try? fileManager.createDirectory(at: logDirectoryURL, withIntermediateDirectories: true)
        }
    }

    private func writableEventFileURL() -> URL {
        let date = dateFormatter.string(from: Date())
        var index = 0

        while true {
            let suffix = index == 0 ? "" : "-\(index)"
            let candidate = logDirectoryURL.appendingPathComponent("events-\(date)\(suffix).jsonl")
            let attributes = try? fileManager.attributesOfItem(atPath: candidate.path)
            let size = (attributes?[.size] as? NSNumber)?.uint64Value ?? 0
            if size < maximumFileSize { return candidate }
            index += 1
        }
    }

    private func eventFileURLs() -> [URL] {
        let keys: [URLResourceKey] = [.isRegularFileKey, .contentModificationDateKey]
        let urls = (try? fileManager.contentsOfDirectory(
            at: logDirectoryURL,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles]
        )) ?? []
        return urls.filter { $0.lastPathComponent.hasPrefix("events-") && $0.pathExtension == "jsonl" }
    }

    private func removeExpiredFiles() {
        guard let cutoff = Calendar.current.date(byAdding: .day, value: -retentionDays, to: Date()) else { return }
        for url in eventFileURLs() {
            let values = try? url.resourceValues(forKeys: [.contentModificationDateKey])
            if let modifiedAt = values?.contentModificationDate, modifiedAt < cutoff {
                try? fileManager.removeItem(at: url)
            }
        }
        enforceTotalSizeLimit()
    }

    private func enforceTotalSizeLimit() {
        let filesWithValues = eventFileURLs().compactMap { url -> (URL, Date, UInt64)? in
            guard let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey]) else {
                return nil
            }
            return (
                url,
                values.contentModificationDate ?? .distantPast,
                UInt64(values.fileSize ?? 0)
            )
        }

        var totalSize = filesWithValues.reduce(UInt64(0)) { $0 + $1.2 }
        for file in filesWithValues.sorted(by: { $0.1 < $1.1 }) where totalSize > maximumTotalSize {
            guard (try? fileManager.removeItem(at: file.0)) != nil else { continue }
            totalSize = totalSize >= file.2 ? totalSize - file.2 : 0
        }
    }
}

private struct ActiveSession: Codable {
    let sessionID: UUID
    let startedAt: Date
}
