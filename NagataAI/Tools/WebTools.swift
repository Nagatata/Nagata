import Foundation
import FoundationModels

/// オンデバイスモデルは扱える文章量が少ないので、ツールの結果は短く切り詰めて返す。
private let maxResultLength = 1500

struct WebSearchTool: Tool {
    let name = "webSearch"
    let description = "インターネットを検索して、検索結果のタイトル・URL・要約を返す。最新情報や知らないことを調べるときに使う。"

    @Generable
    struct Arguments {
        @Guide(description: "検索キーワード")
        var query: String
    }

    func call(arguments: Arguments) async throws -> String {
        await ActivityLog.record("🔍 検索: \(arguments.query)")
        var results = (try? await duckDuckGo(arguments.query)) ?? []
        if results.isEmpty {
            results = (try? await wikipedia(arguments.query)) ?? []
        }
        guard !results.isEmpty else { return "検索結果が見つかりませんでした。" }
        return String(results.prefix(5).enumerated().map { i, r in
            "\(i + 1). \(r.title)\n\(r.url)\n\(r.snippet)"
        }.joined(separator: "\n\n").prefix(maxResultLength))
    }

    private struct Result {
        let title: String
        let url: String
        let snippet: String
    }

    private func duckDuckGo(_ query: String) async throws -> [Result] {
        var components = URLComponents(string: "https://html.duckduckgo.com/html/")!
        components.queryItems = [.init(name: "q", value: query), .init(name: "kl", value: "jp-jp")]
        let html = try await HTTP.getText(components.url!)

        let linkPattern = #/<a[^>]*class="result__a"[^>]*href="([^"]+)"[^>]*>(.*?)</a>/#
        let snippetPattern = #/<a[^>]*class="result__snippet"[^>]*>(.*?)</a>/#
        let links = html.matches(of: linkPattern)
        let snippets = html.matches(of: snippetPattern)

        return links.enumerated().map { i, match in
            let snippet = i < snippets.count ? HTML.plainText(String(snippets[i].1)) : ""
            return Result(title: HTML.plainText(String(match.2)),
                          url: resolveDuckDuckGoLink(String(match.1)),
                          snippet: snippet)
        }
    }

    /// DuckDuckGoのリダイレクトURL(//duckduckgo.com/l/?uddg=...)から本来のURLを取り出す
    private func resolveDuckDuckGoLink(_ href: String) -> String {
        let decoded = href.replacingOccurrences(of: "&amp;", with: "&")
        guard let components = URLComponents(string: decoded.hasPrefix("//") ? "https:" + decoded : decoded),
              let target = components.queryItems?.first(where: { $0.name == "uddg" })?.value
        else { return decoded }
        return target
    }

    private func wikipedia(_ query: String) async throws -> [Result] {
        var components = URLComponents(string: "https://ja.wikipedia.org/w/api.php")!
        components.queryItems = [
            .init(name: "action", value: "query"),
            .init(name: "list", value: "search"),
            .init(name: "srsearch", value: query),
            .init(name: "srlimit", value: "5"),
            .init(name: "format", value: "json"),
        ]
        struct Response: Decodable {
            struct Query: Decodable { let search: [Item] }
            struct Item: Decodable { let title: String; let snippet: String }
            let query: Query
        }
        let data = try await HTTP.get(components.url!)
        let response = try JSONDecoder().decode(Response.self, from: data)
        return response.query.search.map { item in
            let path = item.title.replacingOccurrences(of: " ", with: "_")
                .addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? item.title
            return Result(title: item.title + "(Wikipedia)",
                          url: "https://ja.wikipedia.org/wiki/\(path)",
                          snippet: HTML.plainText(item.snippet))
        }
    }
}

struct FetchWebPageTool: Tool {
    let name = "fetchWebPage"
    let description = "指定したURLのウェブページを読み込み、本文のテキストを返す。検索結果を詳しく確認するときに使う。"

    @Generable
    struct Arguments {
        @Guide(description: "読み込むページのURL(https://で始まる)")
        var url: String
    }

    func call(arguments: Arguments) async throws -> String {
        guard let url = URL(string: arguments.url), url.scheme?.hasPrefix("http") == true else {
            return "URLが正しくありません。"
        }
        await ActivityLog.record("🌐 ページを読み込み: \(url.host() ?? arguments.url)")
        do {
            let html = try await HTTP.getText(url)
            let text = HTML.plainText(HTML.removeNonContent(html))
            return text.isEmpty ? "本文を取得できませんでした。" : String(text.prefix(maxResultLength))
        } catch {
            return "ページを読み込めませんでした: \(error.localizedDescription)"
        }
    }
}

enum HTTP {
    static func get(_ url: URL) async throws -> Data {
        var request = URLRequest(url: url, timeoutInterval: 15)
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 26_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148",
                         forHTTPHeaderField: "User-Agent")
        request.setValue("ja,en;q=0.8", forHTTPHeaderField: "Accept-Language")
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }
        return data
    }

    static func getText(_ url: URL) async throws -> String {
        let data = try await get(url)
        return String(data: data, encoding: .utf8)
            ?? String(data: data, encoding: .shiftJIS)
            ?? String(decoding: data, as: UTF8.self)
    }
}

enum HTML {
    static func removeNonContent(_ html: String) -> String {
        var result = html
        for tag in ["script", "style", "noscript", "svg", "nav", "header", "footer", "aside"] {
            if let regex = try? Regex("(?is)<\(tag)\\b.*?</\(tag)>") {
                result = result.replacing(regex, with: " ")
            }
        }
        return result
    }

    static func plainText(_ html: String) -> String {
        html
            .replacing(#/(?s)<[^>]+>/#, with: " ")
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&#x27;", with: "'")
            .replacing(#/\s+/#, with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
