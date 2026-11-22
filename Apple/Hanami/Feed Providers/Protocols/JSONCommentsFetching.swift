import Foundation

/// Shared plumbing for comment sources that answer one JSON request per entry.
nonisolated enum JSONCommentsFetching {

    static func decode<Response: Decodable>(
        _ type: Response.Type, from request: URLRequest, source: String
    ) async throws -> Response? {
        let (data, response) = try await URLSession.shared.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        log("Comments", "\(source) \(request.url?.absoluteString ?? "") status=\(statusCode) bytes=\(data.count)")
        guard statusCode == 200 else { return nil }
        return try JSONDecoder().decode(type, from: data)
    }

    static func date(_ string: String?) -> Date? {
        string.flatMap { RSSParser().parseDate($0) }
    }
}
