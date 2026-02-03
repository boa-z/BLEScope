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

            SettingsView()
                .tabItem {
                    Image(systemName: "gearshape")
                    Text("Settings")
                }
        }
    }
}
