# Watch Alarm — iPhone + watchOS companion

## 実装結果と重要な制約

既存 `watch-alarm.html` と `apple-touch-icon.png` は変更しません。新規 `native/` のみを追加します。Safari/PWAの `localStorage`、時計アプリ、既存ショートカットの設定にはアクセスしません。

**羽田チャイムをApple Watchのローカル通知音に指定する、という部分はwatchOSの公開APIでは実現できません。** 実際にXcode 27.1のwatchOS 27 SDKで `UNNotificationSound(named:)` をコンパイルすると `unavailable in watchOS` になります。SDKの `UserNotifications.framework/Headers/UNNotificationSound.h` にも `soundNamed: ... API_UNAVAILABLE(watchos, tvos)` と明記されています。30秒未満の条件だけではこの制約を解消できません。

このプロジェクトが行うこと:

- iPhoneで既存HTMLの設定一覧JSONを貼り付け／ファイルから取り込み、内容を検証して件数を確認してから保存。
- OFF・同一時刻の設定を含む全件と、取り込み元のJSONを保持。保存後はJSON共有によるバックアップも可能。
- WatchConnectivityで最新の全件スナップショットを転送。通常は `updateApplicationContext`、大きなJSONは `transferFile`。到着順が逆でも古い設定で上書きしません。
- Watch自身でローカル通知を予約。通知は **標準音**。iPhoneが近くになくても、既に予約された通知の配信をOSが管理します。
- 元のCAFを両アプリに同梱するためのChimeAssetsフォルダと、iPhoneからCAFをWatchに転送する機能。WatchでのCAF再生は **アプリを開いている間の手動試聴のみ**。

このプロジェクトが行わないこと:

- Watchの標準時計アラーム音の変更、バックグラウンドでの任意CAF自動再生、30秒ごとの無期限再生。
- 消音・集中モードを無視すること、強制終了中に予約を無制限に補充すること。
- 利用者のブラウザにだけ保存されている78件を、GitHubから自動取得すること。

## 元音源の状態

指定された `/mnt/data/羽田空港チャイム_AppleWatch通知用_28秒.caf` は今回の環境に存在せず、参照会話の取得結果にも添付ファイルがありませんでした。**元音源は未収録**です。代替音源は生成していません。

音源を入手したら、次のいずれかで追加できます。

1. ファイル名を `Haneda28.caf` にして `native/ChimeAssets/` に配置し、再ビルド。ChimeAssetsフォルダは両ターゲットに含まれます。初回起動時にLibrary/Soundsへコピー・検証します。
2. インストール後にiPhoneアプリの「元のCAFを選んでWatchへ転送」で元ファイルを選択。名前は元の日本語名のままで構いません。

どちらも30秒未満、Linear PCM CAF、10MB以下であることを検証します。音源の実ファイルがないため、28秒という長さや実音の再生は今回検証していません。試聴用音源があっても、Watchの通知音は標準音です。

## Xcodeで開く・実機へインストール

必要: Mac、Xcode（検証環境27.1）、iOS 17以降のiPhone、watchOS 10以降のApple Watch（Ultra 2を含む）、Apple Accountと署名設定。対象OSに対応したXcodeを使ってください。

1. このブランチを取得して `native/WatchAlarm.xcodeproj` を開く。外部パッケージ、CocoaPods、XcodeGenは不要。
2. `WatchAlarm` と `WatchAlarmWatch` の両ターゲットで Signing & Capabilities → Team を自分の開発チームに指定し、Automatically manage signingを有効化。
3. Bundle Identifierを変更する場合、iPhoneは `jp.isobem.watchalarm`、Watchは `jp.isobem.watchalarm.watchkitapp` を一組として変更。Watch側の `WKCompanionAppBundleIdentifier` もiPhoneのIDと一致させる。
4. iPhoneとUltra 2をペアリングして、Xcodeに実機を認識させる。必要に応じて両端末でデベロッパモードを有効化。
5. `WatchAlarm` スキームでiPhoneを選択してRun。WatchアプリはiPhoneアプリに埋め込み済み。Watchアプリのインストール状況をiPhoneのWatchアプリで確認する。必要なら `WatchAlarmWatch` スキームでペアリング済みUltra 2を選んでRun。
6. WatchでWatch Alarmを一度開き、「通知を許可」を押す。通知許可の要求はWatch側だけで行い、iPhoneから重複通知を予約しません。

**実機へのインストールにはXcodeと適切な署名・プロビジョニングが必要です。** GitHub保存や署名なしビルドだけではUltra 2にインストールされません。個人用無料署名では有効期限や再署名などの制約があり得ます。App Store配布やTestFlightは今回の対象外です。

## 78件を壊さず移行する

1. **普段78件の設定が見えている同じSafari/PWA** を開く。別のURLや別ブラウザでは保存領域が異なります。
2. HTMLの「設定一覧をコピー」を押す。まずメモやファイルに貼り付けてバックアップする。Safariデータを消さないこと。
3. iPhoneネイティブアプリにJSONを貼り付けるか、JSONファイルとして選択する。
4. 「内容を確認」で全78件とON/OFF内訳を確認し、「保存してWatchへ送信」。全件置換スナップショットとして取り込むので、差分JSONではなく **設定一覧JSON** を使う。空の `alarms: []` を確認して送るとWatch側の自アプリの予約は解除されます。
5. Watchで「保存済み78件」と予約状況を確認する。iPhoneの「送信待ち」はWatchの予約成功を意味しない。Watchから返ってくる確認を待つ。届かなければ両アプリを開き、iPhoneの再送ボタンを押す。
6. 既存の時計アプリ／ショートカットで作成したアラームはそのまま残るため、二重に鳴る可能性があります。まず1件のテストで確認し、既存時計アラームの停止は利用者が必要に応じて手動で行ってください。

対応形式（HTMLのコピー形式と一致）:

```json
{"version":1,"alarms":[{"day":"月","time":"06:00","label":"起床","on":true},{"day":"日","time":"08:00","label":"休日","on":false}]}
```

曜日は月〜日、時刻は00:00〜23:59、onは真偽値。未知の曜日、不正時刻、on欠落、未対応versionは全体を拒否し、一部だけ取り込んで件数を減らしません。最大5000件・JSON 1MB。HTMLがショートカットに送る `state` / ISO時刻の差分JSONは拒否します。タイムゾーンはWatchの現在のローカル時刻に従います。移動・時計やタイムゾーンの変更後はWatchアプリを開いて再予約してください。

## 通知予約の件数と補充

通知枠を保守的に最大60件まで使用します（64枠を想定し、テストや他用途の予約を考慮）。この数字はすべてのwatchOSバージョンで保証された公開契約ではありません。予約後にOSから一覧を読み直して件数を確認します。

- ONが60件以下なら各曜日・時刻を毎週繰り返し予約。OFFは保存のみ。
- ONが枠数を超える場合、全設定は保持し、**実際の発火予定が早い順に直近60件** を一回通知として予約。翌週の予定も含めて計算します。
- Watchの画面に「予約最終」と「必ずこの日時より前に補充」を表示。後者は最初に予約できなかった予定の日時です。必ずその前にWatchアプリを開くか「予約を補充・再確認」を押す必要があります。同じ発火日時に枠数を超える設定がある場合、その日時の全件予約はできず、再補充でも解決しません。設定を分散するかON件数を減らしてください。
- アプリが開かれた時と設定受信時に補充。閉じたままの無期限自動補充は実装しておらず、保証できません。78件すべてONの運用では、少なくとも毎日開いて残り期間を確認してください。予定が密集している場合はさらに頻繁な補充が必要です。
- `wa.` で始まる自アプリの予約だけ更新し、時計アプリのアラームや元HTMLの設定には触れません。予約途中のエラーは完了件数を表示し、再補充を促します。

## 再現可能なビルド・検証

リポジトリルートから:

```sh
sh native/Scripts/test_core.sh
xcodebuild -project native/WatchAlarm.xcodeproj -scheme WatchAlarm \
  -configuration Debug -destination 'generic/platform=iOS' \
  -derivedDataPath /tmp/WatchAlarm-device CODE_SIGNING_ALLOWED=NO build
xcodebuild -project native/WatchAlarm.xcodeproj -scheme WatchAlarmWatch \
  -configuration Debug -destination 'generic/platform=watchOS' \
  -derivedDataPath /tmp/WatchAlarm-watch CODE_SIGNING_ALLOWED=NO build
```

Xcodeプロジェクトは生成済みで同梱しています。再生成するときだけ `python3 native/Scripts/generate_project.py` を実行します（標準ライブラリのみ）。署名なしビルドはコンパイル・リンク・埋め込みの確認用です。

実機で追加確認する項目: 78件の実JSONの件数、許可拒否→再許可、iPhone/Watchオフライン後の転送、再起動、通知テスト、消音・集中モード、CAF試聴、予約の補充、タイムゾーン変更。実機への転送や通知配信は本環境では未検証です。

## 構成

`Shared/AlarmDocument.swift`: 取り込み検証・永続化・週次／直近予定の計画。
`Shared/Connectivity.swift`: 最新設定と試聴音源の転送・Watchからの状況返信。
`Shared/Chime.swift`: PCM CAFの検証・保存。
`iPhone/PhoneApp.swift`: 貼り付け／ファイル取り込み・確認・送信・JSON共有。
`Watch/WatchApp.swift`: 許可・通知予約・残り期間表示・標準音テスト・アプリ内試聴。

Apple資料: [UNNotificationSound](https://developer.apple.com/documentation/usernotifications/unnotificationsound), [soundNamed API](https://developer.apple.com/documentation/usernotifications/unnotificationsound/init(named:)), [Watch notifications](https://developer.apple.com/documentation/watchos-apps/notifications), [WatchConnectivity](https://developer.apple.com/documentation/watchconnectivity)。watchOSのカスタム音可否については、クラス全体の対応OS表示ではなく、個別メソッドのSDK availabilityを確認してください。
