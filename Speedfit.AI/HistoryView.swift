//
//  HistoryView.swift
//  Speedfit.AI
//
//  Created by Claude Code on 8/5/25.
//

import SwiftUI
import Charts

struct HistoryView: View {
    @EnvironmentObject var dataManager: DataManager
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedTimeRange = "1M"
    @State private var showingProfile = false
    @State private var selectedSession: WorkoutSession?
    
    let timeRanges = ["1W", "1M", "3M", "6M", "1Y"]
    
    var filteredSessions: [WorkoutSession] {
        let now = Date()
        let calendar = Calendar.current
        
        let cutoffDate: Date
        switch selectedTimeRange {
        case "1W":
            cutoffDate = calendar.date(byAdding: .weekOfYear, value: -1, to: now) ?? now
        case "1M":
            cutoffDate = calendar.date(byAdding: .month, value: -1, to: now) ?? now
        case "3M":
            cutoffDate = calendar.date(byAdding: .month, value: -3, to: now) ?? now
        case "6M":
            cutoffDate = calendar.date(byAdding: .month, value: -6, to: now) ?? now
        case "1Y":
            cutoffDate = calendar.date(byAdding: .year, value: -1, to: now) ?? now
        default:
            cutoffDate = calendar.date(byAdding: .month, value: -1, to: now) ?? now
        }
        
        return dataManager.workoutSessions.filter { session in
            session.sessionDate >= cutoffDate
        }
    }
    
    var averageVelocity: Double {
        let sessions = filteredSessions.compactMap { $0.sessionAverage }
        guard !sessions.isEmpty else { return 0.0 }
        return sessions.reduce(0, +) / Double(sessions.count)
    }
    
    var totalWorkouts: Int {
        filteredSessions.count
    }
    
    var totalReps: Int {
        filteredSessions.reduce(0) { $0 + $1.totalReps }
    }
    
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
                        VStack(spacing: 20) {
                            // Time Range Selector
                            VStack(spacing: 12) {
                                HStack {
                                    Text("Time Range")
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    Spacer()
                                }
                                
                                HStack(spacing: 8) {
                                    ForEach(timeRanges, id: \.self) { range in
                                        Button(action: {
                                            selectedTimeRange = range
                                        }) {
                                            Text(range)
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                                .foregroundColor(selectedTimeRange == range ? .white : .primary)
                                                .padding(.horizontal, 16)
                                                .padding(.vertical, 8)
                                                .background(
                                                    selectedTimeRange == range ?
                                                    Color.blue : Color(.systemGray6)
                                                )
                                                .cornerRadius(20)
                                        }
                                    }
                                    Spacer()
                                }
                            }
                            .padding(20)
                            .background(Color(.systemBackground).opacity(0.8))
                            .cornerRadius(12)
                            .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
                            
                            // Stats Overview
                            HStack(spacing: 16) {
                                StatCard(
                                    title: "Workouts",
                                    value: "\(totalWorkouts)",
                                    icon: "dumbbell.fill",
                                    color: .blue
                                )
                                
                                StatCard(
                                    title: "Total Reps",
                                    value: "\(totalReps)",
                                    icon: "repeat",
                                    color: .green
                                )
                                
                                StatCard(
                                    title: "Avg Speed",
                                    value: String(format: "%.2f m/s", averageVelocity),
                                    icon: "speedometer",
                                    color: .orange
                                )
                            }
                            
                            // Progress Chart
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Velocity Progress")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                if !filteredSessions.isEmpty {
                                    Chart {
                                        ForEach(filteredSessions.indices, id: \.self) { index in
                                            let session = filteredSessions[index]
                                            if let velocity = session.sessionAverage {
                                                LineMark(
                                                    x: .value("Date", session.sessionDate),
                                                    y: .value("Velocity", velocity)
                                                )
                                                .foregroundStyle(Color.blue)
                                                .symbol(Circle().strokeBorder(lineWidth: 2))
                                            }
                                        }
                                    }
                                    .frame(height: 200)
                                    .chartYAxis {
                                        AxisMarks(position: .leading)
                                    }
                                    .chartXAxis {
                                        AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                                            AxisGridLine()
                                            AxisTick()
                                            AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                                        }
                                    }
                                } else {
                                    VStack(spacing: 16) {
                                        Image(systemName: "chart.line.uptrend.xyaxis")
                                            .font(.system(size: 40))
                                            .foregroundColor(.gray)
                                        
                                        Text("No workout data for selected period")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                    .frame(height: 200)
                                }
                            }
                            .padding(20)
                            .background(Color(.systemBackground).opacity(0.8))
                            .cornerRadius(12)
                            .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
                            
                            // Recent Sessions
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Recent Sessions")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                if filteredSessions.isEmpty {
                                    VStack(spacing: 16) {
                                        Image(systemName: "clock.arrow.circlepath")
                                            .font(.system(size: 40))
                                            .foregroundColor(.gray)
                                        
                                        Text("No sessions yet")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                        
                                        Text("Complete a workout to see your history here")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .multilineTextAlignment(.center)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(40)
                                } else {
                                    LazyVStack(spacing: 12) {
                                        ForEach(filteredSessions.prefix(10)) { session in
                                            SessionRow(session: session) {
                                                selectedSession = session
                                            }
                                        }
                                    }
                                }
                            }
                            .padding(20)
                            .background(Color(.systemBackground).opacity(0.8))
                            .cornerRadius(12)
                            .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 40)
                    }
                    .refreshable {
                        await dataManager.loadWorkoutSessions()
                    }
                }
            }
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingProfile = true
                    }) {
                        Image(systemName: "person.circle")
                            .font(.title2)
                    }
                }
            }
        }
        .sheet(isPresented: $showingProfile) {
            ProfileView()
        }
        .sheet(item: $selectedSession) { session in
            SessionDetailView(session: session)
        }
        .task {
            await dataManager.loadWorkoutSessions()
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(Color(.systemBackground).opacity(0.8))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}

struct SessionRow: View {
    let session: WorkoutSession
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Lift Type Icon
                VStack {
                    Image(systemName: liftTypeIcon(session.liftType))
                        .font(.title2)
                        .foregroundColor(.blue)
                    
                    Text(session.liftType)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                .frame(width: 60)
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(session.sessionDate, style: .date)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        if let average = session.sessionAverage {
                            Text("\(average, specifier: "%.2f") m/s")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.blue)
                        }
                    }
                    
                    HStack {
                        Text("\(session.totalReps) reps")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if let weight = session.weight {
                            Text("• \(weight, specifier: "%.0f")kg")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Text(session.sessionDate, style: .time)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(12)
            .background(Color(.systemGray6).opacity(0.5))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func liftTypeIcon(_ liftType: String) -> String {
        switch liftType.lowercased() {
        case "squat":
            return "figure.strengthtraining.traditional"
        case "bench press":
            return "figure.strengthtraining.functional"
        case "deadlift":
            return "figure.strengthtraining.traditional"
        default:
            return "dumbbell.fill"
        }
    }
}

struct SessionDetailView: View {
    let session: WorkoutSession
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var dataManager: DataManager
    @State private var repAnalysis: [RepAnalysis] = []
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
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
                    
                    ScrollView {
                        VStack(spacing: 20) {
                            // Session Info
                            VStack(spacing: 16) {
                                Text(session.liftType)
                                    .font(.largeTitle)
                                    .fontWeight(.bold)
                                    .foregroundColor(.primary)
                                
                                Text(session.sessionDate, style: .date)
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                
                                if let average = session.sessionAverage {
                                    Text("\(average, specifier: "%.3f") m/s average")
                                        .font(.title2)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.blue)
                                }
                            }
                            .padding(20)
                            .background(Color(.systemBackground).opacity(0.8))
                            .cornerRadius(12)
                            .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
                            
                            // Rep Breakdown
                            if !repAnalysis.isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Rep Breakdown")
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    
                                    LazyVStack(spacing: 8) {
                                        ForEach(repAnalysis) { rep in
                                            HStack {
                                                Text("Rep \(rep.repNumber)")
                                                    .font(.subheadline)
                                                    .foregroundColor(.primary)
                                                
                                                Spacer()
                                                
                                                Text("\(rep.velocity, specifier: "%.3f") m/s")
                                                    .font(.subheadline)
                                                    .fontWeight(.medium)
                                                    .foregroundColor(.blue)
                                            }
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 8)
                                            .background(Color(.systemGray6).opacity(0.5))
                                            .cornerRadius(8)
                                        }
                                    }
                                }
                                .padding(20)
                                .background(Color(.systemBackground).opacity(0.8))
                                .cornerRadius(12)
                                .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationTitle("Session Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .task {
            repAnalysis = await dataManager.getRepAnalysis(for: session.id)
        }
    }
}

#Preview {
    HistoryView()
        .environmentObject(DataManager())
        .environmentObject(AuthManager())
}