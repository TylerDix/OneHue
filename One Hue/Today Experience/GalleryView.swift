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
    private let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    // MARK: - Month-sectioned data

    private struct MonthSection: Identifiable {
        let month: Int
        let name: String
        let artworks: [(index: Int, artwork: Artwork)]
        var id: Int { month }
    }

    private var sections: [MonthSection] {
        let todayOrd = currentDayOrdinal()

        let available: [(Int, Artwork)] = Artwork.catalog.enumerated().compactMap { index, artwork in
            // Only show artworks whose anchor date has arrived
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
            MonthSection(
                month: month,
                name: Self.monthName(for: month),
                artworks: grouped[month]!.map { (index: $0.0, artwork: $0.1) }
            )
        }
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

                ScrollView {
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
                                            isToday: item.index == Artwork.today().index
                                        ) {
                                            store.loadArtwork(at: item.index)
                                            dismiss()
                                        }
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
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        store.loadArtwork(at: Artwork.today().index)
                        dismiss()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 11, weight: .semibold))
                            Text("Today")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                        }
                    }
                    .accessibilityLabel("Return to today's artwork")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                SVGDocumentCache.shared.preloadAll()
                updateCountdown()
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

    // MARK: - Date Helpers

    private func currentDayOrdinal() -> Int {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        let now = Date()
        let m = cal.component(.month, from: now)
        let d = cal.component(.day, from: now)
        return Self.dayOrdinal(month: m, day: d)
    }

    private func artworkOrdinal(_ artwork: Artwork) -> Int {
        Self.dayOrdinal(month: artwork.month, day: artwork.day)
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

private struct GalleryCell: View {
    let artwork: Artwork
    let index: Int
    let isCurrent: Bool
    var isToday: Bool = false
    let onTap: () -> Void

    @State private var document: SVGDocument?
    @State private var appeared = false

    private var isCompleted: Bool {
        ColoringStore.isArtworkCompleted(artwork.id)
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
                                filledElements: Set(0..<doc.totalElements),
                                selectedGroupIndex: nil,
                                showNumbers: false,
                                isPeeking: false,
                                zoomLevel: 1.0,
                                activeAnimations: [],
                                flashTick: 0,
                                pulsePhase: 0
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
