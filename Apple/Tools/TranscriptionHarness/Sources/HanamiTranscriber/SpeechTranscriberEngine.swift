import AVFoundation
import Foundation
import Speech

/// Transcription engine using the system SpeechAnalyzer and SpeechTranscriber models.
public nonisolated struct SpeechTranscriberEngine: TranscriptionEngine {

    public let locale: Locale

    public init(locale: Locale) {
        self.locale = locale
    }

    public static let requiresModelDownload = true

    // The protocol needs this synchronously, but installed locales can only be read asynchronously,
    // so callers should always go through downloadModel, which returns immediately when installed.
    public var isModelDownloaded: Bool { SpeechTranscriber.isAvailable }

    public var isAvailable: Bool {
        get async {
            guard SpeechTranscriber.isAvailable else { return false }
            return await SpeechTranscriber.supportedLocale(equivalentTo: locale) != nil
        }
    }

    public var isLocaleInstalled: Bool {
        get async {
            guard let supportedLocale = await SpeechTranscriber.supportedLocale(equivalentTo: locale) else {
                return false
            }
            return await SpeechTranscriber.installedLocales.contains(supportedLocale)
        }
    }

    public func downloadModel(progress: (@Sendable (Double) -> Void)?) async throws {
        let transcriber = try await makeTranscriber()
        guard let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) else {
            progress?(1)
            return
        }
        let observation = request.progress.observe(\.fractionCompleted) { reportedProgress, _ in
            progress?(reportedProgress.fractionCompleted)
        }
        defer { observation.invalidate() }
        try await request.downloadAndInstall()
    }

    public func deleteModel() throws {
        let locale = locale
        Task {
            guard let supportedLocale = await SpeechTranscriber.supportedLocale(equivalentTo: locale) else { return }
            _ = await AssetInventory.release(reservedLocale: supportedLocale)
        }
    }

    public func transcribe(
        audioFileURL: URL,
        title: String,
        progress: (@Sendable (Double) -> Void)?
    ) async throws -> [TranscriptSegment] {
        guard FileManager.default.fileExists(atPath: audioFileURL.path) else {
            throw TranscriptionEngineError.audioFileUnreadable
        }
        let audioFile: AVAudioFile
        do {
            audioFile = try AVAudioFile(forReading: audioFileURL)
        } catch {
            throw TranscriptionEngineError.audioFileUnreadable
        }
        let totalSeconds = Double(audioFile.length) / audioFile.processingFormat.sampleRate

        let transcriber = try await makeTranscriber()
        let analyzer = SpeechAnalyzer(modules: [transcriber])

        let resultsTask = Task {
            var builder = SpeechSegmentBuilder()
            for try await result in transcriber.results {
                builder.consume(result.text)
                if totalSeconds > 0 {
                    progress?(min(1, result.range.end.seconds / totalSeconds))
                }
            }
            builder.flush()
            return builder.segments
        }

        do {
            if let lastSampleTime = try await analyzer.analyzeSequence(from: audioFile) {
                try await analyzer.finalizeAndFinish(through: lastSampleTime)
            } else {
                await analyzer.cancelAndFinishNow()
            }
        } catch {
            resultsTask.cancel()
            throw TranscriptionEngineError.transcriptionFailed(error.localizedDescription)
        }
        return try await resultsTask.value
    }

    private func makeTranscriber() async throws -> SpeechTranscriber {
        guard let supportedLocale = await SpeechTranscriber.supportedLocale(equivalentTo: locale) else {
            throw TranscriptionEngineError.notAvailable
        }
        return SpeechTranscriber(
            locale: supportedLocale,
            transcriptionOptions: [],
            reportingOptions: [],
            attributeOptions: [.audioTimeRange]
        )
    }
}
