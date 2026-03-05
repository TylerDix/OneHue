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

                Section("Debug") {
                    Button("Reset Today Progress") {
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
