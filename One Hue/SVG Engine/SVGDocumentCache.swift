import Foundation

/// Thread-safe LRU cache for parsed SVG documents.
/// Prevents redundant re-parsing when gallery cells scroll in/out.
/// Caps at `maxEntries` to avoid unbounded memory growth.
final class SVGDocumentCache: @unchecked Sendable {
    static let shared = SVGDocumentCache()

    private var cache: [String: SVGDocument] = [:]
    /// Access order for LRU eviction (most recent at end).
    private var accessOrder: [String] = []
    private let lock = NSLock()

    /// Maximum cached documents. ~20 docs keeps memory under ~100 MB.
    private let maxEntries = 20

    private var memoryObserver: NSObjectProtocol?

    private init() {
        memoryObserver = NotificationCenter.default.addObserver(
            forName: memoryWarningNotification,
            object: nil, queue: nil
        ) { [weak self] _ in
            self?.evictAll()
        }
    }

    /// Returns a cached document or parses + caches it.
    func document(for artwork: Artwork) -> SVGDocument? {
        lock.lock()
        if let cached = cache[artwork.id] {
            // Move to end of access order (most recently used)
            if let idx = accessOrder.firstIndex(of: artwork.id) {
                accessOrder.remove(at: idx)
            }
            accessOrder.append(artwork.id)
            lock.unlock()
            return cached
        }
        lock.unlock()

        // Parse outside the lock to avoid blocking other reads
        guard let doc = SVGParser.parse(artwork: artwork) else { return nil }

        lock.lock()
        cache[artwork.id] = doc
        accessOrder.append(artwork.id)
        // Evict oldest entries if over limit
        while cache.count > maxEntries, let oldest = accessOrder.first {
            accessOrder.removeFirst()
            cache.removeValue(forKey: oldest)
        }
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

    /// Drop all cached documents (called on memory warning).
    private func evictAll() {
        lock.lock()
        cache.removeAll()
        accessOrder.removeAll()
        lock.unlock()
    }
}
