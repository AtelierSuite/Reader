import CoreMedia
import Foundation
import Speech

/// Groups timed runs from SpeechTranscriber results into sentence-level segments,
/// matching how FluidTranscriberEngine groups Parakeet token timings.
nonisolated struct SpeechSegmentBuilder {

    private(set) var segments: [TranscriptSegment] = []
    private var buffer = ""
    private var segmentStart: TimeInterval?
    private var segmentEnd: TimeInterval = 0

    mutating func consume(_ text: AttributedString) {
        for run in text.runs {
            let piece = String(text[run.range].characters)
            if let timeRange = run[AttributeScopes.SpeechAttributes.TimeRangeAttribute.self] {
                if segmentStart == nil { segmentStart = timeRange.start.seconds }
                segmentEnd = max(segmentEnd, timeRange.end.seconds)
            }
            buffer.append(piece)
            if endsSentence(piece) {
                flush()
            }
        }
    }

    mutating func flush() {
        let trimmed = buffer.trimmingCharacters(in: .whitespacesAndNewlines)
        defer {
            buffer = ""
            segmentStart = nil
        }
        guard !trimmed.isEmpty, let start = segmentStart else { return }
        segments.append(TranscriptSegment(
            id: segments.count,
            start: start,
            end: max(segmentEnd, start + 0.001),
            text: trimmed
        ))
    }

    private func endsSentence(_ piece: String) -> Bool {
        let trimmed = piece.trimmingCharacters(in: .whitespaces)
        guard let last = trimmed.last else { return false }
        return last == "." || last == "!" || last == "?" || last == "。" || last == "？" || last == "！"
    }
}
