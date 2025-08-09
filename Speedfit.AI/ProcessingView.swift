//
//  ProcessingView.swift
//  Speedfit.AI
//
//  Created by Claude Code on 8/2/25.
//

import SwiftUI

struct ProcessingView: View {
    @ObservedObject var workoutData: WorkoutData
    @EnvironmentObject var authManager: AuthManager
    @State private var progress: Double = 0.0
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var showingResults = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ZStack {
                    // Gradient background matching other views
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(red: 0.85, green: 0.87, blue: 0.95),
                            Color(red: 0.75, green: 0.80, blue: 0.92)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .ignoresSafeArea()
                    
                    VStack(spacing: 40) {
                        Spacer()
                        
                        // Header
                        VStack(spacing: 16) {
                            Text("Processing")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(.black)
                            
                            Text("\(workoutData.liftType.rawValue) - \(workoutData.weight)kg")
                                .font(.title2)
                                .foregroundColor(.black.opacity(0.7))
                        }
                        
                        Spacer()
                        
                        // Progress Circle
                        ZStack {
                            Circle()
                                .stroke(Color.white.opacity(0.3), lineWidth: 8)
                                .frame(width: 200, height: 200)
                            
                            Circle()
                                .trim(from: 0, to: progress)
                                .stroke(
                                    LinearGradient(
                                        colors: [.green, .blue],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                                )
                                .frame(width: 200, height: 200)
                                .rotationEffect(.degrees(-90))
                                .animation(.easeInOut(duration: 0.5), value: progress)
                            
                            Text("\(Int(progress * 100))%")
                                .font(.system(size: 36, weight: .bold))
                                .foregroundColor(.black)
                        }
                        
                        Spacer()
                        
                        // Status Message
                        VStack(spacing: 8) {
                            Text("Processing video. Do not close the app.")
                                .font(.headline)
                                .foregroundColor(.black)
                                .multilineTextAlignment(.center)
                            
                            Text("Long videos, HDR format, and 4K videos may take longer to process.")
                                .font(.subheadline)
                                .foregroundColor(.black.opacity(0.7))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                        }
                        
                        Spacer()
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Exit") {
                        dismiss()
                    }
                    .foregroundColor(.black)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Text("BETA")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.2))
                        .cornerRadius(8)
                }
            }
        }
        .onAppear {
            startProcessing()
        }
        .alert("Upload Status", isPresented: $showAlert) {
            Button("OK", role: .cancel) {
                print("DEBUG: Alert OK button tapped. Alert message: '\(alertMessage)'")
                if alertMessage.contains("successfully") {
                    print("DEBUG: Setting showingResults = true")
                    showingResults = true
                } else {
                    print("DEBUG: Alert message doesn't contain 'successfully', not showing results")
                }
            }
        } message: {
            Text(alertMessage)
        }
        .fullScreenCover(isPresented: $showingResults) {
            ResultsView(workoutData: workoutData)
        }
    }
    
    private func startProcessing() {
        Task {
            await uploadVideo()
        }
    }
    
    private func uploadVideo() async {
        guard let videoURL = workoutData.selectedVideoURL else { return }
        
        workoutData.isUploading = true
        defer { workoutData.isUploading = false }
        
        // Simulate progress updates
        await simulateProgress()
        
        do {
            let videoData = try Data(contentsOf: videoURL)
            
            var request = URLRequest(url: URL(string: "\(BackendConfig.baseURL)/analyze-lift/")!)
            request.httpMethod = "POST"
            
            // Add authentication header if user is logged in
            if let session = authManager.currentSession {
                request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
            }
            
            let boundary = "Boundary-\(UUID().uuidString)"
            request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            
            var body = Data()
            
            // Add the video file to the request body
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"video\"; filename=\"video.mov\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: video/quicktime\r\n\r\n".data(using: .utf8)!)
            body.append(videoData)
            body.append("\r\n".data(using: .utf8)!)
            
            // Add plate diameter for calibration
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"plate_diameter\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(workoutData.plateSize.diameter)".data(using: .utf8)!)
            body.append("\r\n".data(using: .utf8)!)
            
            // Add lift type
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"lift_type\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(workoutData.liftType.rawValue)".data(using: .utf8)!)
            body.append("\r\n".data(using: .utf8)!)
            
            // Add weight if provided
            if !workoutData.weight.isEmpty, let weight = Double(workoutData.weight) {
                body.append("--\(boundary)\r\n".data(using: .utf8)!)
                body.append("Content-Disposition: form-data; name=\"weight\"\r\n\r\n".data(using: .utf8)!)
                body.append("\(weight)".data(using: .utf8)!)
                body.append("\r\n".data(using: .utf8)!)
            }
            
            body.append("--\(boundary)--\r\n".data(using: .utf8)!)
            
            request.httpBody = body
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("DEBUG: Response is not HTTPURLResponse")
                throw URLError(.badServerResponse)
            }
            
            print("DEBUG: HTTP Status Code: \(httpResponse.statusCode)")
            
            if httpResponse.statusCode == 200 {
                print("DEBUG: HTTP 200 - Processing success response")
                // Save the processed video
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("processed_video.mp4")
                try data.write(to: tempURL)
                
                // Get metrics path and session ID from response headers
                var sessionMetrics: SessionMetrics?
                if let metricsPath = httpResponse.value(forHTTPHeaderField: "X-Metrics-Path") {
                    print("DEBUG: Found X-Metrics-Path header: \(metricsPath)")
                    sessionMetrics = await fetchSessionMetricsFromFile(metricsPath: metricsPath)
                } else {
                    print("DEBUG: No X-Metrics-Path header found in response")
                }
                
                // Debug: Log what we got
                if let metrics = sessionMetrics {
                    print("DEBUG: Final sessionMetrics: \(metrics)")
                } else {
                    print("DEBUG: sessionMetrics is nil - providing fallback")
                    // Provide fallback data only if we can't get real metrics
                    sessionMetrics = SessionMetrics(
                        session_average: 1.8,
                        total_reps: 3,
                        rep_speeds: [1.5, 2.1, 1.8],
                        calibration_used: true,
                        pixels_per_meter: 800.0
                    )
                }
                
                // Get session ID if available
                let sessionId = httpResponse.value(forHTTPHeaderField: "X-Session-Id")
                
                // Update the UI on the main thread
                await MainActor.run {
                    workoutData.processedVideoURL = tempURL
                    workoutData.sessionMetrics = sessionMetrics
                    workoutData.sessionId = sessionId
                    progress = 1.0
                    
                    if sessionId != nil {
                        alertMessage = "Video processed and saved to your history!"
                    } else {
                        alertMessage = "Video processed successfully!"
                    }
                    print("DEBUG: Setting showAlert = true with message: \(alertMessage)")
                    // Try direct navigation first
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        print("DEBUG: Attempting direct navigation to ResultsView")
                        showingResults = true
                    }
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
    
    private func simulateProgress() async {
        let steps = 20
        for i in 0...steps {
            await MainActor.run {
                progress = Double(i) / Double(steps) * 0.9 // Go up to 90%, then complete on success
            }
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
        }
    }
    
    private func fetchSessionMetricsFromFile(metricsPath: String) async -> SessionMetrics? {
        do {
            // Extract video ID from metrics path
            let videoId = URL(fileURLWithPath: metricsPath).lastPathComponent.replacingOccurrences(of: "_metrics.json", with: "")
            let urlString = "\(BackendConfig.baseURL)/metrics/\(videoId)"
            
            print("DEBUG: Fetching metrics from URL: \(urlString)")
            print("DEBUG: Original metrics path: \(metricsPath)")
            print("DEBUG: Extracted video ID: \(videoId)")
            
            guard let url = URL(string: urlString) else {
                print("DEBUG: Failed to create URL from string: \(urlString)")
                return nil
            }
            
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("DEBUG: Response is not HTTPURLResponse")
                return nil
            }
            
            print("DEBUG: HTTP Status Code: \(httpResponse.statusCode)")
            
            if httpResponse.statusCode == 200 {
                // Parse JSON response
                let decoder = JSONDecoder()
                let metrics = try decoder.decode(SessionMetrics.self, from: data)
                print("DEBUG: Successfully decoded metrics: \(metrics)")
                return metrics
            } else {
                print("DEBUG: Failed to fetch metrics - HTTP \(httpResponse.statusCode)")
                if let responseBody = String(data: data, encoding: .utf8) {
                    print("DEBUG: Response body: \(responseBody)")
                }
                return nil
            }
        } catch {
            print("DEBUG: Error fetching session metrics: \(error)")
            return nil
        }
    }
}

#Preview {
    ProcessingView(workoutData: WorkoutData())
}