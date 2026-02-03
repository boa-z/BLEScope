//
//  Extensions.swift
//  BLEScope
//
//  Created by 沉寂 on 2020/10/28.
//

import Foundation
import SwiftUI
import CoreBluetooth

extension Data {
    func hexString() -> String {
        map { String(format: "%02X", $0) }.joined(separator: " ")
    }

    func asciiString() -> String {
        String(bytes: map { byte in
            (byte >= 32 && byte <= 126) ? byte : 46
        }, encoding: .utf8) ?? ""
    }
}

extension String {
    func hexToData() -> Data? {
        let cleaned = self.replacingOccurrences(of: "[^0-9A-Fa-f]", with: "", options: .regularExpression)
        guard cleaned.count % 2 == 0, !cleaned.isEmpty else { return nil }
        var data = Data(capacity: cleaned.count / 2)
        var index = cleaned.startIndex
        while index < cleaned.endIndex {
            let next = cleaned.index(index, offsetBy: 2)
            let byteString = cleaned[index..<next]
            if let byte = UInt8(byteString, radix: 16) {
                data.append(byte)
            } else {
                return nil
            }
            index = next
        }
        return data
    }
}

extension CBCharacteristicProperties {
    var shortDescription: String {
        var parts: [String] = []
        if contains(.read) { parts.append("Read") }
        if contains(.write) { parts.append("Write") }
        if contains(.writeWithoutResponse) { parts.append("WriteNR") }
        if contains(.notify) { parts.append("Notify") }
        if contains(.indicate) { parts.append("Indicate") }
        if contains(.broadcast) { parts.append("Broadcast") }
        if contains(.authenticatedSignedWrites) { parts.append("Signed") }
        if contains(.extendedProperties) { parts.append("Extended") }
        return parts.isEmpty ? "-" : parts.joined(separator: ", ")
    }
}

extension View {
    func onTapEndEditing() -> some View {
        ZStack {
            Color(.systemBackground)
                .opacity(0.000001)
                .onTapGesture(count: 1) {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                                    to: nil,
                                                    from: nil,
                                                    for: nil)
                }
            self
        }
    }
}
