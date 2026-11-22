import Foundation

nonisolated struct DMMListedWork: Sendable {
    let contentID: String
    let title: String
    let url: String
    let coverURL: String?
    let bookSeriesID: String?
    let creator: String?
}

nonisolated struct DMMWorkList: Sendable {
    let name: String?
    let works: [DMMListedWork]
}

nonisolated struct DMMDoujinDetail: Sendable {
    let publishedDate: Date?
    let imageURLs: [String]
    let circle: DMMLinkedList?
    let series: DMMLinkedList?
}

nonisolated struct DMMLinkedList: Sendable {
    let identifier: String
    let name: String
}
