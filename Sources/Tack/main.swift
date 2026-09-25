import AppKit
import Dependencies
import TackKit
import TackUI

prepareDependencies {
    try! $0.bootstrapDatabase()
}

let application = NSApplication.shared
let delegate = AppDelegate()
application.delegate = delegate
application.run()
