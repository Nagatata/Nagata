import Foundation
import Observation

/// ツールが何をしたかを画面に表示するための記録。
@MainActor
@Observable
final class ActivityLog {
    static let shared = ActivityLog()

    private(set) var latest: String?
    private var pending: [String] = []

    func add(_ line: String) {
        latest = line
        pending.append(line)
    }

    func drain() -> [String] {
        defer {
            pending.removeAll()
            latest = nil
        }
        return pending
    }

    /// ツール(メインスレッド以外)から呼ぶためのヘルパー
    nonisolated static func record(_ line: String) async {
        await MainActor.run { ActivityLog.shared.add(line) }
    }
}
