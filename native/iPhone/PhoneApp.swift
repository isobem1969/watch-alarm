import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class PhoneModel: ObservableObject {
    @Published var importingJSON = false
    @Published var importingSound = false
    @Published var text = "" { didSet { preview = nil } }
    @Published var preview: AlarmDocument?
    @Published var snapshot: Snapshot?
    @Published var status = "JSONを貼り付けるか、ファイルを読み込んでください"
    @Published var watchStatus = "Watchの受信確認はまだありません"
    @Published var hasSound = Chime.available
    private let link = Connectivity()
    init() {
        do { snapshot = try SnapshotStore.load(); try Chime.installBundledIfNeeded(); hasSound = Chime.available }
        catch { status = error.localizedDescription }
        link.onStatus = { [weak self] in self?.watchStatus = $0 }
        link.onActivation = { [weak self] in
            // Restore latest snapshot after activation; delivery does not require reachability.
            guard let self, let snapshot = self.snapshot else { return }
            do { try self.link.send(snapshot) } catch { self.status = error.localizedDescription }
        }
    }
    func inspect() {
        do { preview = try AlarmDocument.parse(Data(text.utf8)); status = "件数を確認して「保存してWatchへ送信」を押してください" }
        catch { preview = nil; status = error.localizedDescription }
    }
    func commit() {
        do {
            let data = Data(text.utf8)
            let doc = try AlarmDocument.parse(data)
            guard doc == preview else { throw AlarmError.invalid("内容が変わりました。もう一度確認してください") }
            let value = Snapshot(revision: max(Date().timeIntervalSince1970, (snapshot?.revision ?? 0) + 0.001), json: data)
            try SnapshotStore.save(value)
            snapshot = value
            preview = nil
            try link.send(value)
            status = "\(doc.alarms.count)件を保存・送信待ちにしました。Watchの確認表示をお待ちください"
        } catch { status = error.localizedDescription }
    }
    func resend() {
        do {
            guard let snapshot else { throw AlarmError.invalid("先に設定を保存してください") }
            try link.send(snapshot)
            if Chime.available { try link.sendSound() }
            status = "保存済み設定を再送しました。Watchで受信・予約状況を確認してください"
        } catch { status = error.localizedDescription }
    }
    func load(_ result: Result<[URL], Error>, sound: Bool) {
        do {
            guard let url = try result.get().first else { return }
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            guard size <= (sound ? 10_000_000 : 1_000_000) else { throw AlarmError.invalid("ファイルが大きすぎます") }
            let data = try Data(contentsOf: url)
            if sound {
                try Chime.install(data); hasSound = true; try link.sendSound()
                status = "音源を保存・転送待ちにしました。Watchで確認してください"
            } else {
                _ = try AlarmDocument.parse(data)
                text = String(decoding: data, as: UTF8.self); inspect()
            }
        } catch { status = error.localizedDescription }
    }
}

@main
struct PhoneApp: App {
    @StateObject private var model = PhoneModel()
    var body: some Scene {
        WindowGroup {
            NavigationStack {
                Form {
                    Section("HTMLから設定を取り込む") {
                        Text("元のHTMLで「設定一覧をコピー」を押し、JSONを下に貼り付けてください。ブラウザの設定は変更しません。")
                        TextEditor(text: $model.text).frame(minHeight: 140).font(.caption.monospaced())
                        Button("JSONファイルを選択") { model.importingJSON = true }
                        Button("内容を確認") { model.inspect() }
                        if let doc = model.preview {
                            Text("全\(doc.alarms.count)件 / ON \(doc.alarms.filter(\.on).count)件 / OFF \(doc.alarms.filter { !$0.on }.count)件")
                            Button("保存してWatchへ送信") { model.commit() }
                        }
                    }
                    Section("送信状況") {
                        Text(model.status)
                        if let snapshot = model.snapshot, let doc = try? snapshot.document { Text("iPhoneに保存済み: \(doc.alarms.count)件"); ShareLink("保存済みJSONを共有・バックアップ", item: String(decoding: snapshot.json, as: UTF8.self)) }
                        Button("保存済み設定・音源を再送") { model.resend() }.disabled(model.snapshot == nil)
                        Text(model.watchStatus)
                        Text("転送は非同期です。Watchでアプリを一度開き、通知を許可してください。")
                    }
                    Section("チャイム音源") {
                        Text(model.hasSound ? "アプリ内試聴用CAFを保存済み" : "元音源は未組み込み")
                        Button("元のCAFを選んでWatchへ転送") { model.importingSound = true }
                        Text("Watchの通知音は標準音です。watchOSではカスタム通知音を指定できません。転送したCAFはWatchアプリ内の試聴専用です（30秒未満のLinear PCM形式）。")
                    }
                }
                .navigationTitle("Watch Alarm")
                .fileImporter(isPresented: $model.importingJSON, allowedContentTypes: [.json], allowsMultipleSelection: false) { model.load($0, sound: false) }
                .fileImporter(isPresented: $model.importingSound, allowedContentTypes: [UTType(filenameExtension: "caf") ?? .audio], allowsMultipleSelection: false) { model.load($0, sound: true) }
            }
        }
    }
}
