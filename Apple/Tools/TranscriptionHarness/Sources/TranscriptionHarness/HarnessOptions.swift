import Foundation

nonisolated enum HarnessEngine: String, CaseIterable, Sendable {
    case apple
    case fluid
    case both
}

nonisolated struct HarnessOptions: Sendable {
    var feedURL: URL
    var episodeIndex = 0
    var engine = HarnessEngine.both
    var clipSeconds: Double = 300
    var localeIdentifier = "en-US"
    var outputDirectory = URL(filePath: FileManager.default.currentDirectoryPath)
        .appending(path: "TranscriptionHarnessOutput")
    var listOnly = false

    static let usage = """
        Usage: transcription-harness <feed-url> [options]

          --list                 List the feed's episodes and exit
          --episode <index>      Episode to transcribe, 0 is the newest (default 0)
          --engine <name>        apple, fluid, or both (default both)
          --seconds <count>      Only transcribe the first <count> seconds, 0 for the whole episode (default 300)
          --locale <identifier>  Locale for the Apple engine (default en-US)
          --output <directory>   Where audio and transcripts are written (default ./TranscriptionHarnessOutput)
        """

    init(arguments: [String]) throws(HarnessError) {
        var remaining = arguments[...]
        var feedURL: URL?
        var options = HarnessOptions(feedURL: URL(filePath: "/"))

        while let argument = remaining.popFirst() {
            if argument.hasPrefix("-") {
                try options.apply(flag: argument, from: &remaining)
            } else if feedURL == nil {
                feedURL = URL(string: argument)
            } else {
                throw .invalidArgument("Unexpected argument \(argument)")
            }
        }

        guard let feedURL else { throw .usageRequested }
        options.feedURL = feedURL
        self = options
    }

    private mutating func apply(flag: String, from remaining: inout ArraySlice<String>) throws(HarnessError) {
        switch flag {
        case "--list": listOnly = true
        case "--episode": episodeIndex = try Self.parse(flag, from: &remaining) { Int($0).flatMap(Self.nonNegative) }
        case "--engine": engine = try Self.parse(flag, from: &remaining) { HarnessEngine(rawValue: $0) }
        case "--seconds": clipSeconds = try Self.parse(flag, from: &remaining) { Double($0).flatMap(Self.nonNegative) }
        case "--locale": localeIdentifier = try Self.parse(flag, from: &remaining) { $0 }
        case "--output": outputDirectory = try Self.parse(flag, from: &remaining) { URL(filePath: $0) }
        case "--help", "-h": throw .usageRequested
        default: throw .invalidArgument("Unknown option \(flag)")
        }
    }

    private static func nonNegative<Number: Comparable & Numeric>(_ number: Number) -> Number? {
        number >= 0 ? number : nil
    }

    private static func parse<Value>(
        _ flag: String,
        from remaining: inout ArraySlice<String>,
        as transform: (String) -> Value?
    ) throws(HarnessError) -> Value {
        guard let rawValue = remaining.popFirst() else { throw .invalidArgument("\(flag) needs a value") }
        guard let value = transform(rawValue) else { throw .invalidArgument("\(rawValue) isn't valid for \(flag)") }
        return value
    }

    private init(feedURL: URL) {
        self.feedURL = feedURL
    }
}

nonisolated enum HarnessError: Error, CustomStringConvertible {
    case usageRequested
    case invalidArgument(String)
    case feedUnreadable(String)
    case episodeMissing(Int, available: Int)
    case downloadFailed(String)

    var description: String {
        switch self {
        case .usageRequested: HarnessOptions.usage
        case .invalidArgument(let message): message
        case .feedUnreadable(let message): "Couldn't read the feed: \(message)"
        case .episodeMissing(let index, let available):
            "Episode \(index) doesn't exist, the feed has \(available) episodes with audio"
        case .downloadFailed(let message): "Couldn't download the episode: \(message)"
        }
    }
}
