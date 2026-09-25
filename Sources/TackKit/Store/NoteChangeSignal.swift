import Foundation
import notify

/// A Darwin notification between the command line tool and the app, so an open
/// note shows a change the moment `tack` writes it.
public enum NoteChangeSignal {
    static let name = "ca.optimalapps.tack.notes-changed"

    public static func post() {
        notify_post(name)
    }

    /// Returns a token to keep; the handler runs on the main queue.
    @discardableResult
    public static func observe(_ handler: @escaping @MainActor () -> Void) -> Int32 {
        var token: Int32 = 0
        notify_register_dispatch(name, &token, .main) { _ in
            MainActor.assumeIsolated { handler() }
        }
        return token
    }
}
