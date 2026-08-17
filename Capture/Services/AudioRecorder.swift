import AVFoundation
import Foundation

@MainActor
final class AudioRecorder: NSObject, ObservableObject {
    @Published private(set) var isRecording = false
    @Published private(set) var errorMessage: String?

    private var recorder: AVAudioRecorder?
    private(set) var isStarting = false
    private var cancelPendingStart = false

    func cancelPendingRecordingStart() {
        cancelPendingStart = true
        errorMessage = nil
    }

    func startRecording() async {
        guard !isRecording, !isStarting else { return }
        isStarting = true

        do {
            let allowed = await requestPermission()
            guard allowed else {
                isStarting = false
                errorMessage = "Microphone permission was denied."
                return
            }

            guard !cancelPendingStart else {
                isStarting = false
                cancelPendingStart = false
                errorMessage = nil
                return
            }

            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)

            guard !cancelPendingStart else {
                try? session.setActive(false)
                isStarting = false
                cancelPendingStart = false
                errorMessage = nil
                return
            }

            let url = try PersistenceService.makeUniqueDocumentURL(filename: "voice-\(UUID().uuidString).m4a", subdirectory: "Recordings")
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44_100,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]

            recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder?.prepareToRecord()
            recorder?.record()
            errorMessage = nil
            isRecording = true
            isStarting = false
            cancelPendingStart = false
        } catch {
            isStarting = false
            cancelPendingStart = false
            errorMessage = error.localizedDescription
        }
    }

    func stopRecording() -> URL? {
        guard let recorder else {
            if isStarting {
                cancelPendingStart = true
            }
            return nil
        }
        recorder.stop()
        self.recorder = nil
        isRecording = false
        isStarting = false
        cancelPendingStart = false
        do {
            try AVAudioSession.sharedInstance().setActive(false)
        } catch {
            errorMessage = error.localizedDescription
        }
        return recorder.url
    }

    private func requestPermission() async -> Bool {
        if #available(iOS 17.0, *) {
            return await AVAudioApplication.requestRecordPermission()
        } else {
            return await withCheckedContinuation { continuation in
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
        }
    }
}
