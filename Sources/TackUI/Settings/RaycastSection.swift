import AppKit
import SwiftUI
import TackKit
import UniformTypeIdentifiers

/// Shown only when Raycast is installed: bring Raycast Notes into Tack.
struct RaycastSection: View {
    let theme: NoteTheme
    @State private var model = RaycastImportModel()

    static var isRaycastInstalled: Bool {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.raycast.macos") != nil
    }

    var body: some View {
        Section("Raycast") {
            LabeledContent {
                Button(model.file == nil ? "Choose Export…" : "Change…", action: chooseFile)
            } label: {
                Text("Import notes from Raycast")
                Text(model.file?.lastPathComponent ?? "A .rayconfig file with Notes in it")
            }
            if model.file != nil {
                HStack {
                    SecureField("Export password", text: $model.password)
                        .onSubmit(startImport)
                    Button("Import", action: startImport)
                        .disabled(!model.canImport)
                }
            }
            status
            Text("In Raycast, open Settings > Advanced > Export, include Notes, and set a password. Notes already in Tack are skipped.")
                .settingFootnote()
        }
    }

    @ViewBuilder
    private var status: some View {
        switch model.status {
        case .idle:
            EmptyView()
        case .importing:
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("Importing…").settingFootnote()
            }
        case let .finished(result, total):
            Label(
                "Imported \(result.imported) of \(total) notes" + (result.skipped > 0 ? "; \(result.skipped) were already here." : "."),
                systemImage: "checkmark.circle.fill"
            )
            .settingFootnote()
            .foregroundStyle(.green)
        case let .failed(message):
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .settingFootnote()
                .foregroundStyle(.orange)
        }
    }

    private func chooseFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "rayconfig") ?? .data]
        panel.directoryURL = URL.downloadsDirectory
        panel.message = "Choose a Raycast export"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        model.fileChosen(url)
    }

    private func startImport() {
        Task { await model.importButtonTapped(theme: theme) }
    }
}
