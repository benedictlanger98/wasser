import Foundation

/// Minimal async HTTP transport. Injected into scrapers so they can be unit
/// tested with a stub client and so the User-Agent / headers policy lives in
/// one place (GKD rejects requests without a browser-like User-Agent).
protocol HTTPClient: Sendable {
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

extension HTTPClient {
    /// Convenience GET that returns the response body decoded as UTF-8 text
    /// (with a Latin-1 fallback, since some GKD pages are ISO-8859-1).
    func getText(_ url: URL, headers: [String: String] = [:]) async throws -> String {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        for (key, value) in headers { request.setValue(value, forHTTPHeaderField: key) }
        let (data, response) = try await data(for: request)
        guard (200..<300).contains(response.statusCode) else {
            throw DataSourceError.http(status: response.statusCode, url: url)
        }
        if let utf8 = String(data: data, encoding: .utf8) { return utf8 }
        if let latin1 = String(data: data, encoding: .isoLatin1) { return latin1 }
        throw DataSourceError.decoding("Could not decode response body as text")
    }

    func getJSON<T: Decodable>(_ type: T.Type,
                               url: URL,
                               headers: [String: String] = [:],
                               decoder: JSONDecoder = JSONDecoder()) async throws -> T {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        for (key, value) in headers { request.setValue(value, forHTTPHeaderField: key) }
        let (data, response) = try await data(for: request)
        guard (200..<300).contains(response.statusCode) else {
            throw DataSourceError.http(status: response.statusCode, url: url)
        }
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw DataSourceError.decoding(String(describing: error))
        }
    }
}

/// Default `URLSession`-backed client that applies a browser-like User-Agent
/// and sensible language headers required by gkd.bayern.de.
struct URLSessionHTTPClient: HTTPClient {
    let session: URLSession
    let defaultHeaders: [String: String]

    init(session: URLSession = .shared,
         defaultHeaders: [String: String] = URLSessionHTTPClient.browserHeaders) {
        self.session = session
        self.defaultHeaders = defaultHeaders
    }

    static let browserHeaders: [String: String] = [
        "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
            + "AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15",
        "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
        "Accept-Language": "de-DE,de;q=0.9,en;q=0.8"
    ]

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        var request = request
        for (key, value) in defaultHeaders where request.value(forHTTPHeaderField: key) == nil {
            request.setValue(value, forHTTPHeaderField: key)
        }
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw DataSourceError.transport("Non-HTTP response")
            }
            return (data, http)
        } catch let error as DataSourceError {
            throw error
        } catch {
            throw DataSourceError.transport(error.localizedDescription)
        }
    }
}
