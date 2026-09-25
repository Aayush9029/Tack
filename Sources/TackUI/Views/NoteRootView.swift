import SwiftUI
import TackKit

struct NoteRootView: View {
    let model: NoteWindowModel
    let preferences: Preferences
    let window: WindowState
    let proxy: EditorProxy
    let actions: NoteWindowActions

    @State private var isHovering = false
    @State private var entryOffset: CGFloat = 0
    @State private var entryOpacity: Double = 1
    @State private var showsFocusHint = false

    private var showsChrome: Bool { isHovering && !model.isFocusMode }

    var body: some View {
        VStack(spacing: 0) {
            if !model.isFocusMode {
                NoteTitleBar(model: model, isHovering: isHovering)
                    .transition(.opacity)
            }
            NoteEditor(model: model, configuration: configuration, proxy: proxy, onEscape: actions.escape)
                .offset(x: window.swipeOffset + entryOffset)
                .opacity(entryOpacity * swipeOpacity)
        }
        .background { NoteBackground(theme: model.theme, isFocusMode: model.isFocusMode) }
        .overlay(alignment: .topLeading) {
            CloseButton(isKey: window.isKey, close: actions.close)
                .frame(height: Metrics.titleBarHeight)
                .padding(.leading, 14)
                .opacity(showsChrome ? 1 : 0)
                .allowsHitTesting(showsChrome)
        }
        .overlay(alignment: .topTrailing) {
            ChromeButton(symbol: "command", help: "Commands (⌘K)") { model.commandKeyTapped() }
                .padding(Metrics.cornerInset)
                .opacity(showsChrome ? 1 : 0)
                .allowsHitTesting(showsChrome)
        }
        .overlay(alignment: .bottomLeading) {
            ChromeButton(symbol: model.isPinned ? "pin.fill" : "pin", help: model.isPinned ? "Unpin from Top" : "Pin on Top", isOn: model.isPinned) {
                model.pinButtonTapped()
            }
            .padding(Metrics.cornerInset)
            .opacity(showsChrome ? 1 : 0)
            .allowsHitTesting(showsChrome)
        }
        .overlay(alignment: .bottom) {
            if showsFocusHint {
                Text("Press ⌘↩ or Esc to leave focus mode")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .glassEffect(.regular, in: .capsule)
                    .padding(.bottom, 32)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .overlay {
            SwipeGlow(offset: window.swipeOffset, isAllowed: window.swipeEdge != nil, flash: window.swipeFlash)
                .clipShape(.rect(cornerRadius: model.isFocusMode ? 0 : Metrics.windowRadius, style: .continuous))
        }
        .onHover { isHovering = $0 }
        .animation(.easeOut(duration: 0.16), value: showsChrome)
        .animation(.smooth(duration: 0.35), value: model.isFocusMode)
        .animation(.easeOut(duration: 0.3), value: showsFocusHint)
        .onChange(of: model.revision) { slideIn(model.direction) }
        .onChange(of: model.isFocusMode) { _, isFocusMode in
            showsFocusHint = isFocusMode
        }
        .task(id: showsFocusHint) {
            guard showsFocusHint else { return }
            try? await Task.sleep(for: .seconds(2.2))
            showsFocusHint = false
        }
        .task { await model.task() }
    }

    private var configuration: EditorConfiguration {
        EditorConfiguration(
            noteFont: preferences.noteFont,
            focusFont: preferences.focusFont,
            size: preferences.noteFontSize,
            isFocusMode: model.isFocusMode,
            isTypewriter: preferences.typewriterScrolling,
            dimsParagraphs: preferences.dimsOtherParagraphs,
            checksSpelling: preferences.checksSpelling
        )
    }

    private var swipeOpacity: Double {
        1 - min(abs(window.swipeOffset) / 420, 0.5)
    }

    /// A new note arrives from the side it was asked for; a swipe that already moved
    /// the old one away hands over from where the fingers left it.
    private func slideIn(_ direction: NavigationDirection) {
        guard direction != .none else { return }
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            entryOffset = direction == .forward ? 48 : -48
            entryOpacity = 0
        }
        withAnimation(.smooth(duration: 0.32)) {
            entryOffset = 0
            entryOpacity = 1
        }
    }
}
