import Foundation

/// Thread-safe cache for parsed SVG documents.
/// Prevents redundant re-parsing when gallery cells scroll in/out.
final class SVGDocumentCache: @unchecked Sendable {
    static let shared = SVGDocumentCache()

    private var cache: [String: SVGDocument] = [:]
    private let lock = NSLock()

    /// Returns a cached document or parses + caches it.
    func document(for artwork: Artwork) -> SVGDocument? {
        lock.lock()
        if let cached = cache[artwork.id] {
            lock.unlock()
            return cached
        }
        lock.unlock()

        // Parse outside the lock to avoid blocking other reads
        guard let doc = SVGParser.parse(artwork: artwork) else { return nil }

        lock.lock()
        cache[artwork.id] = doc
        lock.unlock()
        return doc
    }

    /// Preloads all artworks in the background.
    func preloadAll() {
        let catalog = Artwork.catalog
        DispatchQueue.global(qos: .userInitiated).async {
            for artwork in catalog {
                _ = self.document(for: artwork)
            }
        }
    }

    /// Check if a document is already cached (non-blocking).
    func hasCached(_ artworkID: String) -> Bool {
        lock.lock()
        let result = cache[artworkID] != nil
        lock.unlock()
        return result
    }

    /// Returns a cached document without parsing. Returns nil if not yet cached.
    func peekDocument(for artwork: Artwork) -> SVGDocument? {
        lock.lock()
        let doc = cache[artwork.id]
        lock.unlock()
        return doc
    }
}
