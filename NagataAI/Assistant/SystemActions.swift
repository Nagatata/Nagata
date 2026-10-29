import UIKit

enum SystemActions {
    /// URLを開く(電話・メッセージ・他のアプリ起動など)。
    /// 電話の発信などはiOSが確認画面を出すので、最終的な実行はユーザーが承認する。
    @MainActor
    static func open(_ url: URL) async -> Bool {
        await UIApplication.shared.open(url)
    }
}
