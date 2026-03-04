import Foundation

struct GitHubRelease: Decodable, Sendable {
  let tagName: String
  let name: String?
  let htmlUrl: String
  let publishedAt: String?
  let body: String?

  enum CodingKeys: String, CodingKey {
    case tagName = "tag_name"
    case name
    case htmlUrl = "html_url"
    case publishedAt = "published_at"
    case body
  }
}

@MainActor
enum UpdateChecker {
  static var currentVersion: String {
    Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
  }

  static var buildNumber: String {
    Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
  }

  nonisolated static func fetchLatestChangelog() async -> (version: String, changelog: String)? {
    let urlString = "https://api.github.com/repos/jkuri/Reframed/releases/latest"
    guard let url = URL(string: urlString) else { return nil }

    var request = URLRequest(url: url)
    request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
    request.timeoutInterval = 10

    do {
      let (data, response) = try await URLSession.shared.data(for: request)
      guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
        return nil
      }
      let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
      let version = release.tagName.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
      return (version, release.body ?? "")
    } catch {
      return nil
    }
  }
}
