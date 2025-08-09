//
//  Speedfit_AIApp.swift
//  Speedfit.AI
//
//  Created by 이찬주 on 7/25/25.
//

import SwiftUI

@main
struct Speedfit_AIApp: App {      //when the app starts, this file checks the value of authManager and dataManager
    //this checks if the user is already logged in. If it is, it show users the main app. If not, go to log in page
    @StateObject private var authManager = AuthManager()
    @StateObject private var dataManager = DataManager()
    
    var body: some Scene {
        WindowGroup {
            Group {
                if authManager.isAuthenticated {
                    HomeView()
                        .environmentObject(authManager)
                        .environmentObject(dataManager)
                } else {
                    LoginView()
                        .environmentObject(authManager)
                }
            }
        }
    }
}
