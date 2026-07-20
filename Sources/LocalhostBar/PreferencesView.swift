import LocalhostCore
import SwiftUI

struct PreferencesView: View {
    @ObservedObject var model: LocalhostModel
    @ObservedObject var preferences: LocalhostPreferences

    @State private var launchAtLogin = false
    @State private var launchAtLoginError: String?

    var body: some View {
        Form {
            Section {
                Toggle("Show background services", isOn: $preferences.showBackgroundServices)

                Picker("Refresh interval", selection: $preferences.refreshIntervalSeconds) {
                    Text("2 seconds").tag(2)
                    Text("4 seconds").tag(4)
                    Text("8 seconds").tag(8)
                    Text("15 seconds").tag(15)
                    Text("30 seconds").tag(30)
                }
                .onChange(of: preferences.refreshIntervalSeconds) { _ in
                    model.startRefreshLoop()
                }

                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { newValue in
                        if !preferences.setLaunchAtLogin(newValue) {
                            launchAtLoginError = "Could not update login item. Move the app to Applications and try again."
                            launchAtLogin = preferences.launchAtLoginEnabled
                        } else {
                            launchAtLoginError = nil
                        }
                    }

                if let launchAtLoginError {
                    Text(launchAtLoginError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            } header: {
                Text("General")
            }

            Section {
                LabeledContent("Version", value: AppMetadata.version)
                Link("GitHub", destination: AppMetadata.githubURL)
                Text(AppMetadata.copyright)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("About")
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear {
            launchAtLogin = preferences.launchAtLoginEnabled
        }
    }
}
