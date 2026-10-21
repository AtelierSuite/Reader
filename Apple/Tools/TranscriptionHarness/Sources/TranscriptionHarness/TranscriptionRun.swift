import Foundation
import HanamiTranscriber

nonisolated struct TranscriptionRun: Sendable {
    let engineName: String
    let audioSeconds: Double
    let modelPreparationSeconds: Double
    let transcriptionSeconds: Double
    let segments: [TranscriptSegment]

    var speedMultiple: Double { transcriptionSeconds > 0 ? audioSeconds / transcriptionSeconds : 0 }

    var plainText: String { segments.map(\.text).joined(separator: " ") }

    @MainActor
    static func perform(
        engineName: String,
        engine: any TranscriptionEngine,
        audioURL: URL,
        audioSeconds: Double,
        title: String
    ) async throws -> TranscriptionRun {
        let clock = ContinuousClock()

        let downloadReporter = ProgressReporter(label: "\(engineName) model")
        let preparationStart = clock.now
        if !engine.isModelDownloaded || engine is SpeechTranscriberEngine {
            try await engine.downloadModel(progress: downloadReporter.report)
            downloadReporter.finish()
        }
        let preparationDuration = preparationStart.duration(to: clock.now)

        let transcriptionReporter = ProgressReporter(label: "\(engineName) transcription")
        let transcriptionStart = clock.now
        let segments = try await engine.transcribe(
            audioFileURL: audioURL,
            title: title,
            progress: transcriptionReporter.report
        )
        transcriptionReporter.finish()
        let transcriptionDuration = transcriptionStart.duration(to: clock.now)

        return TranscriptionRun(
            engineName: engineName,
            audioSeconds: audioSeconds,
            modelPreparationSeconds: preparationDuration.seconds,
            transcriptionSeconds: transcriptionDuration.seconds,
            segments: segments
        )
    }

    func write(to directory: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(segments).write(to: directory.appending(path: "\(engineName).json"))

        let timedLines = segments.map { segment in
            "[\(Self.timestamp(segment.start)) – \(Self.timestamp(segment.end))] \(segment.text)"
        }
        try timedLines.joined(separator: "\n").write(
            to: directory.appending(path: "\(engineName).txt"),
            atomically: true,
            encoding: .utf8
        )
    }

    func printSummary(previewCount: Int = 5) {
        print("""

            == \(engineName)
            Model preparation: \(Self.format(modelPreparationSeconds))s
            Transcription:     \(Self.format(transcriptionSeconds))s for \(Self.format(audioSeconds))s of audio \
            (\(Self.format(speedMultiple))× real time)
            Segments:          \(segments.count), \(plainText.split(separator: " ").count) words
            """)
        for segment in segments.prefix(previewCount) {
            print("  [\(Self.timestamp(segment.start))] \(segment.text)")
        }
    }

    static func timestamp(_ seconds: TimeInterval) -> String {
        let totalSeconds = Int(seconds)
        return String(format: "%02d:%02d:%02d", totalSeconds / 3600, (totalSeconds / 60) % 60, totalSeconds % 60)
    }

    static func format(_ value: Double) -> String {
        String(format: "%.1f", value)
    }
}

private nonisolated extension Duration {
    var seconds: Double {
        Double(components.seconds) + Double(components.attoseconds) / 1e18
    }
}
