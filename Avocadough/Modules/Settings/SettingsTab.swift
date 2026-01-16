//
//  SettingsTab.swift
//  Avocadough
//

import SwiftUI

struct SettingsTab: View {
    @Environment(SettingsState.self) private var state

    var body: some View {
        @Bindable var state = state

        NavigationStack(path: $state.path) {
            SettingsTabContent()
                .navigationDestination(for: SettingsState.NavigationLink.self) {
                    switch $0 {
                    case .privacy:
                        PrivacyPolicyView()
                    case .about:
                        AboutView()
                    case .support:
                        SupportView()
                    case .theme:
                        ThemeSettingsView()
                    }
                }
        }
    }
}

// MARK: - SettingsTabContent

private struct SettingsTabContent: View {
    @Environment(SettingsState.self) private var state

    // MARK: color scheme properties
    @State private var selectedColorScheme = 0
    @AppStorage(Build.Constants.UserDefault.colorScheme) private var colorSchemeString: String?

    var body: some View {
        @Bindable var state = state

        Form {
            // MARK: - Wallet Section
            Section {
                InfoCard(
                    icon: "bolt.fill",
                    title: "NWC Wallet",
                    subtitle: "Connected",
                    iconColor: .yellow,
                    style: .transparent
                )
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            } header: {
                Text("Wallet")
            }

            // MARK: - General Section
            Section {
                if let url = URL(string: "https://github.com/sparrowtek/avocadough") {
                    Link(destination: url) {
                        SettingsRow(icon: "link", title: "Source (Github)", color: DesignTokens.Colors.Accent.primary)
                    }
                }

                NavigationLink(value: SettingsState.NavigationLink.privacy) {
                    SettingsRow(icon: "hand.raised.fill", title: "Privacy", color: DesignTokens.Colors.Accent.info)
                }

                NavigationLink(value: SettingsState.NavigationLink.about) {
                    SettingsRow(icon: "info.circle.fill", title: "About", color: Color.ds.textSecondary)
                }

                NavigationLink(value: SettingsState.NavigationLink.support) {
                    SettingsRow(icon: "bitcoinsign.circle.fill", title: "Support Avocadough", color: .orange)
                }
            } header: {
                Text("General")
            }

            // MARK: - Appearance Section
            Section {
                Picker("Color Scheme", selection: $selectedColorScheme) {
                    Text("System").tag(0)
                    Text("Light").tag(1)
                    Text("Dark").tag(2)
                }
                .pickerStyle(.segmented)
            } header: {
                Text("Appearance")
            }

            // MARK: - Danger Zone
            Section {
                Button(role: .destructive, action: disconnectFromNWCAlert) {
                    HStack {
                        Image(systemName: "bolt.trianglebadge.exclamationmark.fill")
                        Text("Disconnect and Clear Data")
                    }
                }
                .confirmationDialog("Are you sure you want to disconnect?", isPresented: $state.presentNWCDisconnectDialog, titleVisibility: .visible) {
                    Button("Disconnect", role: .destructive, action: disconnectNWC)
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("This will remove your wallet connection and all local data.")
                }
            }
        }
        .fullScreenColorView()
        .navigationTitle("Settings")
        .onAppear(perform: setSelectedColorScheme)
        .onChange(of: selectedColorScheme, updateColorScheme)
    }

    private func disconnectNWC() {
        state.disconnectNWC()
    }

    private func disconnectFromNWCAlert() {
        state.presentNWCDisconnectDialog = true
    }

    // MARK: Color scheme methods
    private func setSelectedColorScheme() {
        switch colorSchemeString {
        case Build.Constants.Theme.light: selectedColorScheme = 1
        case Build.Constants.Theme.dark: selectedColorScheme = 2
        default: selectedColorScheme = 0
        }
    }

    private func updateColorScheme() {
        switch selectedColorScheme {
        case 1: colorSchemeString = Build.Constants.Theme.light
        case 2: colorSchemeString = Build.Constants.Theme.dark
        default: colorSchemeString = nil
        }
    }
}

// MARK: - Settings Row

private struct SettingsRow: View {
    let icon: String
    let title: LocalizedStringKey
    let color: Color

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 28, height: 28)
                .background(color.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.sm))

            Text(title)
                .foregroundStyle(Color.ds.textPrimary)
        }
    }
}

// MARK: - Preview

#Preview {
    @Previewable @State var state = AppState()
    
    SettingsTab()
        .environment(state.settingsState)
}
