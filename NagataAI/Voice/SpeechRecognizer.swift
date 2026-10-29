import AVFoundation
import Observation
import Speech

/// マイクの音声を日本語のテキストに変換する。
@MainActor
@Observable
final class SpeechRecognizer {
    private(set) var transcript = ""
    private(set) var isRecording = false

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "ja-JP"))
    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    func requestAuthorization() async -> Bool {
        let speechAllowed = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0 == .authorized) }
        }
        let micAllowed = await AVAudioApplication.requestRecordPermission()
        return speechAllowed && micAllowed
    }

    func start() throws {
        guard let recognizer, recognizer.isAvailable else {
            throw NSError(domain: "SpeechRecognizer", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "音声認識が利用できません"])
        }
        cleanUp()
        transcript = ""

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .measurement, options: [.duckOthers, .defaultToSpeaker])
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.addsPunctuation = true
        self.request = request

        let input = audioEngine.inputNode
        Self.installTap(on: input, request: request)
        audioEngine.prepare()
        try audioEngine.start()
        isRecording = true

        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            let text = result?.bestTranscription.formattedString
            let finished = error != nil || (result?.isFinal ?? false)
            Task { @MainActor in
                guard let self else { return }
                if let text { self.transcript = text }
                if finished { self.stop() }
            }
        }
    }

    func stop() {
        guard isRecording else { return }
        cleanUp()
        isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func cleanUp() {
        if audioEngine.isRunning { audioEngine.stop() }
        audioEngine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.cancel()
        request = nil
        task = nil
    }

    /// オーディオのタップはバックグラウンドスレッドで呼ばれるため、MainActorの外で設定する
    nonisolated private static func installTap(on input: AVAudioInputNode,
                                               request: SFSpeechAudioBufferRecognitionRequest) {
        let format = input.outputFormat(forBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }
    }
}
