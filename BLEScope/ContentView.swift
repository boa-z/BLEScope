//
//  ContentView.swift
//  BLEScope
//
//  Created by 沉寂 on 2020/10/28.
//

import SwiftUI
import UIKit

struct ContentView: View {
    @StateObject private var ble = BLEManager()

    var body: some View {
        RootView()
            .environmentObject(ble)
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                ble.persistLogsIfNeeded()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willTerminateNotification)) { _ in
                ble.persistLogsIfNeeded()
            }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
