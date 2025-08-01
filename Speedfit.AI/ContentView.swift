//
//  ContentView.swift
//  Speedfit.AI
//
//  Created by 이찬주 on 7/25/25.
//

import SwiftUI
import PhotosUI
import AVKit

struct ContentView: View {
    // Backend URL - Configuration should be externalized for production  
    private let backendURL = "http://172.20.10.3:8000"
    //When @state variable's value changed, SwiftUI invalidates the view and re-renders the body
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedVideoURL: URL?
    @State private var showingVideoPicker = false
    @State private var weight: String = ""
    @State private var liftType: LiftType = .squat
    @State private var isUploading = false
    @State private var processedVideoURL: URL?
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var plateSize: PlateSize = .standard45
    @State private var showCameraGuidance = false
    @State private var sessionMetrics: SessionMetrics?
    
    struct SessionMetrics: Codable {
        let session_average: Double?
        let total_reps: Int
        let rep_speeds: [Double]
        let calibration_used: Bool
        let pixels_per_meter: Double
    }
    
    enum LiftType: String, CaseIterable {
        case squat = "Squat"
        case benchPress = "Bench Press"
        case deadlift = "Deadlift"
    }
    
    enum PlateSize: String, CaseIterable {
        case standard45 = "45cm (Olympic)"
        case standard35 = "35cm (Standard)"
        case standard25 = "25cm (Small)"
        
        var diameter: Double {
            switch self {
            case .standard45: return 0.45 // meters
            case .standard35: return 0.35
            case .standard25: return 0.25
            }
        }
    }
    //body property describes the layout and components of your view
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Speedfit.AI")
                    .font(.largeTitle)
                    .bold()
                
                Picker("Lift Type", selection: $liftType) {
                    ForEach(LiftType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                
                TextField("Weight (kg/lbs)", text: $weight)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.numberPad)
                    .padding()
                
                VStack(alignment: .leading, spacing: 10) {
                    Text("Plate Size for Calibration")
                        .font(.headline)
                    
                    Picker("Plate Size", selection: $plateSize) {
                        ForEach(PlateSize.allCases, id: \.self) { size in
                            Text(size.rawValue).tag(size)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    
                    Button(action: {
                        showCameraGuidance = true
                    }) {
                        Label("Camera Setup Guide", systemImage: "camera.viewfinder")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
                .padding()
                
                if let videoURL = processedVideoURL ?? selectedVideoURL {
                    VideoPlayer(player: AVPlayer(url: videoURL))
                        .frame(height: 250)
                        .cornerRadius(12)
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 250)
                        .cornerRadius(12)
                        .overlay(
                            Text("No video selected")
                                .foregroundColor(.gray)
                        )
                }
                //this is UI component for users to select video from photo library
                PhotosPicker(
                    selection: $selectedItem,
                    matching: .videos
                ) {
                    Label("Select Video", systemImage: "video.badge.plus")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(10)
                }
                
                // .onChange modifier observes the selectedItem variable. If it changes, it executes inner codes
                .onChange(of: selectedItem) { newItem in
                    Task {
                        if let data = try? await newItem?.loadTransferable(type: Data.self) {
                            // Save video to temporary directory
                            // Loaded data us written to a temporary file on the device's local storaoge
                            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("selected_video.mov")
                            try? data.write(to: tempURL)
                            selectedVideoURL = tempURL
                            processedVideoURL = nil // Reset processed video when new video is selected
                            sessionMetrics = nil // Reset metrics when new video is selected
                        }
                    }
                }
                
                if selectedVideoURL != nil {
                    Button(action: {
                        Task {
                            await uploadVideo()
                        }
                    }) {
                        Label(isUploading ? "Analyzing..." : "Analyze Lift", systemImage: "waveform.path")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(isUploading ? Color.gray : Color.green)
                            .cornerRadius(10)
                    }
                    .disabled(isUploading)
                }
                
                // Display session metrics if available
                if let metrics = sessionMetrics {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Session Results")
                            .font(.headline)
                            .padding(.top)
                        
                        // Session Summary
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Session Average")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("\(metrics.session_average ?? 0.0, specifier: "%.2f") m/s")
                                    .font(.title2)
                                    .bold()
                                    .foregroundColor(.blue)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .leading) {
                                Text("Total Reps")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("\(metrics.total_reps)")
                                    .font(.title2)
                                    .bold()
                                    .foregroundColor(.green)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing) {
                                Text("Calibration")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(metrics.calibration_used ? "✓" : "⚠")
                                    .font(.caption)
                                    .foregroundColor(metrics.calibration_used ? .green : .orange)
                            }
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                        
                        // Individual Rep Speeds
                        if !metrics.rep_speeds.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Individual Reps")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                ForEach(Array(metrics.rep_speeds.enumerated()), id: \.offset) { index, speed in
                                    HStack {
                                        Text("Rep \(index + 1):")
                                            .font(.caption)
                                        Spacer()
                                        Text("\(speed, specifier: "%.2f") m/s")
                                            .font(.caption)
                                            .bold()
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .alert("Upload Status", isPresented: $showAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
            .alert("Camera Setup Guide", isPresented: $showCameraGuidance) {
                Button("Got it", role: .cancel) { }
            } message: {
                Text("For accurate speed detection:\n\n• Position camera 90° to the side of the bar\n• Keep camera steady and at barbell height\n• Ensure the selected plate size is clearly visible\n• Maintain consistent distance from the bar\n• Good lighting on the plates is essential")
            }
        }
    }
    //this function is for communication with main.py the backend part
    func uploadVideo() async {
        guard let videoURL = selectedVideoURL else { return }
        
        isUploading = true
        defer { isUploading = false }
        
        do {
            let videoData = try Data(contentsOf: videoURL)
            
            var request = URLRequest(url: URL(string: "\(backendURL)/analyze-lift/")!)
            request.httpMethod = "POST"
            
            let boundary = "Boundary-\(UUID().uuidString)"
            request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            
            var body = Data()
            
            // Add the video file to the request body
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            //content-Disposition declares that this section contains form data
            //The name "video" must match with parameter name in my FastAPI endpoint to crrectly identify the data
            body.append("Content-Disposition: form-data; name=\"video\"; filename=\"video.mov\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: video/quicktime\r\n\r\n".data(using: .utf8)!)
            body.append(videoData)
            body.append("\r\n".data(using: .utf8)!)
            
            // Add plate diameter for calibration
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"plate_diameter\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(plateSize.diameter)".data(using: .utf8)!)
            body.append("\r\n".data(using: .utf8)!)
            body.append("--\(boundary)--\r\n".data(using: .utf8)!)
            
            //fully constructed body is assigned to the URLRequest
            request.httpBody = body
            
            //this is the modern Swift concurrency API for executing a network request
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw URLError(.badServerResponse)
            }
            
            if httpResponse.statusCode == 200 {
                // Save the processed video
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("processed_video.mp4")
                try data.write(to: tempURL)
                
                // Try to fetch session metrics
                await fetchSessionMetrics()
                
                // Update the UI on the main thread
                await MainActor.run {
                    processedVideoURL = tempURL
                    alertMessage = "Video processed successfully!"
                    showAlert = true
                }
            } else {
                throw URLError(.badServerResponse)
            }
        } catch {
            await MainActor.run {
                alertMessage = "Error: \(error.localizedDescription)"
                showAlert = true
            }
        }
    }
    
    func fetchSessionMetrics() async {
        // Since we don't have a specific video ID from the backend yet,
        // we'll create a simple implementation that waits and tries to fetch
        // This would need to be improved with proper video ID handling
        
        do {
            // For now, we'll use a mock implementation
            // In a real implementation, you'd get the video ID from the upload response
            let mockMetrics = SessionMetrics(
                session_average: 1.8,
                total_reps: 3,
                rep_speeds: [1.5, 2.1, 1.8],
                calibration_used: true,
                pixels_per_meter: 800.0
            )
            
            await MainActor.run {
                sessionMetrics = mockMetrics
            }
        } catch {
            print("Failed to fetch session metrics: \(error)")
        }
    }
}

#Preview {
    ContentView()
}
