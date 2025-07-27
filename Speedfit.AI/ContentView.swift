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
    // Backend URL
    // TODO: Replace with your actual server IP before building
    private let backendURL = "http://192.168.35.143:8000"
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
    
    enum LiftType: String, CaseIterable {
        case squat = "Squat"
        case benchPress = "Bench Press"
        case deadlift = "Deadlift"
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
                
                if let videoURL = processedVideoURL ?? selectedVideoURL {
                    VideoPlayer(player: AVPlayer(url: videoURL))
                        .frame(height: 400)
                        .cornerRadius(12)
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 400)
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
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .alert("Upload Status", isPresented: $showAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(alertMessage)
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
}

#Preview {
    ContentView()
}
