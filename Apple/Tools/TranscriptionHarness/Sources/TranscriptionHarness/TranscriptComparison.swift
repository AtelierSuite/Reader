import Foundation

/// Word-level edit distance between two transcripts. Neither side is ground truth,
/// so this is a disagreement rate, not a word error rate.
nonisolated enum TranscriptComparison {

    static func disagreementRate(reference: String, candidate: String) -> Double {
        let referenceWords = normalizedWords(reference)
        let candidateWords = normalizedWords(candidate)
        guard !referenceWords.isEmpty else { return candidateWords.isEmpty ? 0 : 1 }

        var previousRow = Array(0...candidateWords.count)
        var currentRow = Array(repeating: 0, count: candidateWords.count + 1)
        for (referenceIndex, referenceWord) in referenceWords.enumerated() {
            currentRow[0] = referenceIndex + 1
            for (candidateIndex, candidateWord) in candidateWords.enumerated() {
                let substitutionCost = referenceWord == candidateWord ? 0 : 1
                currentRow[candidateIndex + 1] = min(
                    previousRow[candidateIndex + 1] + 1,
                    currentRow[candidateIndex] + 1,
                    previousRow[candidateIndex] + substitutionCost
                )
            }
            swap(&previousRow, &currentRow)
        }
        return Double(previousRow[candidateWords.count]) / Double(referenceWords.count)
    }

    private static func normalizedWords(_ text: String) -> [String] {
        text.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.union(.init(charactersIn: "'")).inverted)
            .filter { !$0.isEmpty }
    }
}
