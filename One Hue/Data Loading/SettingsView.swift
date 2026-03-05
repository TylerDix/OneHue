import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: DailyArtworkStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("One Hue") {
                    Text("Free. No ads. Ever.")
                    Text("One image. One world. One day.")
                        .foregroundStyle(.secondary)
                }

                Section("Today") {
                    LabeledContent("Day") {
                        Text(store.artwork.id)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }

                    LabeledContent("Regions") {
                        Text("\(store.artwork.regions.count)")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }

                    LabeledContent("Colors") {
                        Text("\(store.artwork.palette.count)")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }

                Section("Debug") {
                    VStack(spacing: 10) {
                        HStack(spacing: 10) {
                            debugButton("Prev Day") { store.debugPrevDay() }
                            debugButton("Today") { store.debugBackToToday() }
                            debugButton("Next Day") { store.debugNextDay() }
                        }

                        Button(role: .destructive) {
                            store.resetThisDayProgress()
                        } label: {
                            Text("Reset This Day Progress")
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private func debugButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(.regular)
    }
}
