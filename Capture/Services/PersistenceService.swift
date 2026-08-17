import Foundation
import SwiftData

final class PersistenceService {
    static let appGroupIdentifier = "group.com.capture.shared"
    static let sharedUserDefaults = UserDefaults(suiteName: appGroupIdentifier) ?? .standard

    private static let sharedStoreFilename = "Capture.store"

    static let sharedModelContainer: ModelContainer = {
        do {
            let configuration = ModelConfiguration(
                url: try sharedStoreURL(),
                allowsSave: true
            )
            return try ModelContainer(for: Capture.self, Enrichment.self, Attachment.self, configurations: configuration)
        } catch {
            fatalError("Unable to create ModelContainer: \(error.localizedDescription)")
        }
    }()

    private static func sharedContainerDirectory() throws -> URL {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else {
            throw CocoaError(.fileNoSuchFile)
        }

        try FileManager.default.createDirectory(at: containerURL, withIntermediateDirectories: true)
        return containerURL
    }

    private static func sharedStoreURL() throws -> URL {
        try sharedContainerDirectory().appending(path: sharedStoreFilename)
    }

    static func documentsDirectory(subdirectory: String? = nil) throws -> URL {
        let baseURL = try sharedContainerDirectory()
        guard let subdirectory else { return baseURL }
        let directory = baseURL.appending(path: subdirectory, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    static func makeUniqueDocumentURL(filename: String, subdirectory: String) throws -> URL {
        let directory = try documentsDirectory(subdirectory: subdirectory)
        let baseName = URL(fileURLWithPath: filename).deletingPathExtension().lastPathComponent
        let fileExtension = URL(fileURLWithPath: filename).pathExtension
        let fileManager = FileManager.default

        func makeCandidate(_ index: Int?) -> URL {
            let suffix = index.map { "-\($0)" } ?? ""
            let name = fileExtension.isEmpty ? "\(baseName)\(suffix)" : "\(baseName)\(suffix).\(fileExtension)"
            return directory.appending(path: name)
        }

        var candidate = makeCandidate(nil)
        var index = 1
        while fileManager.fileExists(atPath: candidate.path) {
            candidate = makeCandidate(index)
            index += 1
        }
        return candidate
    }

    static func saveDataToDocuments(_ data: Data, filename: String, subdirectory: String) throws -> URL {
        let url = try makeUniqueDocumentURL(filename: filename, subdirectory: subdirectory)
        try data.write(to: url, options: .atomic)
        return url
    }

    static func copyFileToDocuments(from sourceURL: URL, subdirectory: String) throws -> URL {
        let needsSecurityScope = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if needsSecurityScope {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        let destinationURL = try makeUniqueDocumentURL(filename: sourceURL.lastPathComponent, subdirectory: subdirectory)
        try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
        return destinationURL
    }

    static func removeStoredFiles() throws {
        let fileManager = FileManager.default
        let directories = ["Recordings", "Photos", "Files"]
        for directory in directories {
            let url = try documentsDirectory(subdirectory: directory)
            if fileManager.fileExists(atPath: url.path) {
                try fileManager.removeItem(at: url)
            }
        }
    }
}
