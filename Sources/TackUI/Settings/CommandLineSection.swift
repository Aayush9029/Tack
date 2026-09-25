import SwiftUI

struct CommandLineSection: View {
    @State private var isInstalled = CommandLineTool.isInstalled
    @State private var failure: String?

    var body: some View {
        Section("Command Line") {
            LabeledContent {
                Button(isInstalled ? "Installed" : "Install") {
                    do {
                        try CommandLineTool.install()
                        failure = nil
                    } catch {
                        failure = error.localizedDescription
                    }
                    isInstalled = CommandLineTool.isInstalled
                }
                .disabled(isInstalled)
            } label: {
                Text("tack command")
                Text("~/.local/bin/tack").monospaced()
            }
            Text("Lets you and your agents list, search, add and edit notes from a terminal. Run `tack --help` to start. Add ~/.local/bin to your PATH if it is not there.")
                .settingFootnote()
            if let failure {
                Label(failure, systemImage: "exclamationmark.triangle.fill")
                    .settingFootnote()
                    .foregroundStyle(.orange)
            }
        }
    }
}
