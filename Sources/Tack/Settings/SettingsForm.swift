import SwiftUI

struct SettingsForm<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        Form {
            // The grouped style's own section fill is opaque; a material shows the
            // window's glass through every row.
            content
                .listRowBackground(Rectangle().fill(.ultraThinMaterial))
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }
}
