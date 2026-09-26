import Foundation

/// Low Power Mode: wait longer per keystroke and rank a shorter candidate list.
public struct SearchTuning: Equatable, Sendable {
    public var debounce: Duration
    public var matchLimit: Int
    public var resultLimit: Int

    private static let standard = Self(debounce: .milliseconds(60), matchLimit: 300, resultLimit: 40)
    private static let lowPower = Self(debounce: .milliseconds(200), matchLimit: 120, resultLimit: 25)

    public static var current: Self {
        ProcessInfo.processInfo.isLowPowerModeEnabled ? .lowPower : .standard
    }
}
