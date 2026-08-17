import Foundation
import SwiftData

final class PersistenceService {
    static let appGroupIdentifier = "group.com.dericcain.capture"

    static let sharedModelContainer: ModelContainer = {
        do {
            let schema = Schema([Capture.self, Enrichment.self, Attachment.self])
            let storeURL = appGroupContainerURL()?.appending(path: "capture.store") ?? URL.documentsDirectory.appending(path: "capture.store")
            let config = ModelConfiguration(schema: schema, url: storeURL)
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Unable to create ModelContainer: \(error.localizedDescription)")
        }
    }()

    static func appGroupContainerURL() -> URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)
    }

    static func documentsDirectory(subdirectory: String? = nil) throws -> URL {
        let baseURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        guard let subdirectory else { return baseURL }
        let directory = baseURL.appending(path: subdirectory, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    static func makeUniqueDocumentURL(filename: String, subdirectory: String) throws -> URL {
        let directory = try documentsDirectory(subdirectory: subdirectory)
        let base = URL(fileURLWithPath: filename).deletingPathExtension().lastPathComponent
        let ext = URL(fileURLWithPath: filename).pathExtension
        var candidate = directory.appending(path: filename)
        var counter = 1
        while FileManager.default.fileExists(atPath: candidate.path) {
            let newFilename = ext.isEmpty ? "\(base)-\(counter)" : "\(base)-\(counter).\(ext)"
            candidate = directory.appending(path: newFilename)
            counter += 1
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
