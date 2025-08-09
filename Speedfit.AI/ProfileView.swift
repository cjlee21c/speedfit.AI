//
//  ProfileView.swift
//  Speedfit.AI
//
//  Created by Claude Code on 8/5/25.
//

import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var preferredUnits = "metric"
    @State private var defaultPlateSize = "45cm (Olympic)"
    @State private var notificationsEnabled = true
    @State private var isLoading = false
    @State private var showingSignOutAlert = false
    
    let unitsOptions = ["metric", "imperial"]
    let plateSizeOptions = ["45cm (Olympic)", "35cm (Standard)", "25cm (Small)"]
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                ZStack {
                    // Gradient background matching your app design
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(red: 0.85, green: 0.87, blue: 0.95),
                            Color(red: 0.75, green: 0.80, blue: 0.92)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .ignoresSafeArea()
                    
                    ScrollView {
                        VStack(spacing: 30) {
                            // Profile Header
                            VStack(spacing: 16) {
                                // Profile Avatar
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(colors: [
                                                Color.blue,
                                                Color.blue.opacity(0.7)
                                            ]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 80, height: 80)
                                    .overlay(
                                        Text(authManager.userProfile?.fullName?.prefix(1).uppercased() ?? "U")
                                            .font(.largeTitle)
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                    )
                                
                                VStack(spacing: 4) {
                                    Text(authManager.userProfile?.fullName ?? "User")
                                        .font(.title2)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.primary)
                                    
                                    Text(authManager.userProfile?.email ?? "")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.top, 20)
                            
                            // Settings Section
                            VStack(spacing: 20) {
                                // Section Header
                                HStack {
                                    Text("Settings")
                                        .font(.title3)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.primary)
                                    Spacer()
                                }
                                
                                // Settings Card
                                VStack(spacing: 20) {
                                    // Units Preference
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Preferred Units")
                                            .font(.headline)
                                            .foregroundColor(.primary)
                                        
                                        Picker("Units", selection: $preferredUnits) {
                                            ForEach(unitsOptions, id: \.self) { unit in
                                                Text(unit.capitalized).tag(unit)
                                            }
                                        }
                                        .pickerStyle(SegmentedPickerStyle())
                                    }
                                    
                                    Divider()
                                    
                                    // Default Plate Size
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Default Plate Size")
                                            .font(.headline)
                                            .foregroundColor(.primary)
                                        
                                        Picker("Plate Size", selection: $defaultPlateSize) {
                                            ForEach(plateSizeOptions, id: \.self) { size in
                                                Text(size).tag(size)
                                            }
                                        }
                                        .pickerStyle(MenuPickerStyle())
                                    }
                                    
                                    Divider()
                                    
                                    // Notifications Toggle
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Notifications")
                                                .font(.headline)
                                                .foregroundColor(.primary)
                                            
                                            Text("Get reminders for workouts")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        
                                        Spacer()
                                        
                                        Toggle("", isOn: $notificationsEnabled)
                                    }
                                }
                                .padding(20)
                                .background(Color(.systemBackground).opacity(0.8))
                                .cornerRadius(12)
                                .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
                            }
                            .padding(.horizontal, 20)
                            
                            // Sign Out Section
                            VStack(spacing: 16) {
                                Button(action: {
                                    showingSignOutAlert = true
                                }) {
                                    HStack {
                                        Image(systemName: "arrow.right.square")
                                        Text("Sign Out")
                                    }
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 50)
                                    .background(Color.red.opacity(0.1))
                                    .foregroundColor(.red)
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.red.opacity(0.3), lineWidth: 1)
                                    )
                                }
                                .padding(.horizontal, 20)
                            }
                        }
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .alert("Sign Out", isPresented: $showingSignOutAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Sign Out", role: .destructive) {
                Task {
                    await authManager.signOut()
                }
            }
        } message: {
            Text("Are you sure you want to sign out?")
        }
        .task {
            await loadUserSettings()
        }
        .onChange(of: preferredUnits) { _ in saveSettings() }
        .onChange(of: defaultPlateSize) { _ in saveSettings() }
        .onChange(of: notificationsEnabled) { _ in saveSettings() }
    }
    
    private func loadUserSettings() async {
        isLoading = true
        
        if let settings = await dataManager.loadUserSettings() {
            preferredUnits = settings.preferredUnits
            defaultPlateSize = settings.defaultPlateSize
            notificationsEnabled = settings.notificationsEnabled
        }
        
        isLoading = false
    }
    
    private func saveSettings() {
        Task {
            let settings = [
                "preferred_units": preferredUnits,
                "default_plate_size": defaultPlateSize,
                "notifications_enabled": notificationsEnabled
            ]
            
            await dataManager.updateUserSettings(settings)
        }
    }
}

#Preview {
    ProfileView()
        .environmentObject(AuthManager())
        .environmentObject(DataManager())
}