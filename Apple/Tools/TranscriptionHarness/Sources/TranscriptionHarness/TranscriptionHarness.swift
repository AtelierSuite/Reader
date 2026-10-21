import Foundation
import HanamiTranscriber

@main
enum TranscriptionHarness {

    static func main() async {
        setvbuf(stdout, nil, _IOLBF, 0)
        do {
            let options = try HarnessOptions(arguments: Array(CommandLine.arguments.dropFirst()))
            try await run(options)
        } catch HarnessError.usageRequested {
            print(HarnessOptions.usage)
        } catch {
            FileHandle.standardError.write(Data("error: \(error)\n".utf8))
            exit(1)
        }
    }

    private static func run(_ options: HarnessOptions) async throws {
        let episodes = try await PodcastFeed.episodes(at: options.feedURL)
        if options.listOnly {
            for (index, episode) in episodes.enumerated() {
                print("\(index)\t\(episode.duration ?? "?")\t\(episode.title)")
            }
            return
        }
        guard episodes.indices.contains(options.episodeIndex) else {
            throw HarnessError.episodeMissing(options.episodeIndex, available: episodes.count)
        }
        let episode = episodes[options.episodeIndex]
        print("Episode: \(episode.title)")
        print("Audio:   \(episode.audioURL.absoluteString)")

        let audioDirectory = options.outputDirectory.appending(path: "Audio")
        try FileManager.default.createDirectory(at: audioDirectory, withIntermediateDirectories: true)
        let downloadedURL = try await EpisodeAudio.download(episode, into: audioDirectory)
        let audioURL = try await EpisodeAudio.clip(downloadedURL, toFirst: options.clipSeconds)
        let audioSeconds = try await EpisodeAudio.duration(of: audioURL)
        print("File:    \(audioURL.path) (\(TranscriptionRun.format(audioSeconds))s)")

        let runDirectory = options.outputDirectory.appending(path: audioURL.deletingPathExtension().lastPathComponent)
        try FileManager.default.createDirectory(at: runDirectory, withIntermediateDirectories: true)

        var runs: [TranscriptionRun] = []
        for (engineName, engine) in engines(for: options) {
            do {
                let run = try await TranscriptionRun.perform(
                    engineName: engineName,
                    engine: engine,
                    audioURL: audioURL,
                    audioSeconds: audioSeconds,
                    title: episode.title
                )
                try run.write(to: runDirectory)
                run.printSummary()
                runs.append(run)
            } catch {
                FileHandle.standardError.write(Data("\n\(engineName) failed: \(error)\n".utf8))
            }
        }

        if runs.count == 2 {
            let rate = TranscriptComparison.disagreementRate(reference: runs[1].plainText, candidate: runs[0].plainText)
            print("\nWord disagreement between \(runs[0].engineName) and \(runs[1].engineName): " +
                  "\(TranscriptionRun.format(rate * 100))%")
        }
        print("\nTranscripts written to \(runDirectory.path)")
    }

    private static func engines(for options: HarnessOptions) -> [(String, any TranscriptionEngine)] {
        let apple: (String, any TranscriptionEngine) = (
            "apple", SpeechTranscriberEngine(locale: Locale(identifier: options.localeIdentifier))
        )
        let fluid: (String, any TranscriptionEngine) = ("fluid", FluidTranscriberEngine())
        switch options.engine {
        case .apple: return [apple]
        case .fluid: return [fluid]
        case .both: return [apple, fluid]
        }
    }
}
