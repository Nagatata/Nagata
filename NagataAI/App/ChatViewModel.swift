import Foundation
import Observation

struct ChatMessage: Identifiable {
    enum Role { case user, assistant, system }
    let id = UUID()
    let role: Role
    let text: String
}

@MainActor
@Observable
final class ChatViewModel {
    var messages: [ChatMessage] = []
    var input = ""
    var isThinking = false
    var speakReplies = true

    private let assistant = Assistant.shared
    private let speaker = Speaker()

    var availabilityWarning: String? { assistant.availabilityWarning }

    func send() {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isThinking else { return }
        input = ""
        messages.append(.init(role: .user, text: text))
        isThinking = true

        Task {
            let reply = await assistant.ask(text)
            for line in ActivityLog.shared.drain() {
                messages.append(.init(role: .system, text: line))
            }
            messages.append(.init(role: .assistant, text: reply))
            isThinking = false
            if speakReplies { speaker.speak(reply) }
        }
    }

    func reset() {
        assistant.reset()
        speaker.stop()
        messages.removeAll()
    }

    func stopSpeaking() {
        speaker.stop()
    }
}
