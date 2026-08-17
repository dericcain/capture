import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage(OpenAIService.apiKeyDefaultsKey, store: PersistenceService.sharedUserDefaults) private var apiKey = ""
    @State private var clearDataConfirmation = false
    @State private var statusMessage: String?
    @State private var retryPendingTask: Task<Void, Never>?

    private var versionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(version) (\(build))"
    }

    var body: some View {
        Form {
            Section("App") {
                LabeledContent("Version", value: versionText)
            }

            Section("OpenAI") {
                SecureField("API key", text: $apiKey)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Text("Stored locally for this prototype using UserDefaults.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Data") {
                Button("Clear all data", role: .destructive) {
                    clearDataConfirmation = true
                }

                if let statusMessage {
                    Text(statusMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Settings")
        .alert("Clear all data?", isPresented: $clearDataConfirmation) {
            Button("Delete", role: .destructive) {
                clearAllData()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes every capture, enrichment, and stored attachment.")
        }
        .onChange(of: apiKey) { _, newValue in
            retryPendingTask?.cancel()
            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.count >= 20 else { return }

            retryPendingTask = Task {
                try? await Task.sleep(for: .milliseconds(600))
                guard !Task.isCancelled else { return }
                await BackgroundProcessor.shared.retryPendingCaptures()
            }
        }
    }

    private func clearAllData() {
        do {
            for attachment in try modelContext.fetch(FetchDescriptor<Attachment>()) {
                modelContext.delete(attachment)
            }
            for enrichment in try modelContext.fetch(FetchDescriptor<Enrichment>()) {
                modelContext.delete(enrichment)
            }
            for capture in try modelContext.fetch(FetchDescriptor<Capture>()) {
                modelContext.delete(capture)
            }
            try modelContext.save()
            try PersistenceService.removeStoredFiles()
            statusMessage = "All local data cleared."
        } catch {
            statusMessage = error.localizedDescription
        }
    }
}
