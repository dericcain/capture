import Foundation
import SwiftData

actor BackgroundProcessor {
    static let shared = BackgroundProcessor(container: PersistenceService.sharedModelContainer, openAIService: OpenAIService())

    private let container: ModelContainer
    private let openAIService: OpenAIService

    init(container: ModelContainer, openAIService: OpenAIService) {
        self.container = container
        self.openAIService = openAIService
    }

    func enqueueProcessing(for captureID: UUID) async {
        await process(captureID: captureID)
    }

    private func process(captureID: UUID) async {
        guard await openAIService.hasAPIKey() else { return }

        let context = ModelContext(container)

        do {
            guard let capture = try fetchCapture(id: captureID, in: context) else { return }
            var textForEnrichment = capture.rawText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            if capture.source == .voice,
               let audioPath = capture.attachments.first(where: { $0.localPath != nil })?.localPath {
                capture.transcriptionStatus = .processing
                try? context.save()
                do {
                    let transcription = try await openAIService.transcribeAudio(fileURL: URL(fileURLWithPath: audioPath))
                    capture.rawText = transcription
                    capture.transcriptionStatus = .completed
                    textForEnrichment = transcription
                    try context.save()
                } catch {
                    capture.transcriptionStatus = .failed
                    try? context.save()
                    textForEnrichment = capture.rawText ?? ""
                }
            }

            let fallbackContent = fallbackPromptContent(for: capture)
            let enrichmentInput = [textForEnrichment, fallbackContent]
                .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                .joined(separator: "\n\n")

            guard !enrichmentInput.isEmpty else { return }

            capture.enrichmentStatus = .processing
            try? context.save()

            do {
                let payload = try await openAIService.generateEnrichment(from: enrichmentInput)
                if let existing = try fetchEnrichment(captureID: captureID, in: context) {
                    existing.summary = payload.summary
                    existing.areas = payload.areas
                    existing.people = payload.people
                    existing.topics = payload.topics
                    existing.tasks = payload.tasks
                    existing.dates = payload.dates
                    existing.confidence = payload.confidence
                } else {
                    let enrichment = Enrichment(
                        captureId: captureID,
                        summary: payload.summary,
                        areas: payload.areas,
                        people: payload.people,
                        topics: payload.topics,
                        tasks: payload.tasks,
                        dates: payload.dates,
                        confidence: payload.confidence
                    )
                    context.insert(enrichment)
                }
                capture.enrichmentStatus = .completed
                try context.save()
            } catch {
                capture.enrichmentStatus = .failed
                try? context.save()
            }
        } catch {
            return
        }
    }

    private func fetchCapture(id: UUID, in context: ModelContext) throws -> Capture? {
        try context.fetch(FetchDescriptor<Capture>()).first(where: { $0.id == id })
    }

    private func fetchEnrichment(captureID: UUID, in context: ModelContext) throws -> Enrichment? {
        try context.fetch(FetchDescriptor<Enrichment>()).first(where: { $0.captureId == captureID })
    }

    private func fallbackPromptContent(for capture: Capture) -> String {
        var lines = ["Source: \(capture.source.rawValue)"]
        let attachmentDescriptions = capture.attachments.map { attachment in
            switch attachment.type {
            case .url:
                return attachment.url ?? attachment.filename
            case .image, .file:
                return attachment.filename
            }
        }
        if !attachmentDescriptions.isEmpty {
            lines.append("Attachments: \(attachmentDescriptions.joined(separator: ", "))")
        }
        return lines.joined(separator: "\n")
    }
}
