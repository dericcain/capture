import SwiftUI

struct CaptureRowView: View {
    let capture: Capture
    let enrichment: Enrichment?

    private var preview: String {
        if let rawText = capture.rawText?.trimmingCharacters(in: .whitespacesAndNewlines), !rawText.isEmpty {
            return rawText
        }

        if let summary = enrichment?.summary, !summary.isEmpty {
            return summary
        }

        return capture.source.placeholderPreview
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: capture.source.systemImage)
                .font(.title3)
                .foregroundStyle(Color.accentColor)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(capture.createdAt.relativeTimestamp)
                        .font(.subheadline.weight(.medium))
                    if capture.isImportant {
                        Image(systemName: "star.fill")
                            .foregroundStyle(.yellow)
                    }
                }

                Text(preview)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }
}
