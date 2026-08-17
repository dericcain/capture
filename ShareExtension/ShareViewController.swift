import SwiftData
import UIKit
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {
    private let statusLabel = UILabel()
    private let spinner = UIActivityIndicatorView(style: .large)
    private var hasProcessedInput = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.startAnimating()

        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.font = .preferredFont(forTextStyle: .headline)
        statusLabel.textAlignment = .center
        statusLabel.text = "Saving…"
        statusLabel.numberOfLines = 0

        view.addSubview(spinner)
        view.addSubview(statusLabel)

        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -20),
            statusLabel.topAnchor.constraint(equalTo: spinner.bottomAnchor, constant: 16),
            statusLabel.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            statusLabel.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor)
        ])
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !hasProcessedInput else { return }
        hasProcessedInput = true
        Task { await handleInput() }
    }

    @MainActor
    private func handleInput() async {
        guard let item = extensionContext?.inputItems.first as? NSExtensionItem,
              let attachments = item.attachments,
              !attachments.isEmpty else {
            finish(with: "Nothing to save.")
            return
        }

        do {
            if let provider = attachments.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.url.identifier) }) {
                let url = try await loadURL(from: provider)
                try saveCapture(source: .url, rawText: url.absoluteString, attachment: Attachment(captureId: UUID(), type: .url, filename: url.host ?? url.absoluteString, url: url.absoluteString))
                finish(with: "Saved!")
                return
            }

            if let provider = attachments.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) || $0.hasItemConformingToTypeIdentifier(UTType.text.identifier) }) {
                let text = try await loadText(from: provider)
                try saveCapture(source: .text, rawText: text, attachment: nil)
                finish(with: "Saved!")
                return
            }

            finish(with: "Unsupported item.")
        } catch {
            finish(with: error.localizedDescription)
        }
    }

    private func saveCapture(source: CaptureSource, rawText: String, attachment: Attachment?) throws {
        let schema = Schema([Capture.self, Enrichment.self, Attachment.self])
        let storeURL = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: PersistenceService.appGroupIdentifier)?
            .appending(path: "capture.store")
            ?? URL.documentsDirectory.appending(path: "capture.store")
        let config = ModelConfiguration(schema: schema, url: storeURL)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)
        let capture = Capture(source: source, rawText: rawText, attachments: attachment.map { [$0] } ?? [])
        attachment?.captureId = capture.id
        context.insert(capture)
        try context.save()
    }

    private func loadURL(from provider: NSItemProvider) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { item, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let url = item as? URL {
                    continuation.resume(returning: url)
                } else if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                    continuation.resume(returning: url)
                } else {
                    continuation.resume(throwing: ShareError.invalidItem)
                }
            }
        }
    }

    private func loadText(from provider: NSItemProvider) async throws -> String {
        let typeIdentifier = provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier)
            ? UTType.plainText.identifier
            : UTType.text.identifier
        try await withCheckedThrowingContinuation { continuation in
            provider.loadItem(forTypeIdentifier: typeIdentifier, options: nil) { item, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let text = item as? String {
                    continuation.resume(returning: text)
                } else if let attributed = item as? NSAttributedString {
                    continuation.resume(returning: attributed.string)
                } else {
                    continuation.resume(throwing: ShareError.invalidItem)
                }
            }
        }
    }

    @MainActor
    private func finish(with message: String) {
        spinner.stopAnimating()
        statusLabel.text = message
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            self.extensionContext?.completeRequest(returningItems: nil)
        }
    }
}

private enum ShareError: LocalizedError {
    case invalidItem

    var errorDescription: String? {
        switch self {
        case .invalidItem:
            "The shared item could not be read."
        }
    }
}
