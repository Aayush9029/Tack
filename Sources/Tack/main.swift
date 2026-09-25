import AppKit
import Dependencies
import TackKit

prepareDependencies {
    try! $0.bootstrapDatabase()
}

let application = NSApplication.shared
let delegate = AppDelegate()
application.delegate = delegate
application.run()
