import Foundation
import SwiftData

@Model
final class Enrichment {
    @Attribute(.unique) var captureId: UUID
    var summary: String
    @Attribute(.transformable) var areas: [String]
    @Attribute(.transformable) var people: [String]
    @Attribute(.transformable) var topics: [String]
    @Attribute(.transformable) var tasks: [String]
    @Attribute(.transformable) var dates: [String]
    var confidence: Double

    init(
        captureId: UUID,
        summary: String,
        areas: [String] = [],
        people: [String] = [],
        topics: [String] = [],
        tasks: [String] = [],
        dates: [String] = [],
        confidence: Double = 0
    ) {
        self.captureId = captureId
        self.summary = summary
        self.areas = areas
        self.people = people
        self.topics = topics
        self.tasks = tasks
        self.dates = dates
        self.confidence = confidence
    }
}
