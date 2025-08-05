//
//  ResultsView.swift
//  Speedfit.AI
//
//  Created by Claude Code on 8/2/25.
//

import SwiftUI
import AVKit

struct ResultsView: View {
    @ObservedObject var workoutData: WorkoutData
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Gradient background
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
                    // Video Player Section
                    if let videoURL = workoutData.processedVideoURL {
                        VideoPlayer(player: AVPlayer(url: videoURL))
                            .frame(height: 300)
                            .cornerRadius(0)
                    }
                    
                    // Results Section
                    ScrollView {
                        VStack(spacing: 24) {
                            // Header
                            VStack(spacing: 8) {
                                Text("\(workoutData.liftType.rawValue) - \(workoutData.weight)kg")
                                    .font(.title)
                                    .fontWeight(.bold)
                                    .foregroundColor(.black)
                                    .padding(.top, 20)
                            }
                            
                            // Key Metrics Cards
                            if let metrics = workoutData.sessionMetrics {
                                HStack(spacing: 16) {
                                    // Load Card
                                    MetricCard(
                                        title: "LOAD",
                                        value: workoutData.weight,
                                        color: .orange
                                    )
                                    
                                    // Reps Card
                                    MetricCard(
                                        title: "REPS",
                                        value: "\(metrics.total_reps)",
                                        color: .pink
                                    )
                                    
                                    // Velocity Card
                                    MetricCard(
                                        title: "VELOCITY",
                                        value: String(format: "%.2f", metrics.session_average ?? 0.0),
                                        color: .purple
                                    )
                                }
                                .padding(.horizontal, 24)
                                
                                // Highlights Section
                                VStack(alignment: .leading, spacing: 16) {
                                    Text("Highlights")
                                        .font(.title2)
                                        .fontWeight(.bold)
                                        .foregroundColor(.black)
                                        .padding(.horizontal, 24)
                                    
                                    // Mean Velocity Card
                                    VStack(alignment: .leading, spacing: 16) {
                                        Text("Mean velocity")
                                            .font(.headline)
                                            .foregroundColor(.white)
                                        
                                        HStack(spacing: 24) {
                                            VStack(alignment: .leading) {
                                                Text("Best")
                                                    .font(.caption)
                                                    .foregroundColor(.white.opacity(0.7))
                                                Text(String(format: "%.2f", metrics.rep_speeds.max() ?? 0.0))
                                                    .font(.title3)
                                                    .fontWeight(.bold)
                                                    .foregroundColor(.white)
                                                Text("m/s")
                                                    .font(.caption)
                                                    .foregroundColor(.white.opacity(0.7))
                                            }
                                            
                                            VStack(alignment: .leading) {
                                                Text("Average")
                                                    .font(.caption)
                                                    .foregroundColor(.white.opacity(0.7))
                                                Text(String(format: "%.2f", metrics.session_average ?? 0.0))
                                                    .font(.title3)
                                                    .fontWeight(.bold)
                                                    .foregroundColor(.white)
                                                Text("m/s")
                                                    .font(.caption)
                                                    .foregroundColor(.white.opacity(0.7))
                                            }
                                            
                                            Spacer()
                                        }
                                        
                                        // Simple Bar Chart
                                        HStack(alignment: .bottom, spacing: 8) {
                                            ForEach(Array(metrics.rep_speeds.enumerated()), id: \.offset) { index, speed in
                                                VStack {
                                                    Rectangle()
                                                        .fill(Color.green)
                                                        .frame(width: 40, height: CGFloat(speed * 100))
                                                        .cornerRadius(4)
                                                    
                                                    Text("\(index + 1)")
                                                        .font(.caption)
                                                        .foregroundColor(.white.opacity(0.7))
                                                }
                                            }
                                            Spacer()
                                        }
                                        .frame(height: 120)
                                        .padding(.top, 8)
                                    }
                                    .padding(20)
                                    .background(Color.black.opacity(0.8))
                                    .cornerRadius(16)
                                    .padding(.horizontal, 24)
                                    
                                    // Individual Reps Section
                                    VStack(alignment: .leading, spacing: 12) {
                                        Text("Individual Reps")
                                            .font(.headline)
                                            .foregroundColor(.black)
                                            .padding(.horizontal, 24)
                                        
                                        ForEach(Array(metrics.rep_speeds.enumerated()), id: \.offset) { index, speed in
                                            HStack {
                                                Text("Rep \(index + 1):")
                                                    .font(.body)
                                                    .foregroundColor(.black)
                                                Spacer()
                                                Text("\(speed, specifier: "%.2f") m/s")
                                                    .font(.body)
                                                    .fontWeight(.semibold)
                                                    .foregroundColor(.black)
                                            }
                                            .padding(.horizontal, 24)
                                            .padding(.vertical, 8)
                                            .background(Color.white.opacity(0.3))
                                            .cornerRadius(8)
                                            .padding(.horizontal, 24)
                                        }
                                    }
                                }
                            }
                            
                            Spacer(minLength: 100)
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        // Reset data and dismiss
                        workoutData.reset()
                        dismiss()
                    }
                    .foregroundColor(.black)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        // Share functionality could be added here
                    }) {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundColor(.black)
                    }
                }
            }
        }
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.white)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 80)
        .background(
            LinearGradient(
                colors: [color, color.opacity(0.7)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(16)
    }
}

#Preview {
    let workoutData = WorkoutData()
    workoutData.liftType = .squat
    workoutData.weight = "175"
    workoutData.sessionMetrics = SessionMetrics(
        session_average: 1.8,
        total_reps: 3,
        rep_speeds: [1.5, 2.1, 1.8],
        calibration_used: true,
        pixels_per_meter: 800.0
    )
    
    return ResultsView(workoutData: workoutData)
}