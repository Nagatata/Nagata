import Foundation
import FoundationModels

/// iPhone内蔵のAppleのオンデバイスモデル(Foundation Models)で動くアシスタント。
/// 会話の中でモデルが必要と判断したときに、検索・電話・アプリ操作などのツールを呼び出す。
@MainActor
final class Assistant {
    static let shared = Assistant()

    private var session: LanguageModelSession

    private init() {
        session = Assistant.makeSession()
    }

    var availabilityWarning: String? {
        switch SystemLanguageModel.default.availability {
        case .available:
            return nil
        case .unavailable(.deviceNotEligible):
            return "この端末はApple Intelligenceに対応していないため、AIを利用できません(iPhone 15 Pro以降が必要です)。"
        case .unavailable(.appleIntelligenceNotEnabled):
            return "設定アプリで「Apple Intelligence と Siri」をオンにしてください。"
        case .unavailable(.modelNotReady):
            return "AIモデルを準備中です。Wi-Fiに接続してしばらくお待ちください。"
        case .unavailable:
            return "現在AIを利用できません。"
        }
    }

    func ask(_ prompt: String) async -> String {
        if let warning = availabilityWarning { return warning }
        do {
            return try await session.respond(to: prompt).content
        } catch LanguageModelSession.GenerationError.exceededContextWindowSize {
            // オンデバイスモデルは記憶できる会話の長さが短いので、溢れたら新しい会話で再試行する
            reset()
            do {
                return try await session.respond(to: prompt).content
            } catch {
                return "エラーが発生しました: \(error.localizedDescription)"
            }
        } catch LanguageModelSession.GenerationError.guardrailViolation {
            return "その内容にはお答えできません。"
        } catch {
            return "エラーが発生しました: \(error.localizedDescription)"
        }
    }

    func reset() {
        session = Assistant.makeSession()
    }

    private static func makeSession() -> LanguageModelSession {
        let now = Date.now.formatted(.dateTime.year().month().day().weekday(.wide).hour().minute()
            .locale(Locale(identifier: "ja_JP")))
        let instructions = """
        あなたはiPhoneの中で動く、日本語の個人アシスタント「NagataAI」です。
        現在の日時は \(now) です。
        - 最新の情報や知らないことは webSearch で調べ、必要なら fetchWebPage で詳しく読んでから答えてください。
        - 電話をかける・メッセージを送る前に、相手の番号が分からなければ findContact で連絡先を探してください。
        - アプリを開く・地図で場所を探すときは openApp を使ってください。
        - 他のアプリでの複雑な操作は、ユーザーが作ったショートカットを runShortcut で実行してください。
        - 予定の追加は addCalendarEvent を使ってください。
        - 答えは短く、話し言葉で分かりやすく。調べた情報は出典のサイト名も添えてください。
        """
        return LanguageModelSession(
            tools: [
                WebSearchTool(),
                FetchWebPageTool(),
                FindContactTool(),
                PhoneCallTool(),
                SendMessageTool(),
                OpenAppTool(),
                RunShortcutTool(),
                AddCalendarEventTool(),
            ],
            instructions: instructions
        )
    }
}
