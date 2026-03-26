import SwiftUI
import QuartzCore

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - Platform Image Type

#if canImport(UIKit)
typealias PlatformImage = UIImage
#elseif canImport(AppKit)
typealias PlatformImage = NSImage
#endif

// MARK: - HSB Color Extraction

/// Cross-platform HSB extraction from a SwiftUI Color.
/// Replaces UIColor(color).getHue(...) calls.
struct HSBComponents {
    let hue: CGFloat
    let saturation: CGFloat
    let brightness: CGFloat
    let alpha: CGFloat
}

extension Color {
    /// Extract HSB components. Works on iOS (UIColor) and macOS (NSColor).
    func hsbComponents() -> HSBComponents {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        #if canImport(UIKit)
        UIColor(self).getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        #elseif canImport(AppKit)
        let nsColor = NSColor(self).usingColorSpace(.deviceRGB) ?? NSColor(self)
        nsColor.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        #endif
        return HSBComponents(hue: h, saturation: s, brightness: b, alpha: a)
    }
}

/// Extract HSB from raw RGB values (for PaletteView hex→HSB).
func rgbToHSB(r: CGFloat, g: CGFloat, b: CGFloat) -> HSBComponents {
    var h: CGFloat = 0, s: CGFloat = 0, br: CGFloat = 0, a: CGFloat = 0
    #if canImport(UIKit)
    UIColor(red: r, green: g, blue: b, alpha: 1).getHue(&h, saturation: &s, brightness: &br, alpha: &a)
    #elseif canImport(AppKit)
    NSColor(red: r, green: g, blue: b, alpha: 1).getHue(&h, saturation: &s, brightness: &br, alpha: &a)
    #endif
    return HSBComponents(hue: h, saturation: s, brightness: br, alpha: a)
}

// MARK: - Device Idiom

/// True on iPad (or Mac Catalyst in iPad mode). False on iPhone, Mac native, etc.
let isIPad: Bool = {
    #if canImport(UIKit)
    return UIDevice.current.userInterfaceIdiom == .pad
    #else
    return false
    #endif
}()

/// True when running on a large screen (iPad or Mac).
let isLargeScreen: Bool = {
    #if canImport(UIKit)
    return UIDevice.current.userInterfaceIdiom == .pad
    #else
    return true  // Mac always has room
    #endif
}()

// MARK: - Haptics

/// Cross-platform haptic feedback. No-ops on macOS.
enum Haptics {
    #if canImport(UIKit)
    private static let light = UIImpactFeedbackGenerator(style: .light)
    private static let medium = UIImpactFeedbackGenerator(style: .medium)
    #endif

    static func lightImpact() {
        #if canImport(UIKit)
        light.impactOccurred()
        #endif
    }

    static func mediumImpact() {
        #if canImport(UIKit)
        medium.impactOccurred()
        #endif
    }

    static func success() {
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
    }
}

// MARK: - Memory Pressure Notification

/// Cross-platform memory warning notification name.
let memoryWarningNotification: Notification.Name = {
    #if canImport(UIKit)
    return UIApplication.didReceiveMemoryWarningNotification
    #else
    // macOS doesn't have a direct equivalent; use a placeholder that never fires.
    // For real macOS memory pressure, we'd use DispatchSource.makeMemoryPressureSource.
    return Notification.Name("OneHue.memoryWarning.unused")
    #endif
}()

// MARK: - Cross-Platform Display Link

/// @objc target bridge for CADisplayLink (iOS).
final class DisplayLinkTarget: NSObject {
    let callback: () -> Void
    init(callback: @escaping () -> Void) { self.callback = callback }
    @objc func tick() { callback() }
}

/// Cross-platform wrapper: CADisplayLink on iOS, CVDisplayLink on macOS.
/// Call `start()` to begin firing, `stop()` to end.
final class PlatformDisplayLink {
    private let callback: () -> Void

    #if canImport(UIKit)
    private var displayLink: CADisplayLink?
    private var target: DisplayLinkTarget?
    #else
    private var displayLink: CVDisplayLink?
    private var timer: Timer?
    #endif

    init(callback: @escaping () -> Void) {
        self.callback = callback
    }

    func start() {
        #if canImport(UIKit)
        guard displayLink == nil else { return }
        let t = DisplayLinkTarget(callback: callback)
        target = t
        let link = CADisplayLink(target: t, selector: #selector(DisplayLinkTarget.tick))
        link.add(to: .main, forMode: .common)
        displayLink = link
        #else
        guard timer == nil else { return }
        // ~120fps timer on macOS — the run loop coalesces to display refresh anyway
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 120.0, repeats: true) { [weak self] _ in
            self?.callback()
        }
        #endif
    }

    func stop() {
        #if canImport(UIKit)
        displayLink?.invalidate()
        displayLink = nil
        target = nil
        #else
        timer?.invalidate()
        timer = nil
        #endif
    }
}
