import Foundation

public nonisolated struct PlayStoreAppDetails: Sendable {
    public let packageIdentifier: String
    public let title: String
    public let developerName: String?
    public let iconURL: String?
    public let version: String?
    public let releaseNotesHTML: String?
    public let updatedDate: Date?
    public let summary: String?
}

public nonisolated struct PlayStoreDeveloperApp: Sendable {
    public let packageIdentifier: String
    public let title: String
    public let developerName: String?
    public let iconURL: String?
    public let descriptionHTML: String?
}

public nonisolated struct PlayStoreDeveloperPage: Sendable {
    public let developerName: String?
    public let iconURL: String?
    public let apps: [PlayStoreDeveloperApp]
}
