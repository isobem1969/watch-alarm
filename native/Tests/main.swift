import Foundation

func check(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else { fatalError(message) }
}
func rejects(_ text: String) {
    do { _ = try AlarmDocument.parse(Data(text.utf8)); fatalError("Accepted invalid JSON") } catch {}
}
let json = #"{"version":1,"alarms":[{"day":"月","time":"06:00","label":"起床","on":true},{"day":"日","time":"23:59","label":"OFFも保存","on":false}]}"#
let doc = try AlarmDocument.parse(Data(json.utf8))
check(doc.alarms.count == 2 && !doc.alarms[1].on, "OFF entries must survive")
rejects(json.replacingOccurrences(of: "06:00", with: "24:00"))
rejects(json.replacingOccurrences(of: "06:00", with: "06:60"))
rejects(json.replacingOccurrences(of: "06:00", with: "6:00"))
rejects(json.replacingOccurrences(of: "\"月\"", with: "\"祝\""))
rejects(json.replacingOccurrences(of: "\"version\":1", with: "\"version\":2"))
rejects(#"{"version":1,"alarms":[{"day":"月","time":"06:00","label":"x","state":"ON"}]}"#)
rejects(#"{"version":1,"alarms":[{"day":"月","time":"06:00","label":"x"}]}"#)
var cal = Calendar(identifier: .gregorian)
cal.timeZone = TimeZone(identifier: "Asia/Tokyo")!
let now = ISO8601DateFormatter().date(from: "2026-10-30T00:00:00Z")!
let weekly = AlarmPlan.make(doc, now: now, calendar: cal)
check(weekly.requests.count == 1 && weekly.requests[0].repeats && !weekly.rolling, "Weekly mode")
check(cal.component(.weekday, from: weekly.requests[0].date) == 2, "Monday conversion")
check(cal.component(.hour, from: weekly.requests[0].date) == 6, "Local hour")
let many = AlarmDocument(version: 1, alarms: (0..<78).map { i in
    Alarm(day: ["月","火","水","木","金","土","日"][i % 7], time: String(format: "%02d:%02d", 6 + i / 60, i % 60), label: "設定\(i)", on: true)
})
let roundtrip = try AlarmDocument.parse(JSONEncoder().encode(many))
check(roundtrip == many && roundtrip.alarms.count == 78, "Preserve all 78")
let plan = AlarmPlan.make(many, now: now, calendar: cal)
check(plan.requests.count == 60 && plan.rolling && plan.refreshBefore != nil, "78 entries need bounded queue")
check(Set(plan.requests.map(\.id)).count == 60, "Unique identifiers")
check(plan.requests.allSatisfy { $0.date > now && !$0.repeats }, "Future one-shot occurrences")
check(plan.requests.map(\.date) == plan.requests.map(\.date).sorted(), "Chronological queue")
check(plan.refreshBefore! >= plan.requests.last!.date, "Refresh deadline")
let replenished = AlarmPlan.make(many, now: plan.requests[20].date, calendar: cal)
check(replenished.requests.count == 60 && replenished.requests[0].date > plan.requests[20].date, "Refill after delivery")
let duplicates = AlarmDocument(version: 1, alarms: Array(repeating: doc.alarms[0], count: 78))
check(AlarmPlan.make(duplicates, now: now, calendar: cal).requests.count == 60, "Do not silently discard duplicates")
let empty = AlarmPlan.make(AlarmDocument(version: 1, alarms: []), now: now, calendar: cal)
check(empty.requests.isEmpty && !empty.rolling, "Empty snapshot clears queue")
let noCapacity = AlarmPlan.make(many, now: now, calendar: cal, capacity: 0)
check(noCapacity.requests.isEmpty && noCapacity.refreshBefore == now, "Capacity exhaustion")
cal.timeZone = TimeZone(identifier: "America/Los_Angeles")!
let dstAlarm = AlarmDocument(version: 1, alarms: [Alarm(day: "日", time: "02:30", label: "DST", on: true)])
let dstNow = ISO8601DateFormatter().date(from: "2026-03-08T08:00:00Z")!
let dst = AlarmPlan.make(dstAlarm, now: dstNow, calendar: cal)
check(dst.requests.count == 1 && dst.requests[0].date > dstNow, "Nonexistent DST hour advances")
let boundary = AlarmPlan.make(doc, now: weekly.requests[0].date, calendar: Calendar(identifier: .gregorian))
check(boundary.requests[0].date > weekly.requests[0].date, "No firing at past/exact time")
print("PASS: validation, 78-entry preservation, OFF/duplicates, weekly/rolling queue, refill, capacity, timezone/DST")
