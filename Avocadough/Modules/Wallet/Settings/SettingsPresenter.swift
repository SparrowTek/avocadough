//
//  SettingsPresenter.swift
//  Avocadough
//
//  Created by Thomas Rademaker on 12/10/23.
//

import SwiftUI

struct SettingsPresenter: View {
    @Environment(SettingsState.self) private var state

    var body: some View {
        @Bindable var state = state

        NavigationStack(path: $state.path) {
            SettingsView()
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

private struct SettingsView: View {
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
    
    SettingsPresenter()
        .environment(state.walletState.settingsState)
}


/*
struct SettingsPresenter: View {
    @Environment(SettingsState.self) private var state
    
    var body: some View {
        @Bindable var state = state
        
        NavigationStack(path: $state.path) {
            SettingsView()
                .navigationDestination(for: SettingsState.NavigationLink.self) {
                    switch $0 {
                    case .privacy:
                        PrivacyPolicyView()
                            .interactiveDismissDisabled()
                    case .about:
                        AboutView()
                            .interactiveDismissDisabled()
                    case .support:
                        SupportView()
                            .interactiveDismissDisabled()
                    case .theme:
                        ThemeSettingsView()
                            .interactiveDismissDisabled()
                    }
                }
        }
        
    }
}

struct SettingsView: View {
    @Environment(SettingsState.self) private var state
    @Environment(\.dismiss) private var dismiss
    
    // MARK: color scheme properties
    @State private var selectedColorScheme = 0
    @AppStorage(Build.Constants.UserDefault.colorScheme) private var colorSchemeString: String?
    
    // add link for value 4 value to support development
    var body: some View {
        @Bindable var state = state
        
        Form {
            Section {
                
                if let url = URL(string: "https://github.com/sparrowtek/avocadough") {
                    Link(destination: url) {
                        Label("Source (Github)", systemImage: "link")
                    }
                }
                
                NavigationLink(value: SettingsState.NavigationLink.privacy) {
                    Label("privacy", systemImage: "hand.raised.fill")
                }
                
                NavigationLink(value: SettingsState.NavigationLink.about) {
                    Label("about", systemImage: "info")
                }
                
                NavigationLink(value: SettingsState.NavigationLink.support) {
                    Label("support avocadough", systemImage: "bitcoinsign")
                }
            }
            
//            Section {
//                NavigationLink(value: SettingsState.NavigationLink.theme) {
//                    Label("theme", systemImage: "line.3.crossed.swirl.circle.fill")
//                }
//            }
            
            Section("color scheme") {
                Picker("selected color scheme", selection: $selectedColorScheme) {
                    Text("system").tag(0)
                    Text("light").tag(1)
                    Text("dark").tag(2)
                }
                .pickerStyle(.segmented)
            }
            
            Button("disconnect and clear all data", systemImage: "bolt.trianglebadge.exclamationmark.fill", role: .destructive, action: disconnectFromNWCAlert)
                .foregroundStyle(.red)
                .confirmationDialog("logout?", isPresented: $state.presentNWCDisconnectDialog) {
                    Button("logout", role: .destructive, action: disconnectNWC)
                }
        }
        .fullScreenColorView()
        .navigationTitle("settings")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done", action: { dismiss() })
            }
        }
        
        // MARK: color scheme modifiers
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
 
 */

struct WebSectionView: View {
    var title: LocalizedStringKey
    var content: LocalizedStringKey
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.title2)
                .fontWeight(.semibold)
            Text(content)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct SupportView: View {
    @Environment(SettingsState.self) private var state
    @Environment(\.openURL) private var openURL
    
    var body: some View {
        VStack(spacing: 16) {
            WebSectionView(title: "support avocadough", content: """
            Avocadoguh is a free and open source application. Please consider sending some sats to help support ongoing development efforts.
            """)
            
            AvocadoButton("Support", icon: "bitcoinsign", variant: .secondary, size: .large) {
                routeToSupportApp()
            }
            
            Spacer()
        }
        .padding(.horizontal)
        .fullScreenColorView()
    }
    
    private func routeToSupportApp() {
        state.routeToSupport()
        guard let url = URL(string: "https://avocadough.xyz/support-project") else { return }
        openURL(url)
    }
}

struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Privacy Policy")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("This policy applies to all information collected or submitted on Avocadough’s website and our apps for iPhone and any other devices and platforms.")
                
                WebSectionView(title: "Information we collect", content: """
                Avocadough does not create any accounts.
                """)
                
                WebSectionView(title: "Technical basics", content: """
                Our server software may store basic technical information, such as your IP address, in temporary memory or logs.
                """)
                
                WebSectionView(title: "Analytics", content: """
                Avocadough’s app may collect aggregate, anonymous statistics, such as the percentage of users who use particular features, to improve the app.
                """)
                
                WebSectionView(title: "Information usage", content: """
                We use the information we collect to operate and improve our website, apps, and customer support.

                We do not share personal information with outside parties except to the extent necessary to accomplish Avocadough’s functionality.
                We may disclose your information in response to subpoenas, court orders, or other legal requirements; to exercise our legal rights or defend against legal claims; to investigate, prevent, or take action regarding illegal activities, suspected fraud or abuse, violations of our policies; or to protect our rights and property.

                In the future, we may sell to, buy, merge with, or partner with other businesses. In such transactions, user information may be among the transferred assets.
                """)
                
                WebSectionView(title: "Third-party links and content", content: """
Avocadough displays links and content from third-party sites. These have their own independent privacy policies, and we have no responsibility or liability for their content or activities.
""")
                
                WebSectionView(title: "California Online Privacy Protection Act Compliance", content: """
We comply with the California Online Privacy Protection Act. We therefore will not distribute your personal information to outside parties without your consent.
""")
                
                WebSectionView(title: "Children’s Online Privacy Protection Act Compliance", content: """
We never collect or maintain information at our website from those we actually know are under 13, and no part of our website is structured to attract anyone under 13.
""")
                
                WebSectionView(title: "Information for European Union Customers", content: """
By using Avocadough and providing your information, you authorize us to collect, use, and store your information outside of the European Union.
""")
                
                WebSectionView(title: "International Transfers of Information", content: """
Information may be processed, stored, and used outside of the country in which you are located. Data privacy laws vary across jurisdictions, and different laws may be applicable to your data depending on where it is processed, stored, or used.
""")
                
                WebSectionView(title: "Your Consent", content: """
By using our site or apps, you consent to our privacy policy.
""")
                
                WebSectionView(title: "Contacting Us", content: """
If you have questions regarding this privacy policy, you may email contact@sparrowtek.com.
""")
                
                WebSectionView(title: "Changes to this policy", content: """
If we decide to change our privacy policy, we will post those changes on this page. Summary of changes so far: June 3, 2025: First published.
""")
            }
        }
        .padding([.horizontal, .bottom])
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenColorView()
    }
}

struct AboutView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("avocadough")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Avocadough is developed by SparrowTek LLC.")
                
                WebSectionView(title: "Attribution", content: """
                Avocadough uses [NostrKit](https://github.com/SparrowTek/NostrKit) for NWC functionality and we get the current Bitcoin price from [Block](https://block.xyz)'s pricing API.
                """)
            }
        }
        .padding([.horizontal, .bottom])
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenColorView()
    }
}

//#Preview {
//    Text("Avocadough")
//        .sheet(isPresented: .constant(true)) {
//            SettingsPresenter()
//                .environment(SettingsState(parentState: .init(parentState: .init())))
//        }
//}
