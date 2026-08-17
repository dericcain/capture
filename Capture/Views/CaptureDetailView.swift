import SwiftData
import SwiftUI
import UIKit

struct CaptureDetailView: View {
    let capture: Capture
    @Environment(\.modelContext) private var modelContext
    @Query private var enrichments: [Enrichment]
    @State private var correctedPeopleText = ""
    @State private var correctedAreasText = ""

    init(capture: Capture) {
        self.capture = capture
        let captureID = capture.id
        _enrichments = Query(filter: #Predicate<Enrichment> { $0.captureId == captureID })
    }

    private var enrichment: Enrichment? {
        enrichments.first
    }

    private var displayedPeople: [String] {
        capture.correctedPeople.isEmpty ? (enrichment?.people ?? []) : capture.correctedPeople
    }

    private var displayedAreas: [String] {
        capture.correctedAreas.isEmpty ? (enrichment?.areas ?? []) : capture.correctedAreas
    }

    var body: some View {
        Form {
            Section("Original Capture") {
                LabeledContent("Source", value: capture.source.rawValue.capitalized)
                LabeledContent("Created", value: capture.createdAt.formatted(date: .abbreviated, time: .shortened))
                LabeledContent("Transcription", value: capture.transcriptionStatus.displayName)
                LabeledContent("Enrichment", value: capture.enrichmentStatus.displayName)

                if let rawText = capture.rawText, !rawText.isEmpty {
                    Text(rawText)
                        .textSelection(.enabled)
                } else {
                    Text(capture.source.placeholderPreview)
                        .foregroundStyle(.secondary)
                }
            }

            if let enrichment, capture.enrichmentStatus == .completed {
                Section("AI Summary") {
                    Text(enrichment.summary)
                    if enrichment.confidence > 0 {
                        Text("Confidence: \(Int(enrichment.confidence * 100))%")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                if !displayedAreas.isEmpty {
                    chipSection(title: "Areas", values: displayedAreas, tint: .blue)
                }
                if !displayedPeople.isEmpty {
                    chipSection(title: "People", values: displayedPeople, tint: .purple)
                }
                if !enrichment.topics.isEmpty {
                    chipSection(title: "Topics", values: enrichment.topics, tint: .green)
                }
                if !enrichment.tasks.isEmpty {
                    chipSection(title: "Tasks", values: enrichment.tasks, tint: .orange)
                }
                if !enrichment.dates.isEmpty {
                    chipSection(title: "Dates", values: enrichment.dates, tint: .pink)
                }
            }

            Section("Corrections") {
                Toggle("Mark as important", isOn: Binding(
                    get: { capture.isImportant },
                    set: { capture.isImportant = $0; saveCorrections() }
                ))

                TextField("Correct people (comma separated)", text: $correctedPeopleText, axis: .vertical)
                    .textInputAutocapitalization(.words)
                TextField("Correct areas (comma separated)", text: $correctedAreasText, axis: .vertical)

                Button("Save Corrections") {
                    capture.correctedPeople = correctedPeopleText.csvValues
                    capture.correctedAreas = correctedAreasText.csvValues
                    saveCorrections()
                }
            }

            if !capture.attachments.isEmpty {
                Section("Attachments") {
                    ForEach(capture.attachments) { attachment in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(attachment.filename)
                                .font(.headline)

                            if attachment.type == .image,
                               let localPath = attachment.localPath,
                               let image = UIImage(contentsOfFile: localPath) {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxHeight: 240)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }

                            if let urlString = attachment.url ?? attachment.localPath {
                                Text(urlString)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .navigationTitle("Capture Detail")
        .onAppear {
            correctedPeopleText = capture.correctedPeople.joined(separator: ", ")
            correctedAreasText = capture.correctedAreas.joined(separator: ", ")
        }
    }

    @ViewBuilder
    private func chipSection(title: String, values: [String], tint: Color) -> some View {
        Section(title) {
            FlowLayout(values: values, tint: tint)
        }
    }

    private func saveCorrections() {
        do {
            try modelContext.save()
        } catch {
            assertionFailure(error.localizedDescription)
        }
    }
}

private struct FlowLayout: View {
    let values: [String]
    let tint: Color
    private var rows: [[String]] {
        chunked(values, size: 3)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(rows.indices, id: \.self) { rowIndex in
                HStack {
                    ForEach(rows[rowIndex].indices, id: \.self) { valueIndex in
                        StatusChip(title: rows[rowIndex][valueIndex], tint: tint)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
    }

    private func chunked(_ values: [String], size: Int) -> [[String]] {
        stride(from: 0, to: values.count, by: size).map {
            Array(values[$0..<min($0 + size, values.count)])
        }
    }
}

private extension String {
    var csvValues: [String] {
        split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}
