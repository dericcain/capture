import Foundation

enum CaptureSource: String, Codable, CaseIterable, Identifiable {
    case voice
    case text
    case photo
    case screenshot
    case file
    case url

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .voice: "mic.fill"
        case .text: "text.cursor"
        case .photo: "photo"
        case .screenshot: "camera.viewfinder"
        case .file: "doc.fill"
        case .url: "link"
        }
    }

    var placeholderPreview: String {
        switch self {
        case .voice: "[Voice note]"
        case .text: "[Text capture]"
        case .photo: "[Photo]"
        case .screenshot: "[Screenshot]"
        case .file: "[File]"
        case .url: "[URL]"
        }
    }
}

enum ProcessingStatus: String, Codable, CaseIterable, Identifiable {
    case pending
    case processing
    case completed
    case failed

    var id: String { rawValue }

    var displayName: String {
        rawValue.capitalized
    }

    var tintColorName: String {
        switch self {
        case .pending: "gray"
        case .processing: "orange"
        case .completed: "green"
        case .failed: "red"
        }
    }
}

enum AttachmentType: String, Codable, CaseIterable, Identifiable {
    case image
    case file
    case url

    var id: String { rawValue }
}
