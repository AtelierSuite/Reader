import Foundation
import ImageIO
import UniformTypeIdentifiers
@preconcurrency import UserNotifications

nonisolated enum NewContentNotificationThumbnail {

    private static let maximumPixelSize = 1024
    private static let downloadTimeout: TimeInterval = 10

    static func attachment(
        imageURL: String,
        articleID: Int64,
        database: DatabaseManager
    ) async -> UNNotificationAttachment? {
        guard let imageData = await imageData(for: imageURL, database: database) else {
            log("Notifications", "thumbnail unavailable articleID=\(articleID)")
            return nil
        }
        guard let fileURL = writeThumbnail(from: imageData, articleID: articleID) else {
            log("Notifications", "thumbnail not written articleID=\(articleID) bytes=\(imageData.count)")
            return nil
        }
        do {
            return try UNNotificationAttachment(
                identifier: "thumbnail",
                url: fileURL,
                options: [UNNotificationAttachmentOptionsTypeHintKey: UTType.jpeg.identifier]
            )
        } catch {
            log("Notifications", "attachment failed articleID=\(articleID) error=\(error)")
            try? FileManager.default.removeItem(at: fileURL)
            return nil
        }
    }

    private static func imageData(for imageURL: String, database: DatabaseManager) async -> Data? {
        if let cached = try? database.cachedImageData(for: imageURL), !cached.isEmpty {
            return cached
        }
        guard let url = URL(string: imageURL), url.scheme?.hasPrefix("http") == true else { return nil }
        let request = URLRequest.sakuraImage(url: url, timeoutInterval: downloadTimeout)
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode ?? 200 < 400 else { return nil }
        return data
    }

    /// Attachments must be files, and the system moves them into its own store.
    private static func writeThumbnail(from imageData: Data, articleID: Int64) -> URL? {
        guard let source = CGImageSourceCreateWithData(imageData as CFData, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: maximumPixelSize
              ] as CFDictionary) else { return nil }
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("NotificationThumbnails", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fileURL = directory.appendingPathComponent("\(articleID)-\(UUID().uuidString).jpg")
        guard let destination = CGImageDestinationCreateWithURL(
            fileURL as CFURL, UTType.jpeg.identifier as CFString, 1, nil
        ) else { return nil }
        CGImageDestinationAddImage(destination, image, [
            kCGImageDestinationLossyCompressionQuality: 0.8
        ] as CFDictionary)
        return CGImageDestinationFinalize(destination) ? fileURL : nil
    }
}
