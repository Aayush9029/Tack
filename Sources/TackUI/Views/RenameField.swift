import SwiftUI

struct RenameField: View {
    @State private var text: String
    @FocusState private var isFocused: Bool
    let onCommit: (String) -> Void
    let onCancel: () -> Void

    init(title: String, onCommit: @escaping (String) -> Void, onCancel: @escaping () -> Void) {
        _text = State(initialValue: title)
        self.onCommit = onCommit
        self.onCancel = onCancel
    }

    var body: some View {
        TextField("Title", text: $text)
            .textFieldStyle(.plain)
            .multilineTextAlignment(.center)
            .focused($isFocused)
            .onSubmit { onCommit(text) }
            .onExitCommand { onCancel() }
            .onChange(of: isFocused) { _, focused in
                if !focused { onCommit(text) }
            }
            .task {
                try? await Task.sleep(for: .milliseconds(30))
                isFocused = true
            }
    }
}
