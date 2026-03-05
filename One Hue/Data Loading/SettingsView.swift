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
                    LabeledContent("Day ID") {
                        Text(store.artwork.id)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }

                    LabeledContent("Debug offset") {
                        Text("\(store.debugDayOffset)")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }

                Section("Debug") {
                    // Use a VStack of full-width buttons: much more reliable than
                    // multiple small buttons in one Form row.
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

    // MARK: - Helpers

    @ViewBuilder
    private func debugButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .frame(maxWidth: .infinity)
        }
        // These styles are the key to making taps reliable in Form.
        .buttonStyle(.bordered)
        .controlSize(.regular)
    }
}
