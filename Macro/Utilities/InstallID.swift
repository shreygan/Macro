//
//  InstallID.swift
//  Macro
//
//  Created by Shrey Gangwar on 10/16/26.
//

import Foundation
import Security

nonisolated enum InstallID {
    private static let service = "com.Shreyanka.Macro.installID"

    static let current: String = load() ?? create()

    private static var query: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "installID",
            kSecAttrSynchronizable as String: false,
        ]
    }

    private static func load() -> String? {
        var request = query
        request[kSecReturnData as String] = true
        request[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        guard SecItemCopyMatching(request as CFDictionary, &result) == errSecSuccess,
            let data = result as? Data
        else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func create() -> String {
        let id = UUID().uuidString
        var item = query
        item[kSecValueData as String] = Data(id.utf8)
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(item as CFDictionary, nil)
        return id
    }
}
