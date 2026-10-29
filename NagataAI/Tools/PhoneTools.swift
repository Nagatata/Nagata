import Contacts
import Foundation
import FoundationModels

struct FindContactTool: Tool {
    let name = "findContact"
    let description = "名前で連絡先を検索して、電話番号を返す。電話やメッセージの相手の番号を調べるときに使う。"

    @Generable
    struct Arguments {
        @Guide(description: "探す人の名前(例: 田中、山田花子、お母さん)")
        var name: String
    }

    func call(arguments: Arguments) async throws -> String {
        let store = CNContactStore()
        guard (try? await store.requestAccess(for: .contacts)) == true else {
            return "連絡先へのアクセスが許可されていません。設定アプリで許可してください。"
        }
        await ActivityLog.record("👤 連絡先を検索: \(arguments.name)")

        let keys: [CNKeyDescriptor] = [
            CNContactFormatter.descriptorForRequiredKeys(for: .fullName),
            CNContactPhoneNumbersKey as CNKeyDescriptor,
            CNContactNicknameKey as CNKeyDescriptor,
        ]
        let predicate = CNContact.predicateForContacts(matchingName: arguments.name)
        let contacts = (try? store.unifiedContacts(matching: predicate, keysToFetch: keys)) ?? []
        guard !contacts.isEmpty else { return "「\(arguments.name)」に一致する連絡先は見つかりませんでした。" }

        return contacts.prefix(5).map { contact in
            let fullName = CNContactFormatter.string(from: contact, style: .fullName) ?? contact.nickname
            let numbers = contact.phoneNumbers.map { labeled in
                let label = labeled.label.map { CNLabeledValue<CNPhoneNumber>.localizedString(forLabel: $0) } ?? "電話"
                return "\(label): \(labeled.value.stringValue)"
            }
            return "\(fullName)\n" + (numbers.isEmpty ? "電話番号なし" : numbers.joined(separator: "\n"))
        }.joined(separator: "\n\n")
    }
}

struct PhoneCallTool: Tool {
    let name = "phoneCall"
    let description = "電話をかける。発信前にiPhoneが確認画面を表示する。番号が分からない場合は先に findContact を使う。"

    @Generable
    struct Arguments {
        @Guide(description: "電話番号(例: 09012345678、117)")
        var phoneNumber: String
        @Guide(description: "FaceTimeオーディオでかける場合はtrue")
        var useFaceTime: Bool
    }

    func call(arguments: Arguments) async throws -> String {
        let digits = PhoneNumber.sanitize(arguments.phoneNumber)
        guard !digits.isEmpty else { return "電話番号が正しくありません。" }
        let scheme = arguments.useFaceTime ? "facetime-audio" : "tel"
        guard let url = URL(string: "\(scheme):\(digits)") else { return "電話番号が正しくありません。" }

        await ActivityLog.record("📞 発信: \(digits)")
        let opened = await SystemActions.open(url)
        return opened ? "\(digits) への発信画面を表示しました。" : "電話をかけられませんでした。"
    }
}

struct SendMessageTool: Tool {
    let name = "sendMessage"
    let description = "メッセージアプリでSMS/iMessageの送信画面を、本文を入れた状態で開く。送信ボタンはユーザーが押す。"

    @Generable
    struct Arguments {
        @Guide(description: "宛先の電話番号またはメールアドレス")
        var recipient: String
        @Guide(description: "送るメッセージの本文")
        var body: String
    }

    func call(arguments: Arguments) async throws -> String {
        let recipient = arguments.recipient.contains("@")
            ? arguments.recipient.trimmingCharacters(in: .whitespaces)
            : PhoneNumber.sanitize(arguments.recipient)
        let body = arguments.body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        guard !recipient.isEmpty, let url = URL(string: "sms:\(recipient)&body=\(body)") else {
            return "宛先が正しくありません。"
        }
        await ActivityLog.record("💬 メッセージ作成: \(recipient)")
        let opened = await SystemActions.open(url)
        return opened ? "メッセージの送信画面を開きました。内容を確認して送信してください。" : "メッセージアプリを開けませんでした。"
    }
}

enum PhoneNumber {
    /// 数字と + * # だけを残す(全角数字も半角にする)
    static func sanitize(_ raw: String) -> String {
        let halfWidth = raw.applyingTransform(.fullwidthToHalfwidth, reverse: false) ?? raw
        return halfWidth.filter { $0.isASCII && ($0.isNumber || "+*#".contains($0)) }
    }
}
