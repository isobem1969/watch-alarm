import Foundation

struct Alarm: Codable, Equatable, Identifiable {
    let day: String
    let time: String
    let label: String
    let on: Bool
    // Index-based notification IDs preserve even identical entries without dropping settings.
    var id: String { "\(day) \(time) \(label) \(on)" }
    var weekday: Int { (["日", "月", "火", "水", "木", "金", "土"].firstIndex(of: day) ?? 0) + 1 }
    var hour: Int { Int(time.prefix(2))! }
    var minute: Int { Int(time.suffix(2))! }
}

struct AlarmDocument: Codable, Equatable {
    let version: Int
    let alarms: [Alarm]

    static func parse(_ data: Data) throws -> Self {
        guard data.count <= 1_000_000 else { throw AlarmError.invalid("JSONは1MB以下にしてください") }
        let doc: Self
        do { doc = try JSONDecoder().decode(Self.self, from: data) }
        catch { throw AlarmError.invalid("「設定一覧をコピー」のJSON（version, alarms, day, time, label, on）が必要です。差分送信用JSONは使えません") }
        guard doc.version == 1, doc.alarms.count <= 5000 else { throw AlarmError.invalid("versionは1、設定数は5000件以下にしてください") }
        for (i, a) in doc.alarms.enumerated() {
            let parts = a.time.split(separator: ":", omittingEmptySubsequences: false)
            guard ["月", "火", "水", "木", "金", "土", "日"].contains(a.day),
                  a.time.utf8.count == 5, parts.count == 2,
                  parts.allSatisfy({ $0.utf8.count == 2 && $0.utf8.allSatisfy { (48...57).contains($0) } }),
                  let h = Int(parts[0]), let m = Int(parts[1]), (0...23).contains(h), (0...59).contains(m),
                  a.label.count <= 200 else { throw AlarmError.invalid("\(i + 1)件目の曜日・時刻・名前が不正です。取り込みを中止しました") }
        }
        return doc
    }
}

enum AlarmError: LocalizedError {
    case invalid(String)
    var errorDescription: String? { if case .invalid(let message) = self { return message }; return nil }
}

struct Snapshot: Codable {
    let revision: Double
    let json: Data
    var document: AlarmDocument { get throws { try AlarmDocument.parse(json) } }
}

struct PlannedAlarm {
    let id: String
    let alarm: Alarm
    let date: Date
    let repeats: Bool
}

struct AlarmPlan {
    let requests: [PlannedAlarm]
    let rolling: Bool
    // First excluded occurrence: refresh before this date to avoid missing an alarm.
    let refreshBefore: Date?

    static func make(_ doc: AlarmDocument, now: Date = Date(), calendar: Calendar = .current,
                     capacity: Int = 60) -> Self {
        let enabled = doc.alarms.enumerated().filter { $0.element.on }
        guard capacity > 0 else { return Self(requests: [], rolling: true, refreshBefore: now) }
        if enabled.count <= capacity {
            return Self(requests: enabled.compactMap { index, alarm in
                guard let date = next(alarm, after: now, calendar: calendar) else { return nil }
                return PlannedAlarm(id: "wa.weekly.\(index)", alarm: alarm, date: date, repeats: true)
            }, rolling: false, refreshBefore: nil)
        }
        // Merge weekly streams rather than approximating weeks as fixed 7*24 hours (DST).
        var streams = enabled.compactMap { index, alarm -> PlannedAlarm? in
            guard let date = next(alarm, after: now, calendar: calendar) else { return nil }
            return PlannedAlarm(id: "\(index)", alarm: alarm, date: date, repeats: false)
        }
        var output: [PlannedAlarm] = []
        for _ in 0...capacity {
            streams.sort { $0.date == $1.date ? $0.id < $1.id : $0.date < $1.date }
            guard !streams.isEmpty else { break }
            let first = streams.removeFirst()
            if output.count == capacity { return Self(requests: output, rolling: true, refreshBefore: first.date) }
            output.append(PlannedAlarm(id: "wa.once.\(first.id).\(Int(first.date.timeIntervalSince1970))",
                                       alarm: first.alarm, date: first.date, repeats: false))
            if let date = next(first.alarm, after: first.date, calendar: calendar) {
                streams.append(PlannedAlarm(id: first.id, alarm: first.alarm, date: date, repeats: false))
            }
        }
        return Self(requests: output, rolling: true, refreshBefore: nil)
    }

    private static func next(_ a: Alarm, after date: Date, calendar: Calendar) -> Date? {
        calendar.nextDate(after: date, matching: DateComponents(hour: a.hour, minute: a.minute, second: 0, weekday: a.weekday),
                          matchingPolicy: .nextTime, repeatedTimePolicy: .first, direction: .forward)
    }
}

// Atomic files retain complete source JSON and OFF entries. No access to Safari localStorage.
enum SnapshotStore {
    static var url: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("WatchAlarm/snapshot.json")
    }
    static func load() throws -> Snapshot? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let value = try JSONDecoder().decode(Snapshot.self, from: Data(contentsOf: url))
        _ = try value.document
        return value
    }
    static func save(_ value: Snapshot) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(value).write(to: url, options: .atomic)
    }
}
