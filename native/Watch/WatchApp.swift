import SwiftUI
import UserNotifications
import AVFoundation

final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .list])
    }
}

@MainActor
final class WatchModel: ObservableObject {
    @Published var snapshot: Snapshot?
    @Published var status = "iPhoneから設定を送信してください"
    @Published var count = 0
    @Published var horizon: Date?
    @Published var refreshBefore: Date?
    @Published var rolling = false
    @Published var hasSound = Chime.available
    private var player: AVAudioPlayer?
    private let link = Connectivity()
    private let delegate = NotificationDelegate()
    private let center = UNUserNotificationCenter.current()
    // Keep receipt, foreground refresh, and permission changes in one ordered queue.
    private var queue: Task<Void, Never>?
    init() {
        center.delegate = delegate
        do { snapshot = try SnapshotStore.load(); try Chime.installBundledIfNeeded(); hasSound = Chime.available }
        catch { status = "保存データの読み込み失敗: \(error.localizedDescription)" }
        link.onSnapshot = { [weak self] value in self?.enqueue { [weak self] in await self?.receive(value) } }
        link.onSound = { [weak self] data in
            self?.enqueue { [weak self] in
                guard let self else { return }
                do { try Chime.install(data); self.hasSound = true; await self.schedule() }
                catch { self.report("音源受信失敗: \(error.localizedDescription)") }
            }
        }
        link.onStatus = { [weak self] message in self?.status = message }
    }
    private func enqueue(_ work: @escaping @MainActor () async -> Void) {
        let previous = queue
        queue = Task { await previous?.value; await work() }
    }
    func refresh() { enqueue { [weak self] in await self?.schedule() } }
    func authorize() {
        enqueue { [weak self] in
            guard let self else { return }
            do {
                let granted = try await self.center.requestAuthorization(options: [.alert, .sound])
                guard granted else { self.report("通知が許可されていません。Watchの設定を確認してください"); return }
                await self.schedule()
            } catch { self.report(error.localizedDescription) }
        }
    }
    private func receive(_ value: Snapshot) async {
        // File and application-context transports can arrive in either order.
        guard value.revision > (snapshot?.revision ?? 0) else { await schedule(); return }
        do {
            _ = try value.document
            try SnapshotStore.save(value)
            snapshot = value
            await schedule()
        } catch { report("受信設定を保存できません: \(error.localizedDescription)") }
    }
    private func report(_ message: String) {
        status = message
        link.acknowledge(message)
    }
    private func schedule() async {
        guard let snapshot, let doc = try? snapshot.document else { return }
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else {
            count = 0; horizon = nil; refreshBefore = nil
            report("全\(doc.alarms.count)件を保存済み。Watchで「通知を許可」を押してください")
            return
        }
        let pending = await center.pendingNotificationRequests()
        let own = pending.filter { $0.identifier.hasPrefix("wa.") }
        // Leave room for unrelated notifications and the explicit test notification.
        let capacity = max(0, min(60, 64 - (pending.count - own.count)))
        let plan = AlarmPlan.make(doc, capacity: capacity)
        // Remove only this app's own alarm requests. No Clock/Safari settings are touched.
        center.removePendingNotificationRequests(withIdentifiers: own.map(\.identifier))
        var added: [PlannedAlarm] = []
        do {
            for planned in plan.requests {
                let content = notificationContent(title: planned.alarm.label, body: "\(planned.alarm.day)曜日 \(planned.alarm.time)")
                let components: DateComponents
                if planned.repeats {
                    components = DateComponents(hour: planned.alarm.hour, minute: planned.alarm.minute, second: 0, weekday: planned.alarm.weekday)
                } else {
                    components = Calendar.current.dateComponents([.timeZone, .year, .month, .day, .hour, .minute, .second], from: planned.date)
                }
                try await center.add(UNNotificationRequest(identifier: planned.id, content: content,
                    trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: planned.repeats)))
                added.append(planned)
            }
            let actual = await center.pendingNotificationRequests().filter { $0.identifier.hasPrefix("wa.") }
            count = actual.count; rolling = plan.rolling
            horizon = plan.rolling ? added.last?.date : nil
            refreshBefore = plan.refreshBefore
            guard actual.count == plan.requests.count else { throw AlarmError.invalid("予約件数が一致しません。アプリを再度開いてください") }
            report("全\(doc.alarms.count)件保存 / ON \(doc.alarms.filter(\.on).count)件 / \(count)件予約\(plan.rolling ? "（補充が必要）" : "（毎週繰り返し）") / 標準通知音")
        } catch {
            count = added.count; rolling = true; horizon = added.last?.date; refreshBefore = Date()
            report("予約が途中で失敗（\(count)件完了）: \(error.localizedDescription)。再度補充してください")
        }
    }
    private func notificationContent(title: String, body: String) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = title.isEmpty ? "アラーム" : title
        content.body = body
        // UNNotificationSound(named:) is explicitly unavailable on watchOS.
        content.sound = .default
        return content
    }
    func previewChime() {
        do {
            guard Chime.available else { throw AlarmError.invalid("iPhoneから元のCAFを転送してください") }
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            player = try AVAudioPlayer(contentsOf: Chime.url)
            guard player?.play() == true else { throw AlarmError.invalid("音源を再生できません") }
            status = "アプリ内で試聴中。通知音は標準音です"
        } catch { status = error.localizedDescription }
    }
    func stopPreview() {
        player?.stop()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
    func test() {
        enqueue { [weak self] in
            guard let self else { return }
            do {
                let settings = await self.center.notificationSettings()
                guard settings.authorizationStatus == .authorized else { throw AlarmError.invalid("先に通知を許可してください") }
                try await self.center.add(UNNotificationRequest(identifier: "test.chime", content: self.notificationContent(title: "チャイムのテスト", body: "10秒後のテスト通知です"),
                    trigger: UNTimeIntervalNotificationTrigger(timeInterval: 10, repeats: false)))
                self.status = "10秒後にテスト通知。手首を下げてお待ちください"
            } catch { self.status = error.localizedDescription }
        }
    }
}

@main
struct WatchAlarmApp: App {
    @StateObject private var model = WatchModel()
    @Environment(\.scenePhase) private var scenePhase
    var body: some Scene {
        WindowGroup {
            NavigationStack {
                List {
                    if let snapshot = model.snapshot, let doc = try? snapshot.document { Text("保存済み \(doc.alarms.count)件") }
                    Text(model.status).font(.footnote)
                    Text(model.hasSound ? "試聴用チャイムあり・通知は標準音" : "試聴音源なし・通知は標準音").font(.footnote)
                    if model.rolling {
                        Text("直近\(model.count)件のみ予約中。定期的にこのアプリを開いて補充してください。閉じたままの自動補充は保証されません。")
                        if let horizon = model.horizon { Text("予約最終: \(horizon.formatted(date: .abbreviated, time: .shortened))") }
                        if let deadline = model.refreshBefore { Text("必ずこの日時より前に補充: \(deadline.formatted(date: .abbreviated, time: .shortened))").foregroundStyle(.orange) }
                    }
                    Button("通知を許可") { model.authorize() }
                    Button("予約を補充・再確認") { model.refresh() }
                    Button("チャイムを試聴（アプリ内）") { model.previewChime() }.disabled(!model.hasSound)
                    Button("試聴を停止") { model.stopPreview() }
                    Button("10秒後に標準通知をテスト") { model.test() }
                    Text("通知は標準音です。watchOSではカスタム通知音を指定できません。CAFはこのアプリ内での試聴専用です。消音・集中モード・音量の設定に従います。")
                        .font(.footnote)
                }.navigationTitle("Watch Alarm")
            }.onChange(of: scenePhase) { _, phase in
                    if phase == .active { model.refresh() } else { model.stopPreview() }
                }
                .task { model.refresh() }
        }
    }
}
