import SwiftUI
import TackKit

struct SettingsView: View {
    let app: AppModel
    @State private var tab: SettingsTab?

    init(app: AppModel, initialTab: SettingsTab = .general) {
        self.app = app
        _tab = State(initialValue: initialTab)
    }

    var body: some View {
        NavigationSplitView(columnVisibility: .constant(.all)) {
            List(SettingsTab.allCases, selection: $tab) { tab in
                Label {
                    Text(tab.title)
                } icon: {
                    SettingsTabIcon(tab: tab, isSelected: tab == currentTab)
                }
                .padding(.vertical, 4)
                .tag(tab)
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 180, ideal: 180, max: 180)
            .toolbar(removing: .sidebarToggle)
        } detail: {
            pane
                .navigationTitle("")
                .background {
                    VisualEffectBackground(material: .underWindowBackground)
                        .ignoresSafeArea()
                }
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 660, minHeight: 460)
    }

    private var currentTab: SettingsTab { tab ?? .general }

    @ViewBuilder
    private var pane: some View {
        switch currentTab {
        case .general: GeneralPane(preferences: app.preferences)
        case .notes: NotesPane(app: app)
        case .editor: EditorPane(preferences: app.preferences)
        case .shortcuts: ShortcutsPane()
        case .about: AboutPane()
        }
    }
}
