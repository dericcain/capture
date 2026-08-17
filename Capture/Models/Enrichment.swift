import Foundation
import SwiftData

@Model
final class Enrichment {
    @Attribute(.unique) var captureId: UUID
    var summary: String
    var areas: [String]
    var people: [String]
    var topics: [String]
    var tasks: [String]
    var dates: [String]
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
