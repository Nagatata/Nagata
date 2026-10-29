import EventKit
import Foundation
import FoundationModels

struct OpenAppTool: Tool {
    let name = "openApp"
    let description = """
    iPhoneのアプリを開く。対応: maps(地図・経路・場所検索), safari(URLやウェブ検索), mail(メール作成), \
    music, youtube, line, x, instagram, calendar, reminders, notes, photos, appstore, settings, shortcuts, clock。
    """

    @Generable
    struct Arguments {
        @Guide(description: "開くアプリ", .anyOf(["maps", "safari", "mail", "music", "youtube", "line", "x", "instagram",
                                                  "calendar", "reminders", "notes", "photos", "appstore", "settings",
                                                  "shortcuts", "clock"]))
        var app: String
        @Guide(description: "地図の検索場所・目的地、検索語、URL、メールアドレスなど。不要なら空文字")
        var query: String
    }

    func call(arguments: Arguments) async throws -> String {
        guard let url = Self.url(app: arguments.app, query: arguments.query) else {
            return "「\(arguments.app)」は開けません。"
        }
        await ActivityLog.record("📱 アプリを開く: \(arguments.app)\(arguments.query.isEmpty ? "" : "(\(arguments.query))")")
        let opened = await SystemActions.open(url)
        return opened ? "\(arguments.app) を開きました。" : "\(arguments.app) を開けませんでした。インストールされていない可能性があります。"
    }

    static func url(app: String, query: String) -> URL? {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let encoded = q.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let string: String
        switch app.lowercased() {
        case "maps": string = q.isEmpty ? "maps://" : "maps://?q=\(encoded)"
        case "safari":
            if q.hasPrefix("http://") || q.hasPrefix("https://") { string = q }
            else { string = "https://www.google.com/search?q=\(encoded)" }
        case "mail": string = "mailto:\(q)"
        case "music": string = q.isEmpty ? "music://" : "music://music.apple.com/search?term=\(encoded)"
        case "youtube": string = q.isEmpty ? "youtube://" : "youtube://results?search_query=\(encoded)"
        case "line": string = "line://"
        case "x": string = "twitter://"
        case "instagram": string = "instagram://"
        case "calendar": string = "calshow://"
        case "reminders": string = "x-apple-reminderkit://"
        case "notes": string = "mobilenotes://"
        case "photos": string = "photos-redirect://"
        case "appstore": string = q.isEmpty ? "itms-apps://" : "itms-apps://search.itunes.apple.com/WebObjects/MZSearch.woa/wa/search?media=software&term=\(encoded)"
        case "settings": string = "App-prefs:"
        case "shortcuts": string = "shortcuts://"
        case "clock": string = "clock-alarm://"
        default: return nil
        }
        return URL(string: string)
    }
}

struct RunShortcutTool: Tool {
    let name = "runShortcut"
    let description = """
    ショートカットアプリに登録されたショートカットを名前で実行する。\
    他のアプリでの細かい操作(家電の操作、送金アプリ、特定アプリの機能など)はこれで行う。
    """

    @Generable
    struct Arguments {
        @Guide(description: "実行するショートカットの名前(ショートカットアプリでの名前と完全に一致させる)")
        var name: String
        @Guide(description: "ショートカットに渡すテキスト入力。不要なら空文字")
        var input: String
    }

    func call(arguments: Arguments) async throws -> String {
        var components = URLComponents(string: "shortcuts://run-shortcut")!
        components.queryItems = [.init(name: "name", value: arguments.name)]
        if !arguments.input.isEmpty {
            components.queryItems? += [.init(name: "input", value: "text"), .init(name: "text", value: arguments.input)]
        }
        guard let url = components.url else { return "ショートカット名が正しくありません。" }
        await ActivityLog.record("⚡️ ショートカット実行: \(arguments.name)")
        let opened = await SystemActions.open(url)
        return opened ? "ショートカット「\(arguments.name)」を実行しました。" : "ショートカットを実行できませんでした。"
    }
}

struct AddCalendarEventTool: Tool {
    let name = "addCalendarEvent"
    let description = "カレンダーに予定を追加する。"

    @Generable
    struct Arguments {
        @Guide(description: "予定のタイトル")
        var title: String
        @Guide(description: "開始日時。形式は yyyy-MM-dd HH:mm(例: 2026-11-03 14:00)")
        var start: String
        @Guide(description: "予定の長さ(分)。分からなければ60", .range(5...1440))
        var durationMinutes: Int
        @Guide(description: "場所。不要なら空文字")
        var location: String
    }

    func call(arguments: Arguments) async throws -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        guard let start = formatter.date(from: arguments.start.trimmingCharacters(in: .whitespaces)) else {
            return "日時の形式が正しくありません。yyyy-MM-dd HH:mm で指定してください。"
        }

        let store = EKEventStore()
        guard (try? await store.requestWriteOnlyAccessToEvents()) == true else {
            return "カレンダーへのアクセスが許可されていません。設定アプリで許可してください。"
        }

        let event = EKEvent(eventStore: store)
        event.title = arguments.title
        event.startDate = start
        event.endDate = start.addingTimeInterval(TimeInterval(arguments.durationMinutes * 60))
        if !arguments.location.isEmpty { event.location = arguments.location }
        event.calendar = store.defaultCalendarForNewEvents
        do {
            try store.save(event, span: .thisEvent)
        } catch {
            return "予定を保存できませんでした: \(error.localizedDescription)"
        }
        let when = start.formatted(.dateTime.month().day().weekday().hour().minute().locale(Locale(identifier: "ja_JP")))
        await ActivityLog.record("📅 予定を追加: \(arguments.title)(\(when))")
        return "「\(arguments.title)」を \(when) に追加しました。"
    }
}
