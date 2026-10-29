import SwiftUI

struct ContentView: View {
    @State private var model = ChatViewModel()
    @State private var speech = SpeechRecognizer()
    @FocusState private var inputFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let warning = model.availabilityWarning {
                    Text(warning)
                        .font(.footnote)
                        .padding(10)
                        .frame(maxWidth: .infinity)
                        .background(.yellow.opacity(0.25))
                }
                messageList
                inputBar
            }
            .navigationTitle("NagataAI")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        model.speakReplies.toggle()
                    } label: {
                        Image(systemName: model.speakReplies ? "speaker.wave.2.fill" : "speaker.slash")
                    }
                    .accessibilityLabel("返答の読み上げ")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("新規") { model.reset() }
                }
            }
        }
        .onChange(of: speech.isRecording) { wasRecording, isRecording in
            // 録音が止まったら、聞き取った内容をそのまま送信する
            if wasRecording && !isRecording && !speech.transcript.isEmpty {
                model.input = speech.transcript
                model.send()
            }
        }
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(model.messages) { message in
                        MessageRow(message: message)
                            .id(message.id)
                    }
                    if model.isThinking {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text(ActivityLog.shared.latest ?? "考え中…")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .id("thinking")
                    }
                }
                .padding()
            }
            .onChange(of: model.messages.count) {
                withAnimation { proxy.scrollTo(model.messages.last?.id, anchor: .bottom) }
            }
        }
    }

    private var inputBar: some View {
        HStack(spacing: 8) {
            Button {
                Task { await toggleRecording() }
            } label: {
                Image(systemName: speech.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(speech.isRecording ? .red : .accentColor)
            }
            .accessibilityLabel(speech.isRecording ? "録音を止める" : "音声で話す")

            TextField(speech.isRecording ? speech.transcript : "何でも聞いてください",
                      text: $model.input, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...4)
                .focused($inputFocused)
                .onSubmit { model.send() }

            Button {
                inputFocused = false
                model.send()
            } label: {
                Image(systemName: "arrow.up.circle.fill").font(.system(size: 32))
            }
            .disabled(model.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.isThinking)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.bar)
    }

    private func toggleRecording() async {
        if speech.isRecording {
            speech.stop()
            return
        }
        guard await speech.requestAuthorization() else {
            model.messages.append(.init(role: .system, text: "マイクと音声認識の許可が必要です。設定アプリから許可してください。"))
            return
        }
        model.stopSpeaking()
        do {
            try speech.start()
        } catch {
            model.messages.append(.init(role: .system, text: "録音を開始できませんでした: \(error.localizedDescription)"))
        }
    }
}

private struct MessageRow: View {
    let message: ChatMessage

    var body: some View {
        switch message.role {
        case .user:
            HStack {
                Spacer(minLength: 40)
                Text(message.text)
                    .padding(10)
                    .background(Color.accentColor, in: .rect(cornerRadius: 14))
                    .foregroundStyle(.white)
            }
        case .assistant:
            HStack {
                Text((try? AttributedString(markdown: message.text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(message.text))
                    .textSelection(.enabled)
                    .padding(10)
                    .background(Color(.secondarySystemBackground), in: .rect(cornerRadius: 14))
                Spacer(minLength: 40)
            }
        case .system:
            Text(message.text)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
        }
    }
}
