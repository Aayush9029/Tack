import SwiftUI
import TackKit

struct PaletteView: View {
    let model: PaletteModel

    @FocusState private var isFocused: Bool
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            field
            Divider().opacity(0.5)
            results
        }
        .frame(width: Metrics.paletteWidth)
        .frame(maxHeight: .infinity, alignment: .top)
        .background((colorScheme == .dark ? Color.black.opacity(0.42) : Color.white.opacity(0.55)))
        .task(id: TaskKey(page: model.page, query: model.query)) {
            await model.searchNotes()
        }
        .task {
            try? await Task.sleep(for: .milliseconds(20))
            isFocused = true
        }
    }

    private var field: some View {
        HStack(spacing: 8) {
            if model.page != .root {
                Text(pageTitle)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.primary.opacity(0.08), in: .capsule)
            }
            TextField(model.page.placeholder, text: Binding(get: { model.query }, set: model.queryChanged))
                .textFieldStyle(.plain)
                .font(.system(size: 15.5))
                .focused($isFocused)
                .onSubmit { model.returnKeyPressed() }
                .onKeyPress(.upArrow) {
                    model.moveHighlight(-1)
                    return .handled
                }
                .onKeyPress(.downArrow) {
                    model.moveHighlight(1)
                    return .handled
                }
                .onKeyPress(.delete) {
                    guard model.query.isEmpty, model.page != .root else { return .ignored }
                    model.deleteOnEmptyField()
                    return .handled
                }
        }
        .padding(.horizontal, 16)
        .frame(height: PaletteMetrics.fieldHeight)
    }

    private var pageTitle: String {
        switch model.page {
        case .root: ""
        case .copyAs: "Copy As"
        case .theme: "Look"
        case .notes: "Notes"
        }
    }

    private var results: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    if model.rows.isEmpty {
                        Text(model.page == .notes ? "No notes match “\(model.query)”" : "No matches")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                    }
                    ForEach(Array(model.rows.enumerated()), id: \.element.id) { index, row in
                        if index > 0, row.group != model.rows[index - 1].group {
                            Divider()
                                .opacity(0.5)
                                .padding(.vertical, PaletteMetrics.dividerPadding)
                                .padding(.horizontal, 6)
                        }
                        rowView(row)
                            .id(row.id)
                    }
                }
                .padding(6)
            }
            .scrollIndicators(.never)
            .onChange(of: model.highlighted) { _, id in
                guard let id else { return }
                proxy.scrollTo(id)
            }
        }
    }

    private func rowView(_ row: PaletteRow) -> some View {
        let isHighlighted = row.id == model.highlighted
        return Button {
            model.rowTapped(row.id)
        } label: {
            Group {
                switch row {
                case let .item(item): PaletteItemRow(item: item, isHighlighted: isHighlighted)
                case let .note(hit): PaletteNoteRow(hit: hit, isHighlighted: isHighlighted)
                }
            }
            .background(
                .primary.opacity(isHighlighted ? 0.13 : 0),
                in: .rect(cornerRadius: Metrics.paletteRadius - 6, style: .continuous)
            )
            .contentShape(.rect(cornerRadius: Metrics.paletteRadius - 6, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!row.isEnabled)
        .onContinuousHover { phase in
            if case .active = phase { model.hover(row.id) }
        }
    }

    private struct TaskKey: Equatable {
        let page: PalettePage
        let query: String
    }
}
