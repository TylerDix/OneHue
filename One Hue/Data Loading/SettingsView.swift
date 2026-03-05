import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: DailyArtworkStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("One Hue") {
                    Text("Free. No ads. Ever.")
                    Text("A daily calm coloring space.")
                        .foregroundStyle(.secondary)
                }

                Section("Daily") {
                    Text("Day ID: \(store.artwork.id)")
                        .foregroundStyle(.secondary)
                }

                Section("Debug") {
                    HStack {
                        Button("Prev Day") { store.debugPrevDay() }
                        Spacer()
                        Button("Today") { store.debugBackToToday() }
                        Spacer()
                        Button("Next Day") { store.debugNextDay() }
                    }

                    Button("Reset This Day Progress") {
                        store.resetToday()
                    }
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
}
