import Foundation
import WatchConnectivity

final class Connectivity: NSObject, WCSessionDelegate {
    var onSnapshot: ((Snapshot) -> Void)?
    var onSound: ((Data) -> Void)?
    var onStatus: ((String) -> Void)?
    var onActivation: (() -> Void)?
    private let session = WCSession.default
    override init() {
        super.init()
        if WCSession.isSupported() { session.delegate = self; session.activate() }
    }
    func send(_ snapshot: Snapshot) throws {
        guard session.activationState == .activated else { throw AlarmError.invalid("通信準備中です。少し待ってから再送してください") }
        #if os(iOS)
        guard session.isPaired, session.isWatchAppInstalled else { throw AlarmError.invalid("ペアリングしたWatchにアプリをインストールしてください") }
        #endif
        let data = try JSONEncoder().encode(snapshot)
        if data.count < 60_000 {
            try session.updateApplicationContext(["snapshot": data])
        } else {
            // Larger imports use WC's durable file queue, not the limited context payload.
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json")
            try data.write(to: url, options: .atomic)
            session.transferFile(url, metadata: ["watchAlarm": true])
        }
    }
    func sendSound() throws {
        guard session.activationState == .activated else { throw AlarmError.invalid("通信準備中です") }
        let copy = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".caf")
        try FileManager.default.copyItem(at: Chime.url, to: copy)
        session.transferFile(copy, metadata: ["watchAlarmSound": true])
    }
    func acknowledge(_ status: String) {
        try? session.updateApplicationContext(["status": status])
    }
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error { DispatchQueue.main.async { self.onStatus?(error.localizedDescription) }; return }
        sessionReceived(session.receivedApplicationContext)
        DispatchQueue.main.async { self.onActivation?() }
    }
    private func sessionReceived(_ context: [String: Any]) {
        if let data = context["snapshot"] as? Data { receive(data) }
        if let status = context["status"] as? String { DispatchQueue.main.async { self.onStatus?(status) } }
    }
    private func receive(_ data: Data) {
        do {
            guard data.count < 1_500_000 else { throw AlarmError.invalid("転送サイズが大きすぎます") }
            let value = try JSONDecoder().decode(Snapshot.self, from: data)
            _ = try value.document
            guard value.revision.isFinite else { throw AlarmError.invalid("転送番号が不正です") }
            DispatchQueue.main.async { self.onSnapshot?(value) }
        } catch { DispatchQueue.main.async { self.onStatus?("受信失敗: \(error.localizedDescription)") } }
    }
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) { sessionReceived(applicationContext) }
    func session(_ session: WCSession, didReceive file: WCSessionFile) {
        if file.metadata?["watchAlarmSound"] as? Bool == true {
            do {
                let data = try Data(contentsOf: file.fileURL)
                DispatchQueue.main.async { self.onSound?(data) }
            } catch { DispatchQueue.main.async { self.onStatus?(error.localizedDescription) } }
            return
        }
        guard file.metadata?["watchAlarm"] as? Bool == true else { return }
        // WC deletes the temporary received file after this callback returns.
        do { receive(try Data(contentsOf: file.fileURL)) }
        catch { DispatchQueue.main.async { self.onStatus?(error.localizedDescription) } }
    }
    func session(_ session: WCSession, didFinish fileTransfer: WCSessionFileTransfer, error: Error?) {
        try? FileManager.default.removeItem(at: fileTransfer.file.fileURL)
        if let error { DispatchQueue.main.async { self.onStatus?("転送失敗。再送してください: \(error.localizedDescription)") } }
    }
    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) { session.activate() }
    #endif
}
