import AVFoundation
import Foundation

nonisolated enum EpisodeAudio {

    static func download(_ episode: PodcastEpisode, into directory: URL) async throws -> URL {
        let fileExtension = episode.audioURL.pathExtension.isEmpty ? "mp3" : episode.audioURL.pathExtension
        let fileName = "\(stableName(for: episode.audioURL.absoluteString)).\(fileExtension)"
        let destination = directory.appending(path: fileName)
        if FileManager.default.fileExists(atPath: destination.path) {
            return destination
        }

        let (temporaryURL, response) = try await URLSession.shared.download(from: episode.audioURL)
        if let httpResponse = response as? HTTPURLResponse, !(200..<300).contains(httpResponse.statusCode) {
            throw HarnessError.downloadFailed("HTTP \(httpResponse.statusCode)")
        }
        try FileManager.default.moveItem(at: temporaryURL, to: destination)
        return destination
    }

    static func clip(_ audioURL: URL, toFirst seconds: Double) async throws -> URL {
        let asset = AVURLAsset(url: audioURL)
        let duration = try await asset.load(.duration).seconds
        guard seconds > 0, seconds < duration else { return audioURL }

        let destination = audioURL
            .deletingPathExtension()
            .appendingPathExtension("first\(Int(seconds))s.m4a")
        if FileManager.default.fileExists(atPath: destination.path) {
            return destination
        }

        guard let session = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            throw HarnessError.downloadFailed("couldn't create an export session to clip the audio")
        }
        session.timeRange = CMTimeRange(
            start: .zero,
            duration: CMTime(seconds: seconds, preferredTimescale: 600)
        )
        try await session.export(to: destination, as: .m4a)
        return destination
    }

    static func duration(of audioURL: URL) async throws -> Double {
        try await AVURLAsset(url: audioURL).load(.duration).seconds
    }

    private static func stableName(for string: String) -> String {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in string.utf8 {
            hash = (hash ^ UInt64(byte)) &* 0x100000001b3
        }
        return String(hash, radix: 16)
    }
}
