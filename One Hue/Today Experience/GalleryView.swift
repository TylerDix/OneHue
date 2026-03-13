import SwiftUI

enum GalleryFilter: String, CaseIterable {
    case all = "All"
    case completed = "Completed"
    case inProgress = "In Progress"
}

struct GalleryView: View {
    @ObservedObject var store: ColoringStore
    @Environment(\.dismiss) private var dismiss
    @State private var filter: GalleryFilter = .all

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    private var filteredArtworks: [(index: Int, artwork: Artwork)] {
        Artwork.catalog.enumerated().compactMap { index, artwork in
            let completed = ColoringStore.isArtworkCompleted(artwork.id)
            switch filter {
            case .all:
                return (index, artwork)
            case .completed:
                return completed ? (index, artwork) : nil
            case .inProgress:
                return !completed ? (index, artwork) : nil
            }
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

                ScrollView {
                    if filteredArtworks.isEmpty {
                        Text(filter == .completed ? "No completed artworks yet" : "All artworks are completed!")
                            .font(.system(size: 15, weight: .regular, design: .rounded))
                            .foregroundStyle(.white.opacity(0.4))
                            .frame(maxWidth: .infinity)
                            .padding(.top, 60)
                    } else {
                        LazyVGrid(columns: columns, spacing: 18) {
                            ForEach(filteredArtworks, id: \.artwork.id) { item in
                                GalleryCell(
                                    artwork: item.artwork,
                                    index: item.index,
                                    isCurrent: item.index == store.currentArtworkIndex
                                ) {
                                    store.loadArtwork(at: item.index)
                                    dismiss()
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 40)
                    }
                }
            }
            .background(Color.black)
            .navigationTitle("Gallery")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                SVGDocumentCache.shared.preloadAll()
            }
        }
    }
}

// MARK: - Cell

private struct GalleryCell: View {
    let artwork: Artwork
    let index: Int
    let isCurrent: Bool
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

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                // Thumbnail — portrait container matching cropped viewBox ratio
                Color.black
                    .aspectRatio(1200.0 / 1541.0, contentMode: .fit)
                    .overlay {
                        if let doc = document {
                            SVGCanvasRenderer(
                                document: doc,
                                filledElements: Set(0..<doc.totalElements),
                                selectedGroupIndex: 0,
                                showNumbers: false,
                                zoomLevel: 1.0,
                                activeAnimations: [],
                                flashTick: 0
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
                    .overlay(alignment: .topTrailing) {
                        if isCompleted {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(.white.opacity(0.85))
                                .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                                .padding(8)
                        }
                    }

                // Name + rating
                HStack(spacing: 4) {
                    Text(artwork.displayName)
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(1)

                    Spacer(minLength: 0)

                    if let rating = savedRating {
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 9))
                            Text("\(rating)")
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                        }
                        .foregroundStyle(.white.opacity(0.3))
                    }
                }
                .padding(.horizontal, 4)
                .padding(.top, 10)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(artwork.displayName)\(isCompleted ? ", completed" : "")\(isCurrent ? ", current" : "")\(savedRating.map { ", rated \($0) stars" } ?? "")")
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
