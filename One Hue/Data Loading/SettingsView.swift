import SwiftUI
import UserNotifications

struct SettingsView: View {
    @ObservedObject var store: ColoringStore
    @Environment(\.dismiss) private var dismiss

    @AppStorage("onehue.dailyReminder") private var dailyReminderEnabled = false
    @AppStorage("onehue.soundEnabled") private var soundEnabled = true
    @State private var showAbout = false
    #if DEBUG
    // Always-on in DEBUG builds (no longer gated by 5-tap tagline) so testing
    // tools are one tap away.
    @State private var showDebug = true
    @State private var jumpText: String = ""
    #endif

    var body: some View {
        NavigationStack {
            List {
                // 1. Daily reminder
                Section {
                    Toggle(isOn: $dailyReminderEnabled) {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Daily Reminder")
                                Text("A quiet nudge, once a day")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "bell")
                                .foregroundStyle(.white.opacity(0.7))
                        }
                    }
                    .onChange(of: dailyReminderEnabled) { _, enabled in
                        if enabled { requestAndScheduleReminder() }
                        else { cancelReminder() }
                    }
                }

                // 2. Sound
                Section {
                    Toggle(isOn: $soundEnabled) {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Fill Sound")
                                Text("A soft tap when you paint")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: soundEnabled ? "speaker.wave.2" : "speaker.slash")
                                .foregroundStyle(.white.opacity(0.7))
                        }
                    }
                }

                // 3. About (contains tip jar)
                Section {
                    NavigationLink {
                        AboutView()
                    } label: {
                        Label {
                            Text("About One Hue")
                        } icon: {
                            Image(systemName: "info.circle")
                                .foregroundStyle(.white.opacity(0.7))
                        }
                    }
                }

                // 4. Tagline
                Section {
                    VStack(spacing: 6) {
                        Text("One Hue")
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.9))
                        Text("No ads. No tracking. Ever.")
                            .font(.system(size: 14, weight: .regular, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .listRowBackground(Color.clear)
                }

                #if DEBUG
                if showDebug {
                    // Navigation
                    Section("Navigation") {
                        HStack {
                            Button { store.previousArtwork() } label: {
                                Image(systemName: "chevron.left")
                                    .fontWeight(.bold)
                                    .frame(width: 44, height: 36)
                            }
                            .buttonStyle(.bordered)

                            Spacer()

                            let idx = store.currentArtworkIndex + 1
                            let total = Artwork.catalog.count
                            Text("\(idx) / \(total)")
                                .font(.system(.body, design: .monospaced))
                                .fontWeight(.semibold)

                            Spacer()

                            Button { store.nextArtwork() } label: {
                                Image(systemName: "chevron.right")
                                    .fontWeight(.bold)
                                    .frame(width: 44, height: 36)
                            }
                            .buttonStyle(.bordered)
                        }

                        HStack {
                            TextField("Jump to #", text: $jumpText)
                                #if !os(macOS)
                                .keyboardType(.numberPad)
                                #endif
                                .font(.system(.body, design: .monospaced))
                                .textFieldStyle(.roundedBorder)
                                .frame(maxWidth: 120)

                            Button("Go") {
                                if let num = Int(jumpText), num >= 1, num <= Artwork.catalog.count {
                                    store.loadArtwork(at: num - 1)
                                    jumpText = ""
                                    dismiss()
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(Int(jumpText).map { $0 >= 1 && $0 <= Artwork.catalog.count } != true)

                            Spacer()
                        }
                    }
                    .transition(.opacity)

                    // Artwork info
                    Section("Artwork") {
                        LabeledContent("ID") {
                            Text(store.currentArtwork.id)
                                .foregroundStyle(.secondary)
                                .font(.system(.caption, design: .monospaced))
                        }
                        LabeledContent("Name") {
                            Text(store.currentArtwork.displayName)
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }
                        LabeledContent("Elements") {
                            Text("\(store.filledElements.count) / \(store.document.totalElements)")
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        LabeledContent("Groups") {
                            Text("\(store.document.groups.count)")
                                .foregroundStyle(.secondary)
                        }
                        LabeledContent("Clusters") {
                            Text("\(store.document.clusters.count)")
                                .foregroundStyle(.secondary)
                        }
                        LabeledContent("Phase") {
                            Text(store.phase == .painting ? "🎨 painting" : "✅ complete")
                                .foregroundStyle(.secondary)
                        }
                        let vb = store.document.viewBox
                        LabeledContent("ViewBox") {
                            Text(String(format: "%.0f×%.0f", vb.width, vb.height))
                                .foregroundStyle(.secondary)
                                .font(.system(.caption, design: .monospaced))
                        }
                        LabeledContent("Aspect") {
                            Text(String(format: "%.3f", store.document.aspectRatio) +
                                (store.document.aspectRatio > 0.99 && store.document.aspectRatio < 1.01 ? " ■" : ""))
                                .foregroundStyle(.secondary)
                                .font(.system(.caption, design: .monospaced))
                        }
                    }
                    .transition(.opacity)

                    // Canvas debug
                    Section("Canvas") {
                        let d = store.canvasDebug
                        LabeledContent("Viewport") {
                            Text(String(format: "%.0f × %.0f", d.viewportSize.width, d.viewportSize.height))
                                .foregroundStyle(.secondary)
                                .font(.system(.caption, design: .monospaced))
                        }
                        LabeledContent("Render") {
                            Text(String(format: "%.0f × %.0f", d.renderSize.width, d.renderSize.height))
                                .foregroundStyle(.secondary)
                                .font(.system(.caption, design: .monospaced))
                        }
                        LabeledContent("Zoom") {
                            Text(String(format: "%.2f×", d.zoom))
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                    }
                    .transition(.opacity)

                    // Actions
                    Section("Actions") {
                        Button("Nearly Complete (5 left)") {
                            store.debugNearlyComplete()
                            dismiss()
                        }
                        .tint(.orange)

                        Button("Fill All (instant complete)") {
                            store.fillAll()
                            dismiss()
                        }
                        .tint(.green)

                        Button("Force Complete") {
                            store.debugForceComplete()
                            dismiss()
                        }
                        .tint(.blue)

                        Button(role: .destructive) {
                            store.resetProgress()
                        } label: {
                            Text("Reset Progress")
                        }
                    }
                    .transition(.opacity)
                }
                #endif

            }
            .scrollContentBackground(.hidden)
            .background(Color.appBackground)
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Notifications

    private func requestAndScheduleReminder() {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound]) { granted, _ in
                DispatchQueue.main.async {
                    if granted { scheduleDaily() }
                    else { dailyReminderEnabled = false }
                }
            }
    }

    private func scheduleDaily() {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()

        let content = UNMutableNotificationContent()
        content.title = "One Hue"
        content.body  = "A moment of color awaits."
        content.sound = .default

        var dc = DateComponents()
        dc.hour = 9; dc.minute = 0

        center.add(UNNotificationRequest(
            identifier: "onehue.daily",
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: dc, repeats: true)
        ))
    }

    private func cancelReminder() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}

// MARK: - About

struct AboutView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                Spacer(minLength: 20)

                VStack(spacing: 8) {
                    Text("One Hue")
                        .font(.system(size: 32, weight: .light, design: .serif))
                        .foregroundStyle(.white.opacity(0.9))
                    Text("The whole world colors the same page.")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(.white.opacity(0.5))
                }

                VStack(spacing: 16) {
                    aboutParagraph("A new artwork appears each day — the same one for everyone. Pick a color, tap the numbered regions, and watch it come\u{00A0}alive.")
                    aboutParagraph("No ads. No accounts. No subscriptions. Just color, quiet, and a small thought at the\u{00A0}end.")
                    aboutParagraph("Made by one person who wanted something calm to do with\u{00A0}his\u{00A0}hands.")
                }
                .padding(.horizontal, 28)

                VStack(spacing: 18) {
                    Rectangle()
                        .fill(.white.opacity(0.06))
                        .frame(width: 56, height: 0.5)
                    Text("For Joelle Kline")
                        .font(.system(size: 15, weight: .regular, design: .serif))
                        .foregroundStyle(.white.opacity(0.45))
                        .italic()
                }
                .padding(.top, 32)

                Spacer(minLength: 60)
            }
        }
        .background(Color.appBackground)
        .navigationTitle("About")
        #if !os(macOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private func aboutParagraph(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 15, weight: .regular))
            .foregroundStyle(.white.opacity(0.7))
            .lineSpacing(4)
            .multilineTextAlignment(.center)
    }
}

// MARK: - Previews

#Preview("Settings") {
    SettingsView(store: ColoringStore())
        .preferredColorScheme(.dark)
}

#Preview("About") {
    NavigationStack { AboutView() }
        .preferredColorScheme(.dark)
}
