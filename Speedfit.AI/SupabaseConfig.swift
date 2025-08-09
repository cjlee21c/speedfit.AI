//
//  SupabaseConfig.swift
//  Speedfit.AI
//
//  Created by Claude Code on 8/5/25.
//

import Foundation
import Supabase

// MARK: - Supabase Configuration
struct SupabaseConfig {
    // Replace these with your actual values from Supabase dashboard
    static let url = "https://qfhrfqgfsldoxlobynfh.supabase.co"
    static let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFmaHJmcWdmc2xkb3hsb2J5bmZoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTQzNjgyMzMsImV4cCI6MjA2OTk0NDIzM30.ODv-VKJovkNa2M-uHdcCLQ75qK0R1ShJ6zqkP9Zspag"
    static let client = SupabaseClient(
        supabaseURL: URL(string: url)!,
        supabaseKey: anonKey
    )
}

// MARK: - Database Models
struct UserProfile: Codable, Identifiable {
    let id: UUID
    let email: String?
    let fullName: String?
    let createdAt: Date
    let updatedAt: Date
    
    private enum CodingKeys: String, CodingKey {
        case id
        case email
        case fullName = "full_name"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct WorkoutSession: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let sessionDate: Date
    let liftType: String
    let weight: Double?
    let plateSize: String
    let sessionAverage: Double?
    let totalReps: Int
    let calibrationUsed: Bool
    let pixelsPerMeter: Double?
    let videoUrl: String?
    let processedVideoUrl: String?
    let createdAt: Date
    
    private enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case sessionDate = "session_date"
        case liftType = "lift_type"
        case weight
        case plateSize = "plate_size"
        case sessionAverage = "session_average"
        case totalReps = "total_reps"
        case calibrationUsed = "calibration_used"
        case pixelsPerMeter = "pixels_per_meter"
        case videoUrl = "video_url"
        case processedVideoUrl = "processed_video_url"
        case createdAt = "created_at"
    }
}

struct RepAnalysis: Codable, Identifiable {
    let id: UUID
    let sessionId: UUID
    let repNumber: Int
    let velocity: Double
    let createdAt: Date
    
    private enum CodingKeys: String, CodingKey {
        case id
        case sessionId = "session_id"
        case repNumber = "rep_number"
        case velocity
        case createdAt = "created_at"
    }
}

struct UserSettings: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let preferredUnits: String
    let defaultPlateSize: String
    let notificationsEnabled: Bool
    let createdAt: Date
    let updatedAt: Date
    
    private enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case preferredUnits = "preferred_units"
        case defaultPlateSize = "default_plate_size"
        case notificationsEnabled = "notifications_enabled"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
