import AppKit
import SwiftUI

struct AboutPane: View {
    private var version: String {
        let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(short) (\(build))"
    }

    var body: some View {
        SettingsForm {
            Section {
                HStack(spacing: 14) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .frame(width: 56, height: 56)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Tack")
                            .font(.title3.weight(.semibold))
                        Text("Version \(version)")
                            .settingFootnote()
                        Text("Glass sticky notes for the Mac, in Markdown.")
                            .settingFootnote()
                    }
                    Spacer(minLength: 0)
                    Link("GitHub", destination: URL(string: "https://github.com/Aayush9029/Tack")!)
                }
                .padding(.vertical, 4)
            }

            Section("Storage") {
                LabeledContent("Notes", value: "Stored on this Mac only")
                LabeledContent("Pasted images", value: "Application Support, Attachments")
            }

            Section("Fonts") {
                LabeledContent("iA Writer Duo, Quattro, Mono", value: "SIL Open Font License")
            }
        }
    }
}
