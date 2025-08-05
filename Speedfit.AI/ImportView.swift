//
//  ImportView.swift
//  Speedfit.AI
//
//  Created by Claude Code on 8/2/25.
//

import SwiftUI
import PhotosUI
import AVKit

struct ImportView: View {
    @StateObject private var workoutData = WorkoutData()
    @State private var selectedItem: PhotosPickerItem?
    @State private var showCameraGuidance = false
    @State private var showingProcessing = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ZStack {
                    // Gradient background matching HomeView
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
                        VStack(spacing: 24) {
                            // Header
                            VStack(spacing: 8) {
                                Text("Import Video")
                                    .font(.largeTitle)
                                    .fontWeight(.bold)
                                    .foregroundColor(.black)
                                
                                Text("Set up your lift analysis")
                                    .font(.subheadline)
                                    .foregroundColor(.black.opacity(0.7))
                            }
                            .padding(.top, 20)
                            
                            // Video Selection Card
                            VStack(spacing: 16) {
                                if let videoURL = workoutData.selectedVideoURL {
                                    VideoPlayer(player: AVPlayer(url: videoURL))
                                        .frame(height: 200)
                                        .cornerRadius(12)
                                } else {
                                    PhotosPicker(
                                        selection: $selectedItem,
                                        matching: .videos
                                    ) {
                                        VStack(spacing: 12) {
                                            Image(systemName: "video.badge.plus")
                                                .font(.system(size: 40))
                                                .foregroundColor(.black.opacity(0.6))
                                            
                                            Text("Select Video")
                                                .font(.headline)
                                                .foregroundColor(.black.opacity(0.8))
                                            
                                            Text("Tap to choose from library")
                                                .font(.caption)
                                                .foregroundColor(.black.opacity(0.6))
                                        }
                                        .frame(height: 200)
                                        .frame(maxWidth: .infinity)
                                        .background(Color.white.opacity(0.3))
                                        .cornerRadius(12)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(Color.white.opacity(0.5), lineWidth: 2)
                                                .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8]))
                                        )
                                    }
                                }
                            }
                            .padding(.horizontal, 24)
                            
                            // Form Card
                            VStack(spacing: 20) {
                                // Workout Type
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Workout Type")
                                        .font(.headline)
                                        .foregroundColor(.black)
                                    
                                    Picker("Lift Type", selection: $workoutData.liftType) {
                                        ForEach(LiftType.allCases, id: \.self) { type in
                                            Text(type.rawValue).tag(type)
                                        }
                                    }
                                    .pickerStyle(SegmentedPickerStyle())
                                }
                                
                                // Weight Input
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Weight")
                                        .font(.headline)
                                        .foregroundColor(.black)
                                    
                                    TextField("Enter weight (kg/lbs)", text: $workoutData.weight)
                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                        .keyboardType(.numberPad)
                                }
                                
                                // Plate Size
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Plate Size for Calibration")
                                        .font(.headline)
                                        .foregroundColor(.black)
                                    
                                    Picker("Plate Size", selection: $workoutData.plateSize) {
                                        ForEach(PlateSize.allCases, id: \.self) { size in
                                            Text(size.rawValue).tag(size)
                                        }
                                    }
                                    .pickerStyle(SegmentedPickerStyle())
                                    
                                    // Camera Setup Guide Button
                                    Button(action: {
                                        showCameraGuidance = true
                                    }) {
                                        HStack {
                                            Image(systemName: "camera.viewfinder")
                                            Text("Camera Setup Guide")
                                        }
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                    }
                                    .padding(.top, 4)
                                }
                            }
                            .padding(20)
                            .background(Color.white.opacity(0.4))
                            .cornerRadius(16)
                            .padding(.horizontal, 24)
                            
                            Spacer(minLength: 100)
                        }
                    }
                    
                    // Bottom Confirm Button
                    VStack {
                        Spacer()
                        
                        Button(action: {
                            showingProcessing = true
                        }) {
                            HStack {
                                Image(systemName: "checkmark.circle")
                                    .font(.title2)
                                Text("Confirm")
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
                        .disabled(workoutData.selectedVideoURL == nil)
                        .opacity(workoutData.selectedVideoURL == nil ? 0.6 : 1.0)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 50)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.black)
                }
            }
        }
        .onChange(of: selectedItem) { newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                    let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("selected_video.mov")
                    try? data.write(to: tempURL)
                    await MainActor.run {
                        workoutData.selectedVideoURL = tempURL
                    }
                }
            }
        }
        .alert("Camera Setup Guide", isPresented: $showCameraGuidance) {
            Button("Got it", role: .cancel) { }
        } message: {
            Text("For accurate speed detection:\n\n• Position camera 90° to the side of the bar\n• Keep camera steady and at barbell height\n• Ensure the selected plate size is clearly visible\n• Maintain consistent distance from the bar\n• Good lighting on the plates is essential")
        }
        .fullScreenCover(isPresented: $showingProcessing) {
            ProcessingView(workoutData: workoutData)
        }
    }
}

#Preview {
    ImportView()
}