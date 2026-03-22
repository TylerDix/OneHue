import Foundation

/// Lightweight Supabase client for One Hue.
/// No external SDK — just URLSession against the REST + RPC APIs.
/// Handles two things: the global completion counter and daily image metadata.
enum OneHueAPI {

    // MARK: - Configuration

    fileprivate static let projectURL = "https://hrtkbuycrqczilqwylxa.supabase.co"
    fileprivate static let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhydGtidXljcnFjemlscXd5bHhhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI2NjE3NDAsImV4cCI6MjA4ODIzNzc0MH0.WPOkcAjglsurujNjHRYtFQ4Jkyc3SMBpVCuffUeqiUM"

    // MARK: - Counter

    /// Fetch the current completion count for a given day.
    /// Returns 0 if the day doesn't exist yet or if the request fails.
    static func fetchCount(for dayID: String) async -> Int {
        guard let url = URL(string: "\(projectURL)/rest/v1/daily_counters?day_id=eq.\(dayID)&select=count") else {
            return 0
        }

        var request = URLRequest(url: url)
        request.addStandardHeaders()

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let rows = try JSONDecoder().decode([CounterRow].self, from: data)
            return rows.first?.count ?? 0
        } catch {
            #if DEBUG
            print("[OneHueAPI] fetchCount error: \(error.localizedDescription)")
            #endif
            return 0
        }
    }

    /// Atomically increment the completion counter for a given day.
    /// Creates the row if it doesn't exist. Returns the new count.
    static func incrementCount(for dayID: String) async -> Int {
        guard let url = URL(string: "\(projectURL)/rest/v1/rpc/increment_completion") else {
            return 0
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addStandardHeaders()
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: String] = ["p_day_id": dayID]
        request.httpBody = try? JSONEncoder().encode(body)

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            // RPC returns the integer directly
            if let count = try? JSONDecoder().decode(Int.self, from: data) {
                return count
            }
            return 0
        } catch {
            #if DEBUG
            print("[OneHueAPI] incrementCount error: \(error.localizedDescription)")
            #endif
            return 0
        }
    }

    // MARK: - Daily Image Metadata

    /// Fetch metadata for a given day's image (title, subject, completion message, palette).
    /// Returns nil if not found or request fails.
    static func fetchDailyImage(for dayID: String) async -> DailyImageDTO? {
        guard let url = URL(string: "\(projectURL)/rest/v1/daily_images?day_id=eq.\(dayID)&select=*") else {
            return nil
        }

        var request = URLRequest(url: url)
        request.addStandardHeaders()

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let rows = try JSONDecoder().decode([DailyImageDTO].self, from: data)
            return rows.first
        } catch {
            #if DEBUG
            print("[OneHueAPI] fetchDailyImage error: \(error.localizedDescription)")
            #endif
            return nil
        }
    }

    // MARK: - DTOs

    struct CounterRow: Decodable {
        let count: Int
    }

    struct DailyImageDTO: Decodable {
        let dayID: String
        let title: String
        let subject: String
        let message: String
        let palette: [String]  // hex strings
        let imageURL: String?

        enum CodingKeys: String, CodingKey {
            case dayID = "day_id"
            case title, subject, message, palette
            case imageURL = "image_url"
        }
    }

    // MARK: - Polling (for live count during completion screen)

    /// Polls the counter every `interval` seconds, calling `onUpdate` with the latest count.
    /// Returns a Task that can be cancelled to stop polling.
    @discardableResult
    static func pollCount(
        for dayID: String,
        interval: TimeInterval = 10,
        onUpdate: @escaping @MainActor (Int) -> Void
    ) -> Task<Void, Never> {
        Task {
            while !Task.isCancelled {
                let count = await fetchCount(for: dayID)
                await onUpdate(count)
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            }
        }
    }
}

// MARK: - URLRequest Extension

extension URLRequest {
    fileprivate mutating func addStandardHeaders() {
        setValue(OneHueAPI.anonKey, forHTTPHeaderField: "apikey")
        setValue("Bearer \(OneHueAPI.anonKey)", forHTTPHeaderField: "Authorization")
    }
}
