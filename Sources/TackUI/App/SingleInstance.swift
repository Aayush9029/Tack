import AppKit

/// One Tack at a time: two copies would each save their own version of an open
/// note over the other's. A second launch brings the first forward and quits.
public enum SingleInstance {
    public static func handOffIfAlreadyRunning() -> Bool {
        guard let bundleID = Bundle.main.bundleIdentifier else { return false }
        let others = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            .filter { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier && !$0.isTerminated }
        guard let running = others.first else { return false }
        running.activate()
        return true
    }
}
