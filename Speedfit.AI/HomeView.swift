//
//  HomeView.swift
//  Speedfit.AI
//
//  Created by Claude Code on 8/2/25.
//

import SwiftUI

struct HomeView: View {
    @State private var showingImport = false
    @State private var showingHistory = false
    
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ZStack {
                    // Gradient background similar to reference screenshots
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(red: 0.85, green: 0.87, blue: 0.95),
                            Color(red: 0.75, green: 0.80, blue: 0.92)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .ignoresSafeArea()
                    
                    VStack(spacing: 0) {
                        // Hero Section
                        VStack(spacing: 20) {
                            Spacer()
                            
                            // App Logo/Icon Area
                            Image(systemName: "figure.strengthtraining.traditional")
                                .font(.system(size: 80, weight: .light))
                                .foregroundColor(.black.opacity(0.8))
                                .padding(.bottom, 10)
                            
                            // Main Title
                            Text("Speedfit.AI")
                                .font(.system(size: 42, weight: .bold, design: .default))
                                .foregroundColor(.black)
                                .multilineTextAlignment(.center)
                            
                            // Subtitle
                            Text("AI-Powered Lift Analysis")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.black.opacity(0.7))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                            
                            Spacer()
                        }
                        .frame(height: geometry.size.height * 0.65)
                        
                        // Action Buttons Section
                        VStack(spacing: 16) {
                            // Primary Action Button
                            Button(action: {
                                showingImport = true
                            }) {
                                HStack {
                                    Image(systemName: "video.badge.plus")
                                        .font(.title2)
                                    Text("Import Video")
                                        .font(.title2)
                                        .fontWeight(.semibold)
                                }
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(Color.white)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                            }
                            
                            // Secondary Action Button
                            Button(action: {
                                showingHistory = true
                            }) {
                                HStack {
                                    Image(systemName: "clock.arrow.circlepath")
                                        .font(.title3)
                                    Text("View History")
                                        .font(.title3)
                                        .fontWeight(.medium)
                                }
                                .foregroundColor(.black.opacity(0.8))
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(Color.white.opacity(0.5))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.white, lineWidth: 1)
                                )
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 50)
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .fullScreenCover(isPresented: $showingImport) {
            ImportView()
        }
        .sheet(isPresented: $showingHistory) {
            // Placeholder for HistoryView
            NavigationView {
                VStack {
                    Text("View History")
                        .font(.largeTitle)
                        .padding()
                    Text("HistoryView will be implemented later")
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .navigationTitle("History")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            showingHistory = false
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    HomeView()
}
