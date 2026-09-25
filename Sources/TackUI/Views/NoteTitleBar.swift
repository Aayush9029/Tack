import SwiftUI
import TackKit

struct NoteTitleBar: View {
    let model: NoteWindowModel
    let isHovering: Bool

    /// Classic's header is a solid colour in both appearances, so its title is dark ink.
    private var titleStyle: AnyShapeStyle {
        if model.theme.style == .classic {
            return AnyShapeStyle(Color.black.opacity(isHovering ? 0.75 : 0.55))
        }
        return isHovering ? AnyShapeStyle(.secondary) : AnyShapeStyle(.tertiary)
    }

    var body: some View {
        ZStack {
            if model.isRenaming {
                RenameField(title: model.displayTitle, onCommit: model.renameCommitted, onCancel: model.renameCancelled)
                    .font(.system(size: 12.5, weight: .semibold))
                    .padding(.horizontal, 84)
            } else {
                Text(model.displayTitle)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(titleStyle)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .padding(.horizontal, 84)
                    .contentTransition(.opacity)
                    .id(model.noteID)
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: Metrics.titleBarHeight)
        .contentShape(.rect)
        .gesture(WindowDragGesture())
        .onTapGesture(count: 2) { model.renameButtonTapped() }
        .contextMenu { NoteLookMenu(model: model) }
        .animation(.easeOut(duration: 0.15), value: model.noteID)
    }
}
