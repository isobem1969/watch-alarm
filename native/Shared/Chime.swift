import Foundation
import AVFoundation

// Main-bundle resource may be added later without changing the Xcode project.
enum Chime {
    static let filename = "Haneda28.caf"
    static var directory: URL { FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0].appendingPathComponent("Sounds") }
    static var url: URL { directory.appendingPathComponent(filename) }
    static var available: Bool { FileManager.default.fileExists(atPath: url.path) }
    static func installBundledIfNeeded() throws {
        guard !available, let resource = Bundle.main.url(forResource: "Haneda28", withExtension: "caf", subdirectory: "ChimeAssets") else { return }
        try install(Data(contentsOf: resource))
    }
    static func install(_ data: Data) throws {
        guard data.count <= 10_000_000 else { throw AlarmError.invalid("音源は10MB以下にしてください") }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let temp = directory.appendingPathComponent(UUID().uuidString + ".caf")
        defer { try? FileManager.default.removeItem(at: temp) }
        try data.write(to: temp, options: .atomic)
        let file = try AVAudioFile(forReading: temp)
        let seconds = Double(file.length) / file.fileFormat.sampleRate
        // Linear PCM CAF is the supported input contract; reject compressed/unknown codecs.
        guard seconds > 0, seconds < 30, file.fileFormat.streamDescription.pointee.mFormatID == kAudioFormatLinearPCM else {
            throw AlarmError.invalid("30秒未満のLinear PCM形式CAFが必要です")
        }
        try data.write(to: url, options: .atomic)
    }
}
