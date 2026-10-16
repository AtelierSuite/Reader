import Foundation

extension InstagramProvider {
    func buildPostsRequest(
        username: String, query: InstagramPostsQuery,
        bootstrap: InstagramProfileBootstrap, cookies: InstagramCookies
    ) throws -> URLRequest {
        guard let url = URL(string: "https://www.instagram.com/graphql/query") else {
            throw URLError(.badURL)
        }
        let queryName = "PolarisProfilePostsQuery"
        var variables: [String: Any] = [
            "username": username,
            "data": [
                "count": Self.targetPostCount,
                "include_reel_media_seen_timestamp": true,
                "include_relationship_info": true,
                "latest_besties_reel_media": true,
                "latest_reel_media": true
            ]
        ]
        variables.merge(query.relayProviderVariables) { current, _ in current }
        let variablesData = try JSONSerialization.data(withJSONObject: variables)
        guard let variablesJSON = String(data: variablesData, encoding: .utf8) else {
            throw InstagramFetchError.invalidResponse
        }
        var parameters = [
            "__a": "1", "__d": "www", "__user": "0", "__comet_req": "7",
            "lsd": bootstrap.lsdToken,
            "fb_api_caller_class": "RelayModern",
            "fb_api_req_friendly_name": queryName,
            "doc_id": query.docID,
            "variables": variablesJSON
        ]
        if let dtsgToken = bootstrap.dtsgToken {
            parameters["fb_dtsg"] = dtsgToken
        }
        var components = URLComponents()
        components.queryItems = parameters.sorted { $0.key < $1.key }.map {
            URLQueryItem(name: $0.key, value: $0.value)
        }
        guard let body = components.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B") else {
            throw InstagramFetchError.invalidResponse
        }
        var request = buildRequest(url: url, cookies: cookies, referer: "https://www.instagram.com/\(username)/")
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue(queryName, forHTTPHeaderField: "x-fb-friendly-name")
        request.setValue(bootstrap.lsdToken, forHTTPHeaderField: "x-fb-lsd")
        request.httpBody = Data(body.utf8)
        return request
    }
}
