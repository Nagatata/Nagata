import AppIntents

/// Siri・アクションボタン・ショートカットから「NagataAIに聞く」を使えるようにする。
struct AskAIIntent: AppIntent {
    static let title: LocalizedStringResource = "NagataAIに聞く"
    static let description = IntentDescription("NagataAIに質問やお願いをします。")
    // 電話や他アプリの起動はアプリが前面にないとできないため、実行時にアプリを開く
    static let openAppWhenRun = true

    @Parameter(title: "お願い", requestValueDialog: "何をしましょうか?")
    var request: String

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let reply = await Assistant.shared.ask(request)
        return .result(dialog: "\(reply)")
    }
}

struct NagataAIShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AskAIIntent(),
            phrases: [
                "\(.applicationName)に聞く",
                "\(.applicationName)にお願い",
                "Ask \(.applicationName)",
            ],
            shortTitle: "NagataAIに聞く",
            systemImageName: "sparkles"
        )
    }
}
