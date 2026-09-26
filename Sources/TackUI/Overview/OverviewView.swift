import SwiftUI
import TackKit

struct OverviewView: View {
    let model: OverviewModel
    /// Room for the menu bar and the camera notch the grid now covers.
    let topInset: CGFloat

    @FocusState private var isSearching: Bool
    @State private var width: CGFloat = 0
    @Environment(\.colorScheme) private var colorScheme

    private let cardWidth: CGFloat = 300
    private let spacing: CGFloat = 22
    private let margin: CGFloat = 56

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
                .padding(.horizontal, margin)
            content
        }
        .padding(.top, topInset)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(colorScheme == .dark ? Color.black.opacity(0.62) : Color.white.opacity(0.66))
        .onGeometryChange(for: CGFloat.self, of: { $0.size.width - 112 }) { width = $0 }
        .task(id: model.query) { await model.load() }
        .confirmationDialog(
            "Delete “\(model.pendingDeletion?.title ?? "")”?",
            isPresented: Binding(get: { model.pendingDeletion != nil }, set: { if !$0 { model.deletionCancelled() } })
        ) {
            Button("Delete", role: .destructive, action: model.deletionConfirmed)
            Button("Cancel", role: .cancel, action: model.deletionCancelled)
        } message: {
            Text("You can’t undo this.")
        }
        .task {
            try? await Task.sleep(for: .milliseconds(60))
            isSearching = true
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text("All Notes")
                .font(.system(size: 28, weight: .bold))
            if model.isLoaded {
                Text("\(model.cards.count)")
                    .font(.system(size: 20, weight: .semibold).monospacedDigit())
                    .foregroundStyle(.tertiary)
                    .contentTransition(.numericText())
            }
            Spacer()
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search notes", text: Binding(get: { model.query }, set: model.queryChanged))
                    .textFieldStyle(.plain)
                    .focused($isSearching)
                    .onSubmit(model.returnKeyPressed)
            }
            .font(.system(size: 14))
            .padding(.horizontal, 14)
            .frame(width: 280, height: 36)
            .glassEffect(.regular, in: .capsule)
            ChromeButton(symbol: "plus", help: "New Note (⌘N)", action: model.newNoteButtonTapped)
                .keyboardShortcut("n", modifiers: .command)
        }
    }

    @ViewBuilder
    private var content: some View {
        if model.isLoaded, model.cards.isEmpty {
            Text(model.query.isEmpty ? "No notes yet" : "No notes match “\(model.query)”")
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                HStack(alignment: .top, spacing: spacing) {
                    ForEach(Array(columns.enumerated()), id: \.offset) { _, column in
                        LazyVStack(spacing: spacing) {
                            ForEach(column) { card in
                                NoteCardView(card: card) { model.cardTapped(card.id, inNewWindow: NSEvent.modifierFlags.contains(.command)) }
                                    .contextMenu {
                                        Button("Open") { model.cardTapped(card.id) }
                                        Button("Open in New Window") { model.cardTapped(card.id, inNewWindow: true) }
                                        Divider()
                                        Button("Delete Note…", role: .destructive) { model.deleteMenuItemTapped(card) }
                                    }
                            }
                        }
                        .frame(width: cardWidth)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            // Margins inside the scroll view, not padding around it, so a card's hover
            // growth, shadow and context menu highlight are never clipped at its edge.
            .contentMargins(.horizontal, margin, for: .scrollContent)
            .contentMargins(.top, 20, for: .scrollContent)
            .contentMargins(.bottom, 56, for: .scrollContent)
            .scrollIndicators(.never)
            .opacity(model.isLoaded ? 1 : 0)
            .animation(.easeOut(duration: 0.25), value: model.isLoaded)
        }
    }

    /// As many columns as fit, but never more than there are notes, so a few notes
    /// sit centered instead of in a corner.
    private var columns: [[NoteCard]] {
        let fitting = max(1, Int((width + spacing) / (cardWidth + spacing)))
        return WaterfallLayout.columns(model.cards, count: min(fitting, max(1, model.cards.count)))
    }
}
