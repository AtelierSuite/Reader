import Foundation

extension URL {

    private nonisolated static let fileLinkExtensions: Set<String> = [
        "pdf", "doc", "docx", "xls", "xlsx", "csv", "ppt", "pptx", "pps", "ppsx",
        "odt", "ods", "odp", "rtf", "pages", "numbers", "key", "epub", "mobi",
        "zip", "tar", "gz", "tgz", "bz2", "xz", "rar", "7z",
        "dmg", "pkg", "ipa", "apk", "exe", "msi", "iso", "deb", "rpm",
        "mp3", "m4a", "aac", "ogg", "oga", "wav", "flac", "opus", "wma",
        "mp4", "m4v", "mov", "avi", "mkv", "webm", "flv", "wmv",
        "jpg", "jpeg", "png", "gif", "webp", "svg", "bmp",
        "heic", "heif", "tiff", "tif", "avif"
    ]

    nonisolated var isFileLink: Bool {
        Self.fileLinkExtensions.contains(pathExtension.lowercased())
    }
}
