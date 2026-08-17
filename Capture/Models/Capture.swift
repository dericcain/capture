import Foundation
import SwiftData

@Model
final class Capture {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var source: CaptureSource
    var rawText: String?
    @Relationship(deleteRule: .cascade) var attachments: [Attachment]
    var transcriptionStatus: ProcessingStatus
    var enrichmentStatus: ProcessingStatus
    @Attribute(.transformable) var correctedAreas: [String]
    @Attribute(.transformable) var correctedPeople: [String]
    var isImportant: Bool

    init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        source: CaptureSource,
        rawText: String? = nil,
        attachments: [Attachment] = [],
        transcriptionStatus: ProcessingStatus? = nil,
        enrichmentStatus: ProcessingStatus = .pending,
        correctedAreas: [String] = [],
        correctedPeople: [String] = [],
        isImportant: Bool = false
    ) {
        self.id = id
        self.createdAt = createdAt
        self.source = source
        self.rawText = rawText
        self.attachments = attachments
        self.transcriptionStatus = transcriptionStatus ?? (source == .voice ? .pending : .completed)
        self.enrichmentStatus = enrichmentStatus
        self.correctedAreas = correctedAreas
        self.correctedPeople = correctedPeople
        self.isImportant = isImportant
    }
}
