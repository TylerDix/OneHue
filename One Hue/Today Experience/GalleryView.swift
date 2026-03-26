import SwiftUI
import Combine

enum GalleryFilter: String, CaseIterable {
    case all = "All"
    case completed = "Completed"
    case inProgress = "In Progress"
}

struct GalleryView: View {
    @ObservedObject var store: ColoringStore
    @Environment(\.dismiss) private var dismiss
    @State private var filter: GalleryFilter = .all
    @State private var countdownText = ""
    @State private var timerCancellable: (any Cancellable)?
    private let timer = Timer.publish(every: 60, on: .main, in: .common)

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    // MARK: - Month-sectioned data

    private var sections: [GalleryMonthSection] {
        GalleryMonthSection.buildSections(filter: filter)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Filter bar
                Picker("Filter", selection: $filter) {
                    ForEach(GalleryFilter.allCases, id: \.self) { f in
                        Text(f.rawValue).tag(f)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

                if !countdownText.isEmpty {
                    Text(countdownText)
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundStyle(.white.opacity(0.35))
                        .padding(.top, 2)
                        .padding(.bottom, 4)
                }

                ScrollView(.vertical, showsIndicators: false) {
                    if sections.isEmpty {
                        Text(filter == .completed ? "No completed artworks yet" : "All artworks are completed!")
                            .font(.system(size: 15, weight: .regular, design: .rounded))
                            .foregroundStyle(.white.opacity(0.4))
                            .frame(maxWidth: .infinity)
                            .padding(.top, 60)
                    } else {
                        LazyVStack(spacing: 0) {
                            ForEach(sections) { section in
                                // Month header
                                Text(section.name)
                                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.4))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 20)
                                    .padding(.top, 24)
                                    .padding(.bottom, 8)

                                // 2-column grid for this month
                                LazyVGrid(columns: columns, spacing: 18) {
                                    ForEach(section.artworks, id: \.artwork.id) { item in
                                        GalleryCell(
                                            artwork: item.artwork,
                                            index: item.index,
                                            isCurrent: item.index == store.currentArtworkIndex,
                                            isToday: item.index == Artwork.today().index,
                                            onTap: {
                                                store.loadArtwork(at: item.index)
                                                dismiss()
                                            },
                                            onReset: item.index == store.currentArtworkIndex ? {
                                                store.resetProgress()
                                            } : nil
                                        )
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                        }
                        .padding(.top, 8)
                        .padding(.bottom, 40)
                    }
                }
            }
            .background(Color.black)
            .navigationTitle("Gallery")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 11, weight: .semibold))
                            Text("Back")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                        }
                    }
                    .accessibilityLabel("Return to artwork")
                }
            }
            .onAppear {
                SVGDocumentCache.shared.preloadAll()
                updateCountdown()
                timerCancellable = timer.connect()
            }
            .onDisappear {
                timerCancellable?.cancel()
                timerCancellable = nil
            }
            .onReceive(timer) { _ in
                updateCountdown()
            }
        }
    }

    // MARK: - Countdown

    private func updateCountdown() {
        var utcCal = Calendar(identifier: .gregorian)
        utcCal.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        let now = Date()
        guard let midnight = utcCal.nextDate(after: now, matching: DateComponents(hour: 0, minute: 0, second: 0), matchingPolicy: .nextTime) else {
            countdownText = ""
            return
        }
        let diff = utcCal.dateComponents([.hour, .minute], from: now, to: midnight)
        let h = diff.hour ?? 0
        let m = diff.minute ?? 0
        countdownText = "Next artwork in \(h)h \(m)m"
    }

    // Date helpers moved to GalleryMonthSection
}

// MARK: - Shared Section Model

struct GalleryMonthSection: Identifiable {
    let month: Int
    let name: String
    let artworks: [(index: Int, artwork: Artwork)]
    var id: Int { month }

    static func buildSections(filter: GalleryFilter) -> [GalleryMonthSection] {
        let todayOrd = currentDayOrdinal()

        let available: [(Int, Artwork)] = Artwork.catalog.enumerated().compactMap { index, artwork in
            guard artworkOrdinal(artwork) <= todayOrd else { return nil }
            let completed = ColoringStore.isArtworkCompleted(artwork.id)
            switch filter {
            case .all:        return (index, artwork)
            case .completed:  return completed ? (index, artwork) : nil
            case .inProgress: return !completed ? (index, artwork) : nil
            }
        }

        let grouped = Dictionary(grouping: available) { $0.1.month }
        return grouped.keys.sorted().map { month in
            GalleryMonthSection(
                month: month,
                name: monthName(for: month),
                artworks: grouped[month]!.map { (index: $0.0, artwork: $0.1) }
            )
        }
    }

    private static func currentDayOrdinal() -> Int {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        let now = Date()
        let m = cal.component(.month, from: now)
        let d = cal.component(.day, from: now)
        return dayOrdinal(month: m, day: d)
    }

    private static func artworkOrdinal(_ artwork: Artwork) -> Int {
        dayOrdinal(month: artwork.month, day: artwork.day)
    }

    private static func dayOrdinal(month: Int, day: Int) -> Int {
        let offsets = [0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334]
        guard month >= 1, month <= 12 else { return 1 }
        return offsets[month - 1] + day
    }

    private static let monthNames = [
        "January", "February", "March", "April", "May", "June",
        "July", "August", "September", "October", "November", "December"
    ]

    private static func monthName(for month: Int) -> String {
        guard month >= 1, month <= 12 else { return "" }
        return monthNames[month - 1]
    }
}

// MARK: - Cell

struct GalleryCell: View {
    let artwork: Artwork
    let index: Int
    let isCurrent: Bool
    var isToday: Bool = false
    let onTap: () -> Void
    var onReset: (() -> Void)?

    @State private var document: SVGDocument?
    @State private var appeared = false
    @State private var showResetConfirm = false

    private var isCompleted: Bool {
        ColoringStore.isArtworkCompleted(artwork.id)
    }

    /// Whether the artwork has any saved progress (filled or completed).
    private var hasProgress: Bool {
        isCompleted || !(UserDefaults.standard.array(forKey: "onehue.svg.\(artwork.id)") as? [Int] ?? []).isEmpty
    }

    /// Load saved fill progress for in-progress artworks
    private func savedProgress(for doc: SVGDocument) -> Set<Int> {
        if isCompleted { return Set(0..<doc.totalElements) }
        let array = UserDefaults.standard.array(forKey: "onehue.svg.\(doc.id)") as? [Int] ?? []
        return Set(array)
    }

    private var savedRating: Int? {
        let val = UserDefaults.standard.integer(forKey: "onehue.rated.\(artwork.id)")
        return val > 0 ? val : nil
    }

    private var dateStamp: String {
        let names = ["Jan","Feb","Mar","Apr","May","Jun",
                     "Jul","Aug","Sep","Oct","Nov","Dec"]
        guard artwork.month >= 1, artwork.month <= 12 else { return "" }
        return "\(names[artwork.month - 1]) \(artwork.day)"
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                // Thumbnail — portrait container using document's actual aspect ratio
                Color.black
                    .aspectRatio(document?.aspectRatio ?? (1200.0 / 1536.0), contentMode: .fit)
                    .overlay {
                        if let doc = document {
                            SVGCanvasRenderer(
                                document: doc,
                                filledElements: savedProgress(for: doc),
                                selectedGroupIndex: nil,
                                showNumbers: false,
                                isPeeking: false,
                                zoomLevel: 1.0,
                                activeAnimations: [],
                                flashTick: 0,
                                pulsePhase: 0,
                                strokeDissolve: 0
                            )
                            .drawingGroup()
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(
                                isCurrent ? .white.opacity(0.4) : .white.opacity(0.06),
                                lineWidth: isCurrent ? 1.5 : 0.5
                            )
                    )
                    .overlay(alignment: .topLeading) {
                        if isToday {
                            Text("Today")
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.9))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(
                                    Capsule().fill(.white.opacity(0.2))
                                )
                                .padding(6)
                        }
                    }
                    .overlay(alignment: .topTrailing) {
                        if isCompleted {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(.white.opacity(0.85))
                                .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                                .padding(8)
                        }
                    }
                    .overlay(alignment: .bottomLeading) {
                        Text(dateStamp)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.7))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(
                                Capsule().fill(.black.opacity(0.5))
                            )
                            .padding(6)
                    }

                // Name + rating
                HStack(spacing: 4) {
                    Text(artwork.displayName)
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(1)

                    Spacer(minLength: 0)

                    if savedRating != nil {
                        Image(systemName: "hand.thumbsup.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(.white.opacity(0.3))
                    }
                }
                .padding(.horizontal, 4)
                .padding(.top, 10)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(artwork.displayName), \(dateStamp)\(isCompleted ? ", completed" : "")\(isCurrent ? ", current" : "")\(savedRating != nil ? ", liked" : "")")
        .contextMenu {
            if hasProgress {
                Button(role: .destructive) {
                    showResetConfirm = true
                } label: {
                    Label("Start Over", systemImage: "arrow.counterclockwise")
                }
            }
        }
        .alert("Start Over?", isPresented: $showResetConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Start Over", role: .destructive) {
                ColoringStore.resetArtwork(artwork.id)
                onReset?()
                // Reload document to refresh thumbnail
                document = nil
                Task {
                    document = await Task.detached(priority: .userInitiated) {
                        SVGDocumentCache.shared.document(for: artwork)
                    }.value
                }
            }
        } message: {
            Text("This will erase all progress on \"\(artwork.displayName)\".")
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 12)
        .animation(.easeOut(duration: 0.3), value: appeared)
        .onAppear { appeared = true }
        .task {
            if document == nil {
                document = await Task.detached(priority: .userInitiated) {
                    SVGDocumentCache.shared.document(for: artwork)
                }.value
            }
        }
    }
}

#Preview("Gallery") {
    GalleryView(store: ColoringStore())
        .preferredColorScheme(.dark)
}
