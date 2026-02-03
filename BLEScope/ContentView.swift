//
//  ContentView.swift
//  BLEScope
//
//  Created by 沉寂 on 2020/10/28.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var ble = BLEManager()

    var body: some View {
        RootView()
            .environmentObject(ble)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
