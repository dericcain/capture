import SwiftData
import SwiftUI

struct RecentView: View {
    @Query(sort: \Capture.createdAt, order: .reverse) private var captures: [Capture]
    @Query private var enrichments: [Enrichment]
    @State private var searchText = ""

    private var enrichmentByCaptureId: [UUID: Enrichment] {
        Dictionary(uniqueKeysWithValues: enrichments.map { ($0.captureId, $0) })
    }

    private var filteredCaptures: [Capture] {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return captures
        }

        let query = searchText.lowercased()
        return captures.filter { capture in
            let enrichment = enrichmentByCaptureId[capture.id]
            let terms = [
                capture.rawText ?? "",
                enrichment?.summary ?? "",
                enrichment?.topics.joined(separator: " ") ?? "",
                enrichment?.people.joined(separator: " ") ?? "",
                capture.correctedPeople.joined(separator: " "),
                capture.correctedAreas.joined(separator: " ")
            ]
            .joined(separator: " ")
            .lowercased()

            return terms.contains(query)
        }
    }

    var body: some View {
        List(filteredCaptures) { capture in
            NavigationLink {
                CaptureDetailView(capture: capture)
            } label: {
                CaptureRowView(capture: capture, enrichment: enrichmentByCaptureId[capture.id])
            }
        }
        .navigationTitle("Recent")
        .searchable(text: $searchText, prompt: "Search captures, summaries, topics, people")
        .overlay {
            if filteredCaptures.isEmpty {
                ContentUnavailableView.search(text: searchText)
            }
        }
    }
}
