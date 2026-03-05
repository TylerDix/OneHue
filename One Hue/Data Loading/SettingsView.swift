import SwiftUI
import UserNotifications

struct SettingsView: View {
    @ObservedObject var store: DailyArtworkStore
    @Environment(\.dismiss) private var dismiss

    @AppStorage("onehue.dailyReminder") private var dailyReminderEnabled = false
    @State private var showAbout = false
    @State private var debugTapCount = 0
    @State private var showDebug = false

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

                // 2. About
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

                // 3. Tagline
                Section {
                    VStack(spacing: 6) {
                        Text("One Hue")
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.9))
                        Text("Free. No ads. Ever.")
                            .font(.system(size: 14, weight: .regular, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .listRowBackground(Color.clear)
                    .onTapGesture {
                        debugTapCount += 1
                        if debugTapCount >= 5 { showDebug = true; debugTapCount = 0 }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { debugTapCount = 0 }
                    }
                }

                // Debug (hidden until 5-tap)
                if showDebug {
                    Section("Debug") {
                        VStack(spacing: 10) {
                            HStack(spacing: 10) {
                                debugButton("Prev Day") { store.debugPrevDay() }
                                debugButton("Today")    { store.debugBackToToday() }
                                debugButton("Next Day") { store.debugNextDay() }
                            }

                            Button(role: .destructive) {
                                store.resetThisDayProgress()
                            } label: {
                                Text("Reset This Day Progress")
                                    .frame(maxWidth: .infinity, alignment: .center)
                            }
                            .buttonStyle(.bordered)

                            Button {
                                store.debugForceComplete()
                                dismiss()
                            } label: {
                                Text("Force Complete")
                                    .frame(maxWidth: .infinity, alignment: .center)
                            }
                            .buttonStyle(.bordered)

                            LabeledContent("Day") {
                                Text(store.artwork.id)
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                            LabeledContent("Grid") {
                                Text("\(store.artwork.cols)×\(store.artwork.rows)")
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                            LabeledContent("Fillable cells") {
                                Text("\(store.artwork.fillableCellCount)")
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                            LabeledContent("Colors") {
                                Text("\(store.artwork.palette.count)")
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                            LabeledContent("Phase") {
                                Text("\(store.phase)")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
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

    // MARK: - Debug Button

    @ViewBuilder
    private func debugButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(.regular)
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
        content.body  = "Today's image is waiting."
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
                    Text("One image. One world. One day.")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(.white.opacity(0.5))
                }

                VStack(spacing: 16) {
                    aboutParagraph("Every day, one image appears — the same image for every person on Earth. You color it in. When you finish, you see how many others did too. Then the app goes quiet until tomorrow.")
                    aboutParagraph("There are no streaks, no leaderboards, no points. No ads, no accounts, no profiles. Nothing to optimize. Just a single daily act of focus and beauty, shared with the world.")
                    aboutParagraph("The intent is simple: one moment of sustained attention in a world that takes it from you constantly.")
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
                .padding(.top, 48)

                Spacer(minLength: 60)
            }
        }
        .background(.black)
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
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
    SettingsView(store: DailyArtworkStore())
        .preferredColorScheme(.dark)
}

#Preview("About") {
    NavigationStack { AboutView() }
        .preferredColorScheme(.dark)
}
