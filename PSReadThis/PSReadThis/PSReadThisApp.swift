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
        Task {
            await TokenManager.shared.debugKeychainAccess()
            await TokenManager.shared.debugKeychainEntitlements()
            await TokenManager.shared.debugPrintAccessToken()
        }
    }
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
