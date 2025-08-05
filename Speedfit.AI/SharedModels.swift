//
//  SharedModels.swift
//  Speedfit.AI
//
//  Created by Claude Code on 8/2/25.
//

import Foundation

// MARK: - Backend Configuration
struct BackendConfig {
    static let baseURL = "http://172.20.10.3:8000"
}

// MARK: - Session Metrics
struct SessionMetrics: Codable {
    let session_average: Double?
    let total_reps: Int
    let rep_speeds: [Double]
    let calibration_used: Bool
    let pixels_per_meter: Double
}

// MARK: - Lift Type
enum LiftType: String, CaseIterable {
    case squat = "Squat"
    case benchPress = "Bench Press"
    case deadlift = "Deadlift"
}

// MARK: - Plate Size
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

// MARK: - Workout Data
class WorkoutData: ObservableObject {
    @Published var selectedVideoURL: URL?
    @Published var weight: String = ""
    @Published var liftType: LiftType = .squat
    @Published var plateSize: PlateSize = .standard45
    @Published var processedVideoURL: URL?
    @Published var sessionMetrics: SessionMetrics?
    @Published var isUploading: Bool = false
    
    func reset() {
        selectedVideoURL = nil
        weight = ""
        liftType = .squat
        plateSize = .standard45
        processedVideoURL = nil
        sessionMetrics = nil
        isUploading = false
    }
}