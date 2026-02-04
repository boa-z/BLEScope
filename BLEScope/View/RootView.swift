import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            ScanView()
                .tabItem {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                    Text("Devices")
                }

            LogView()
                .tabItem {
                    Image(systemName: "doc.text.magnifyingglass")
                    Text("Logs")
                }

            ToolsView()
                .tabItem {
                    Image(systemName: "wrench.and.screwdriver")
                    Text("Tools")
                }

            SettingsView()
                .tabItem {
                    Image(systemName: "gearshape")
                    Text("Settings")
                }
        }
    }
}
