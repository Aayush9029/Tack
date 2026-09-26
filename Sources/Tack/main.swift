import AppKit
import Dependencies
import TackKit
import TackUI

if SingleInstance.handOffIfAlreadyRunning() {
    exit(0)
}

prepareDependencies {
    try! $0.bootstrapDatabase()
}

let application = NSApplication.shared
let delegate = AppDelegate()
application.delegate = delegate
application.run()
