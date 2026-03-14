import Foundation
import Combine

/// Lightweight Supabase REST client for tracking global completion counts.
/// Fully anonymous — uses a random device UUID stored in UserDefaults.
@MainActor
final class CompletionService: ObservableObject {

    static let shared = CompletionService()

    // MARK: - Published

    @Published private(set) var globalCount: Int?
    @Published private(set) var countryFlags: [String]?

    // MARK: - Config

    private let baseURL = "https://hrtkbuycrqczilqwylxa.supabase.co/rest/v1"
    private let apiKey  = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhydGtidXljcnFjemlscXd5bHhhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI2NjE3NDAsImV4cCI6MjA4ODIzNzc0MH0.WPOkcAjglsurujNjHRYtFQ4Jkyc3SMBpVCuffUeqiUM"

    private var deviceID: String {
        if let existing = UserDefaults.standard.string(forKey: "onehue.deviceID") {
            return existing
        }
        let new = UUID().uuidString
        UserDefaults.standard.set(new, forKey: "onehue.deviceID")
        return new
    }

    private init() {}

    // MARK: - Report Completion

    /// Reports that this device completed the given artwork today.
    /// Uses INSERT with ON CONFLICT (unique index) so duplicates are ignored.
    func reportCompletion(artworkID: String) async {
        guard let url = URL(string: "\(baseURL)/daily_completions") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // return=minimal avoids sending back data; resolution=ignore-duplicates
        // handles the unique constraint gracefully
        request.setValue("return=minimal, resolution=ignore-duplicates", forHTTPHeaderField: "Prefer")

        let body: [String: String] = [
            "artwork_id": artworkID,
            "completed_date": Self.todayUTC(),
            "device_id": deviceID
        ]
        request.httpBody = try? JSONEncoder().encode(body)

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            if status == 201 || status == 200 || status == 409 {
                // Success or duplicate — either way, fetch the updated count
                await fetchCount(artworkID: artworkID)
                // Best-effort: attach country code to this row
                await patchCountryCode(artworkID: artworkID)
                await fetchCountryFlags(artworkID: artworkID)
            }
        } catch {
            // Silent failure — offline is fine
        }
    }

    // MARK: - Country Code

    /// Best-effort PATCH to set country_code on our completion row.
    /// Silently fails if the column doesn't exist yet.
    private func patchCountryCode(artworkID: String) async {
        let code = Locale.current.region?.identifier ?? ""
        guard !code.isEmpty else { return }

        let today = Self.todayUTC()
        let filter = "device_id=eq.\(deviceID)&artwork_id=eq.\(artworkID)&completed_date=eq.\(today)"
        guard let url = URL(string: "\(baseURL)/daily_completions?\(filter)") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue(apiKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        request.httpBody = try? JSONEncoder().encode(["country_code": code])

        _ = try? await URLSession.shared.data(for: request)
    }

    /// Fetches distinct country codes for today's completions and converts to flag emojis.
    func fetchCountryFlags(artworkID: String) async {
        let today = Self.todayUTC()
        let query = "artwork_id=eq.\(artworkID)&completed_date=eq.\(today)&select=country_code"
        guard let url = URL(string: "\(baseURL)/daily_completions?\(query)") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(apiKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard status == 200 else { return }

            if let rows = try? JSONDecoder().decode([[String: String?]].self, from: data) {
                let codes = Set(rows.compactMap { $0["country_code"] ?? nil })
                let flags = codes.compactMap { Self.flag(from: $0) }.sorted()
                if !flags.isEmpty {
                    self.countryFlags = flags
                }
            }
        } catch {
            // Silent failure
        }
    }

    /// Converts a 2-letter country code (e.g. "US") into a flag emoji.
    private static func flag(from code: String) -> String? {
        let upper = code.uppercased()
        guard upper.count == 2 else { return nil }
        let base: UInt32 = 0x1F1E6 - 65  // regional indicator A
        return String(upper.unicodeScalars.compactMap {
            UnicodeScalar(base + $0.value)
        }.map { Character($0) })
    }

    // MARK: - Fetch Count

    /// Fetches how many unique devices completed this artwork today.
    func fetchCount(artworkID: String) async {
        let today = Self.todayUTC()
        let query = "artwork_id=eq.\(artworkID)&completed_date=eq.\(today)&select=count"
        guard let url = URL(string: "\(baseURL)/daily_completions?\(query)") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(apiKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("count=exact", forHTTPHeaderField: "Prefer")

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            if let rows = try? JSONDecoder().decode([[String: Int]].self, from: data),
               let count = rows.first?["count"] {
                self.globalCount = count
            }
        } catch {
            // Silent failure — count stays nil (offline)
        }
    }

    // MARK: - Submit Feedback

    /// Submits a star rating and optional comment for an artwork.
    func submitFeedback(artworkID: String, rating: Int, comment: String) async {
        guard let url = URL(string: "\(baseURL)/artwork_feedback") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("return=minimal", forHTTPHeaderField: "Prefer")

        let body: [String: Any] = [
            "device_id": deviceID,
            "artwork_id": artworkID,
            "rating": rating,
            "comment": comment
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (_, _) = try await URLSession.shared.data(for: request)
        } catch {
            // Silent failure — offline is fine
        }
    }

    // MARK: - Helpers

    /// Everything anchored to UTC so the whole world shares the same "day".
    static func todayUTC() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "UTC")
        return f.string(from: Date())
    }
}
