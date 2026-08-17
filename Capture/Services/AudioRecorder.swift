import AVFoundation
import Foundation

@MainActor
final class AudioRecorder: NSObject, ObservableObject {
    @Published private(set) var isRecording = false
    @Published private(set) var errorMessage: String?

    private var recorder: AVAudioRecorder?

    func startRecording() async {
        guard !isRecording else { return }
        do {
            let allowed = await requestPermission()
            guard allowed else {
                errorMessage = "Microphone permission was denied."
                return
            }

            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)

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
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func stopRecording() -> URL? {
        guard let recorder else { return nil }
        recorder.stop()
        self.recorder = nil
        isRecording = false
        do {
            try AVAudioSession.sharedInstance().setActive(false)
        } catch {
            errorMessage = error.localizedDescription
        }
        return recorder.url
    }

    private func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }
}
