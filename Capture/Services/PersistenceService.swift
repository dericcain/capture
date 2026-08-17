import Foundation
import SwiftData

final class PersistenceService {
    static let sharedModelContainer: ModelContainer = {
        do {
            return try ModelContainer(for: Capture.self, Enrichment.self, Attachment.self)
        } catch {
            fatalError("Unable to create ModelContainer: \(error.localizedDescription)")
        }
    }()

    static func documentsDirectory(subdirectory: String? = nil) throws -> URL {
        let baseURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        guard let subdirectory else { return baseURL }
        let directory = baseURL.appending(path: subdirectory, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    static func makeUniqueDocumentURL(filename: String, subdirectory: String) throws -> URL {
        try documentsDirectory(subdirectory: subdirectory).appending(path: filename)
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
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }
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
