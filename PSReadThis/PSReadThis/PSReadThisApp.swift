//
//  PSReadThisApp.swift
//  PSReadThis
//
//  Created by Pavel S on 6/7/25.
//

import SwiftUI

@main
struct PSReadThisApp: App {
    init() {
        #if DEBUG
        // Run heavy startup diagnostics only when explicitly enabled
        if UserDefaults.standard.bool(forKey: "EnableStartupDiagnostics") {
            Task {
                await TokenManager.shared.debugKeychainAccess()
                await TokenManager.shared.debugKeychainEntitlements()
                await TokenManager.shared.debugPrintAccessToken()
            }
        }
        #endif
    }
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
