import Foundation

nonisolated struct DLsiteArticleContent {

    let coverURL: String?
    let listedSampleURLs: [String]
    let detail: DLsiteProductDetail?
    let description: [DLsiteDescriptionSection]
    let circleName: String?
    let listedCreatorNames: [String]

    var imageURLs: [String] {
        var urls: [String] = []
        for url in [coverURL].compactMap(\.self) + (detail?.sampleImageURLs ?? []) + listedSampleURLs
        where !urls.contains(url) {
            urls.append(url)
        }
        return urls
    }

    var summary: String? {
        let introduction = detail?.shortIntroduction?.trimmingCharacters(in: .whitespacesAndNewlines)
        return introduction?.isEmpty == false ? introduction : nil
    }

    var authorLine: String? {
        let creators = detail.map { detail in Self.creditRoles.flatMap { detail.creatorsByRole[$0.key] ?? [] } }
            ?? listedCreatorNames
        var names: [String] = []
        for name in [circleName].compactMap(\.self) + creators where !names.contains(name) {
            names.append(name)
        }
        return names.isEmpty ? nil : names.joined(separator: " / ")
    }

    var html: String {
        let images = imageURLs
        var blocks: [String] = []
        if let cover = images.first {
            blocks.append(Self.figure(cover))
        }
        if description.isEmpty, let summary {
            blocks.append("<p>\(RSSParser.escapeXMLText(summary))</p>")
        }
        for section in description {
            if let heading = section.heading {
                blocks.append("<h3>\(RSSParser.escapeXMLText(heading))</h3>")
            }
            blocks.append(section.html)
        }
        if let details = detailsList {
            blocks.append(details)
        }
        blocks.append(contentsOf: images.dropFirst().map(Self.figure))
        return blocks.joined()
    }

    private var detailsList: String? {
        guard let detail else { return nil }
        var rows: [(String, String)] = []
        if let workType = detail.workTypeName, !workType.isEmpty {
            rows.append((Self.label("DLsite.Detail.WorkType"), workType))
        }
        if let circleName {
            rows.append((Self.label("DLsite.Detail.Circle"), circleName))
        }
        for role in Self.creditRoles {
            if let names = detail.creatorsByRole[role.key], !names.isEmpty {
                rows.append((Self.label(role.labelKey), names.joined(separator: ", ")))
            }
        }
        if !detail.genres.isEmpty {
            rows.append((Self.label("DLsite.Detail.Genres"), detail.genres.joined(separator: ", ")))
        }
        if let pageCount = detail.pageCount, pageCount > 0 {
            rows.append((Self.label("DLsite.Detail.Pages"), pageCount.formatted()))
        }
        if let price = detail.price {
            rows.append((Self.label("DLsite.Detail.Price"), price.formatted(.currency(code: "JPY"))))
        }
        guard !rows.isEmpty else { return nil }
        let items = rows.map { label, value in
            "<li><strong>\(RSSParser.escapeXMLText(label))</strong>: \(RSSParser.escapeXMLText(value))</li>"
        }
        return "<ul>\(items.joined())</ul>"
    }

    private static let creditRoles: [(key: String, labelKey: String)] = [
        ("created_by", "DLsite.Detail.Author"),
        ("scenario_by", "DLsite.Detail.Scenario"),
        ("illust_by", "DLsite.Detail.Illustration"),
        ("voice_by", "DLsite.Detail.Voice"),
        ("music_by", "DLsite.Detail.Music")
    ]

    private static func label(_ key: String) -> String {
        String(localized: String.LocalizationValue(key), table: "Integrations")
    }

    private static func figure(_ url: String) -> String {
        "<figure><img src=\"\(RSSParser.escapeXMLAttribute(url))\"></figure>"
    }
}
