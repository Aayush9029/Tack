import SwiftUI
import TackKit

struct PreviewLineView: View {
    let line: PreviewLine

    var body: some View {
        switch line {
        case let .heading(text):
            Text(text).font(.system(size: 13, weight: .semibold)).lineLimit(2)
        case let .task(text, isDone):
            Label {
                Text(text).strikethrough(isDone).foregroundStyle(isDone ? .secondary : .primary).lineLimit(2)
            } icon: {
                Image(systemName: isDone ? "checkmark.square.fill" : "square")
                    .foregroundStyle(isDone ? AnyShapeStyle(Color(nsColor: EditorTheme.caret)) : AnyShapeStyle(.secondary))
            }
            .font(.system(size: 13))
        case let .bullet(text):
            Label { Text(text).lineLimit(2) } icon: { Text("•").foregroundStyle(.secondary) }
                .font(.system(size: 13))
        case let .quote(text):
            Text(text).font(.system(size: 13)).foregroundStyle(.secondary).lineLimit(2)
                .padding(.leading, 8)
                .overlay(alignment: .leading) { Capsule().fill(.tertiary).frame(width: 2) }
        case let .code(text):
            Text(text).font(.system(size: 12, design: .monospaced)).foregroundStyle(.secondary).lineLimit(1)
        case let .text(text):
            Text(text).font(.system(size: 13)).lineLimit(3)
        }
    }
}
