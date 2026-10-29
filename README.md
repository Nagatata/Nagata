# NagataAI — iPhoneの中で動くAIアシスタント

iPhoneに内蔵されたAppleのAIモデル(Foundation Models)で動く、日本語の音声アシスタントです。
AIの処理は端末内で行われるため、APIキーや利用料金は不要で、会話内容が外部に送られません
(ウェブ検索をするときだけ、検索キーワードがインターネットに送られます)。

## できること

| 機能 | 話しかけ方の例 | 仕組み |
|---|---|---|
| 調べ物 | 「明日の東京の天気を調べて」 | DuckDuckGo検索(失敗時はWikipedia)→ ページ本文を読んで要約 |
| 電話 | 「田中さんに電話して」 | 連絡先から番号を検索 → 発信(iPhoneの確認画面あり) |
| メッセージ | 「母に『今から帰る』と送って」 | メッセージアプリに本文を入れて開く(送信はご自身で) |
| アプリ操作 | 「渋谷駅を地図で出して」「YouTubeで猫の動画」 | URLスキームで各アプリを開く |
| 細かいアプリ操作 | 「『エアコンオン』のショートカットを実行して」 | ショートカットアプリを名前で実行 |
| 予定の追加 | 「来週月曜の15時に歯医者を入れて」 | カレンダーに直接登録 |
| 音声 | 🎤ボタンで話す / 返答を読み上げ | 日本語音声認識・読み上げ |
| Siri | 「Hey Siri、NagataAIに聞く」 | App Intents(アクションボタンにも割り当て可) |

## 必要なもの

- **Mac**と **Xcode 26** 以降
- **Apple Intelligence対応のiPhone**(iPhone 15 Pro / 16 / 17 シリーズ以降)、iOS 26以降
- iPhoneの「設定 → Apple Intelligence と Siri」をオン
- 無料のApple IDでも自分のiPhoneにインストールできます(7日ごとに再インストールが必要。有料のApple Developer Programなら1年)

## iPhoneへのインストール手順

```bash
brew install xcodegen          # 初回のみ
git clone https://github.com/Nagatata/Nagata.git
cd Nagata
xcodegen                       # NagataAI.xcodeproj を生成
open NagataAI.xcodeproj
```

1. Xcodeで左のプロジェクト「NagataAI」→ TARGETS「NagataAI」→「Signing & Capabilities」を開く
2. 「Team」で自分のApple IDを選ぶ(必要なら Bundle Identifier を他と重ならない名前に変更)
3. iPhoneをケーブルで接続し、上部の実行先で自分のiPhoneを選んで ▶︎ を押す
4. 初回はiPhoneの「設定 → 一般 → VPNとデバイス管理」で開発者を信頼し、「設定 → プライバシーとセキュリティ → デベロッパモード」をオンにする

## 他のアプリを細かく操作するには(ショートカット連携)

iOSでは、アプリが他のアプリの画面を直接操作することはできません。代わりに **ショートカットアプリ** を使います。

1. ショートカットアプリで、やりたい操作(例: 「エアコンオン」「PayPayを開いてスキャン」「今日の歩数を読む」)を作る
2. NagataAIに「エアコンオンのショートカットを実行して」と頼む

ショートカットの入力として、NagataAIが文章を渡すこともできます(「ショートカットの入力を受け取る」アクションで受け取れます)。

## iOSの制約について

- **電話の発信・メッセージの送信は、必ず最後にご自身の確認が必要です。** iOSの安全上の仕様で、アプリが勝手に発信・送信することはできません。
- 内蔵モデルは小型のため、一度に扱える会話の長さが短めです。長くなると自動で新しい会話に切り替わります。右上の「新規」でもリセットできます。
- 天気・ニュースなどはウェブ検索の結果をもとに答えるため、検索サイトの仕様変更で精度が変わることがあります。

## ファイル構成

```
project.yml                     XcodeGenのプロジェクト定義(権限の説明文もここ)
NagataAI/
  App/                          画面(チャットUI)
  Assistant/Assistant.swift     AIモデルとの会話・使えるツールの登録
  Tools/WebTools.swift          ウェブ検索・ページ読み込み
  Tools/PhoneTools.swift        連絡先検索・電話・メッセージ
  Tools/AppTools.swift          アプリ起動・ショートカット実行・カレンダー
  Voice/                        音声認識・読み上げ
  Intents/AskAIIntent.swift     Siri・アクションボタン連携
```

新しい機能を足すときは、`Tools/` に `Tool` を作って `Assistant.swift` の `tools:` に追加するだけです。
