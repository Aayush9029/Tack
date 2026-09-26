import SwiftUI
import TackKit

struct OverviewView: View {
    let model: OverviewModel

    @FocusState private var isSearching: Bool
    @State private var width: CGFloat = 0
    @Environment(\.colorScheme) private var colorScheme

    private let cardWidth: CGFloat = 260
    private let spacing: CGFloat = 18

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            header
            content
        }
        .padding(.horizontal, 56)
        .padding(.top, 44)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(colorScheme == .dark ? Color.black.opacity(0.5) : Color.white.opacity(0.55))
        .onGeometryChange(for: CGFloat.self, of: { $0.size.width - 112 }) { width = $0 }
        .task(id: model.query) { await model.load() }
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
                                NoteCardView(card: card) { model.cardTapped(card.id) }
                            }
                        }
                        .frame(width: cardWidth)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, 56)
            }
            .scrollIndicators(.never)
            .opacity(model.isLoaded ? 1 : 0)
            .animation(.easeOut(duration: 0.25), value: model.isLoaded)
        }
    }

    private var columns: [[NoteCard]] {
        let count = max(1, Int((width + spacing) / (cardWidth + spacing)))
        return WaterfallLayout.columns(model.cards, count: count)
    }
}
