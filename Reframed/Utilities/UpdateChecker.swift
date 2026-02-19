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

enum UpdateStatus: Sendable {
  case upToDate
  case available(version: String, url: String)
  case error(String)
}

@MainActor
enum UpdateChecker {
  static var currentVersion: String {
    Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
  }

  static var buildNumber: String {
    Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
  }

  nonisolated static func checkForUpdates() async -> UpdateStatus {
    let urlString = "https://api.github.com/repos/jkuri/Reframed/releases/latest"
    guard let url = URL(string: urlString) else {
      return .error("Invalid URL")
    }

    var request = URLRequest(url: url)
    request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
    request.timeoutInterval = 10

    do {
      let (data, response) = try await URLSession.shared.data(for: request)

      guard let httpResponse = response as? HTTPURLResponse else {
        return .error("Invalid response")
      }

      if httpResponse.statusCode == 404 {
        return .error("No releases found")
      }

      guard httpResponse.statusCode == 200 else {
        return .error("GitHub API error (\(httpResponse.statusCode))")
      }

      let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
      let latestVersion = release.tagName.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
      let current = await currentVersion

      if compareVersions(latestVersion, isNewerThan: current) {
        return .available(version: latestVersion, url: release.htmlUrl)
      } else {
        return .upToDate
      }
    } catch is CancellationError {
      return .error("Request cancelled")
    } catch {
      return .error(error.localizedDescription)
    }
  }

  nonisolated private static func compareVersions(_ latest: String, isNewerThan current: String) -> Bool {
    let latestParts = latest.split(separator: ".").compactMap { Int($0) }
    let currentParts = current.split(separator: ".").compactMap { Int($0) }

    let maxCount = max(latestParts.count, currentParts.count)
    for i in 0..<maxCount {
      let l = i < latestParts.count ? latestParts[i] : 0
      let c = i < currentParts.count ? currentParts[i] : 0
      if l > c { return true }
      if l < c { return false }
    }
    return false
  }
}
