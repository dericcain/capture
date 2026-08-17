import PhotosUI
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct CaptureView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Capture.createdAt, order: .reverse) private var captures: [Capture]
    @StateObject private var audioRecorder = AudioRecorder()
    @State private var showTextSheet = false
    @State private var textEntry = ""
    @State private var showAttachmentOptions = false
    @State private var showFileImporter = false
    @State private var showPhotoPicker = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var importError: String?
    @State private var recordingStartRequested = false

    private var recentCaptures: [Capture] {
        Array(captures.prefix(5))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(audioRecorder.isRecording ? Color.red.gradient : Color.accentColor.gradient)
                            .frame(width: 180, height: 180)
                            .shadow(color: audioRecorder.isRecording ? Color.red.opacity(0.35) : Color.accentColor.opacity(0.25), radius: 16)

                        Image(systemName: audioRecorder.isRecording ? "waveform.circle.fill" : "mic.fill")
                            .font(.system(size: 60, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .contentShape(Circle())
                    .gesture(recordGesture)

                    Text("Hold to Capture")
                        .font(.title2.weight(.semibold))

                    if audioRecorder.isRecording {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(.red)
                                .frame(width: 10, height: 10)
                            Text("Recording… release to save")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Text("Voice, text, photos, files, and URLs are all captured here.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.top, 20)

                HStack {
                    Button {
                        showAttachmentOptions = true
                    } label: {
                        Label("+ Attach", systemImage: "paperclip")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    Button {
                        showTextSheet = true
                    } label: {
                        Label("⌨ Type", systemImage: "keyboard")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Recent")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if recentCaptures.isEmpty {
                        ContentUnavailableView("No captures yet", systemImage: "tray")
                    } else {
                        ForEach(recentCaptures) { capture in
                            NavigationLink {
                                CaptureDetailView(capture: capture)
                            } label: {
                                CaptureRowView(capture: capture, enrichment: nil)
                            }
                            .buttonStyle(.plain)

                            if capture.id != recentCaptures.last?.id {
                                Divider()
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Capture")
        .sheet(isPresented: $showTextSheet) {
            NavigationStack {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Quick note")
                        .font(.title3.weight(.semibold))
                    TextField("Type anything you want to remember", text: $textEntry, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(6...12)
                    Spacer()
                }
                .padding()
                .navigationTitle("Text Capture")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            textEntry = ""
                            showTextSheet = false
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            saveTextCapture()
                        }
                        .disabled(textEntry.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
            .presentationDetents([.medium])
        }
        .confirmationDialog("Add attachment", isPresented: $showAttachmentOptions, titleVisibility: .visible) {
            Button("Choose Photo") {
                showPhotoPicker = true
            }
            Button("Choose File") {
                showFileImporter = true
            }
            Button("Cancel", role: .cancel) {}
        }
        .photosPicker(isPresented: $showPhotoPicker, selection: $selectedPhoto, matching: .images)
        .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.item], allowsMultipleSelection: false) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                Task { await importFile(url) }
            case .failure(let error):
                importError = error.localizedDescription
            }
        }
        .alert("Capture Error", isPresented: Binding(get: { importError != nil }, set: { if !$0 { importError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importError ?? "Unknown error")
        }
        .onChange(of: selectedPhoto) { _, item in
            guard let item else { return }
            Task {
                await importPhoto(item)
                selectedPhoto = nil
            }
        }
    }

    private var recordGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { _ in
                guard !audioRecorder.isRecording, !audioRecorder.isStarting, !recordingStartRequested else { return }
                recordingStartRequested = true
                Task {
                    await audioRecorder.startRecording()
                    recordingStartRequested = false
                }
            }
            .onEnded { _ in
                Task {
                    if !audioRecorder.isRecording {
                        audioRecorder.cancelPendingRecordingStart()
                    }
                    await finishRecording()
                    recordingStartRequested = false
                }
            }
    }

    @MainActor
    private func finishRecording() async {
        guard let url = audioRecorder.stopRecording() else {
            if let errorMessage = audioRecorder.errorMessage {
                importError = errorMessage
            }
            return
        }

        let attachment = Attachment(captureId: UUID(), type: .file, filename: url.lastPathComponent, localPath: url.path)
        let capture = Capture(source: .voice, attachments: [attachment])
        attachment.captureId = capture.id
        save(capture)
    }

    private func saveTextCapture() {
        let trimmed = textEntry.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let capture = Capture(source: .text, rawText: trimmed)
        save(capture)
        textEntry = ""
        showTextSheet = false
    }

    @MainActor
    private func importPhoto(_ item: PhotosPickerItem) async {
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                importError = "Photo data was empty."
                return
            }
            let filename = "photo-\(UUID().uuidString).jpg"
            let url = try PersistenceService.saveDataToDocuments(data, filename: filename, subdirectory: "Photos")
            let attachment = Attachment(captureId: UUID(), type: .image, filename: filename, localPath: url.path, thumbnailData: data)
            let capture = Capture(source: .photo, rawText: filename, attachments: [attachment])
            attachment.captureId = capture.id
            save(capture)
        } catch {
            importError = error.localizedDescription
        }
    }

    @MainActor
    private func importFile(_ sourceURL: URL) async {
        do {
            let savedURL = try PersistenceService.copyFileToDocuments(from: sourceURL, subdirectory: "Files")
            let attachment = Attachment(captureId: UUID(), type: .file, filename: savedURL.lastPathComponent, localPath: savedURL.path)
            let capture = Capture(source: .file, rawText: savedURL.lastPathComponent, attachments: [attachment])
            attachment.captureId = capture.id
            save(capture)
        } catch {
            importError = error.localizedDescription
        }
    }

    @MainActor
    private func save(_ capture: Capture) {
        modelContext.insert(capture)
        do {
            try modelContext.save()
            Task {
                await BackgroundProcessor.shared.enqueueProcessing(for: capture.id)
            }
        } catch {
            modelContext.delete(capture)
            importError = error.localizedDescription
        }
    }
}
