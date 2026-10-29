import AVFoundation

/// アシスタントの返答を日本語で読み上げる。
@MainActor
final class Speaker {
    private let synthesizer = AVSpeechSynthesizer()

    func speak(_ text: String) {
        stop()
        // 読み上げに向かないマークダウン記号やURLを取り除く
        let spoken = text
            .replacing(#/https?://\S+/#, with: "")
            .replacing(#/[*#`_>]/#, with: "")
        let utterance = AVSpeechUtterance(string: spoken)
        utterance.voice = AVSpeechSynthesisVoice(language: "ja-JP")
        synthesizer.speak(utterance)
    }

    func stop() {
        if synthesizer.isSpeaking { synthesizer.stopSpeaking(at: .immediate) }
    }
}
