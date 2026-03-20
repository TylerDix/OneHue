import StoreKit
import SwiftUI
import UserNotifications

struct SettingsView: View {
    @ObservedObject var store: ColoringStore
    @Environment(\.dismiss) private var dismiss

    @AppStorage("onehue.dailyReminder") private var dailyReminderEnabled = false
    @AppStorage("onehue.soundEnabled") private var soundEnabled = true
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

                // 4. Tagline (5-tap reveals debug)
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
                        if debugTapCount >= 5 {
                            withAnimation { showDebug = true }
                        }
                    }
                }

                // Hidden debug (only after 5-tap)
                if showDebug {
                    Section("Dev") {
                        VStack(spacing: 10) {
                            HStack {
                                Button { store.previousArtwork() } label: {
                                    Image(systemName: "chevron.left")
                                        .frame(width: 32, height: 32)
                                }
                                .buttonStyle(.bordered)

                                Text(store.document.title)
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .lineLimit(1)
                                    .frame(maxWidth: .infinity)

                                Button { store.nextArtwork() } label: {
                                    Image(systemName: "chevron.right")
                                        .frame(width: 32, height: 32)
                                }
                                .buttonStyle(.bordered)
                            }

                            Button("Nearly Complete (5 left)") {
                                store.debugNearlyComplete()
                                dismiss()
                            }
                            .buttonStyle(.bordered)
                            .frame(maxWidth: .infinity)

                            Button("Force Complete") {
                                store.debugForceComplete()
                                dismiss()
                            }
                            .buttonStyle(.bordered)
                            .frame(maxWidth: .infinity)

                            Button(role: .destructive) {
                                store.resetProgress()
                            } label: {
                                Text("Reset Progress")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)

                            LabeledContent("Elements") {
                                Text("\(store.filledElements.count) / \(store.document.totalElements)")
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                            LabeledContent("Groups") {
                                Text("\(store.document.groups.count)")
                                    .foregroundStyle(.secondary)
                            }
                            LabeledContent("Phase") {
                                Text(String(describing: store.phase))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .transition(.opacity)
                }

            }
            .scrollContentBackground(.hidden)
            .background(Color.black)
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
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
                    Text("One artwork. One color at a time.")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(.white.opacity(0.5))
                }

                VStack(spacing: 16) {
                    aboutParagraph("A new image appears each day. You fill it in, one hue at a\u{00A0}time. That\u{00A0}is\u{00A0}the\u{00A0}whole\u{00A0}game.")
                    aboutParagraph("No ads. No accounts. No streaks. No algorithm deciding what you deserve. Just color, quiet, and the occasional\u{00A0}sarcastic\u{00A0}remark.")
                    aboutParagraph("Made by one person who wanted something calm to do with\u{00A0}his\u{00A0}hands.")
                }
                .padding(.horizontal, 28)

                // Support section
                VStack(spacing: 16) {
                    Rectangle()
                        .fill(.white.opacity(0.06))
                        .frame(width: 56, height: 0.5)

                    Text("Support One Hue")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))

                    TipJarInline()
                }
                .padding(.top, 48)

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

// MARK: - Tip Jar (Inline for About page)

private struct TipJarInline: View {
    @StateObject private var tipJar = TipJarManager.shared

    var body: some View {
        VStack(spacing: 12) {
            if tipJar.purchaseState == .thankYou {
                VStack(spacing: 6) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.pink.opacity(0.8))
                    Text("Thank you!")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.8))
                    Text("Your support means the world.")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(.white.opacity(0.4))
                }
                .transition(.opacity)
            } else if tipJar.products.isEmpty && !tipJar.didFinishLoading {
                ProgressView()
                    .padding(.vertical, 8)
            } else if tipJar.products.isEmpty {
                // Products unavailable — hide tip jar gracefully
                EmptyView()
            } else {
                HStack(spacing: 10) {
                    ForEach(tipJar.products) { product in
                        Button {
                            Task { await tipJar.purchase(product) }
                        } label: {
                            VStack(spacing: 6) {
                                Image(systemName: tipIcon(for: product))
                                    .font(.system(size: 16))
                                    .foregroundStyle(.white.opacity(0.6))
                                Text(product.displayPrice)
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.8))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(.white.opacity(0.08))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .strokeBorder(.white.opacity(0.1), lineWidth: 0.5)
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(tipJar.purchaseState == .purchasing)
                    }
                }
                .padding(.horizontal, 32)

                if case .failed(let msg) = tipJar.purchaseState {
                    Text(msg)
                        .font(.caption)
                        .foregroundStyle(.red.opacity(0.7))
                }
            }
        }
    }

    private func tipIcon(for product: Product) -> String {
        switch product.id {
        case "com.dix.OneHue.tip.small":  return "cup.and.saucer"
        case "com.dix.OneHue.tip.medium": return "heart"
        case "com.dix.OneHue.tip.large":  return "heart.fill"
        default: return "heart"
        }
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
