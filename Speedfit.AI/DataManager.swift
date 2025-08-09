
//

import Foundation
import Supabase
import Combine

@MainActor
class DataManager: ObservableObject {
    @Published var workoutSessions: [WorkoutSession] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let supabase = SupabaseConfig.client
    
    // MARK: - Workout Session Management
    
    func saveWorkoutSession(
        liftType: String,
        weight: Double?,
        plateSize: String,
        sessionMetrics: SessionMetrics,
        videoUrl: String? = nil,
        processedVideoUrl: String? = nil
    ) async -> UUID? {
        guard let userId = try? await supabase.auth.user().id else {
            errorMessage = "User not authenticated"
            return nil
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            // Create workout session using a struct
            struct WorkoutSessionInsert: Encodable {
                let user_id: String
                let lift_type: String
                let plate_size: String
                let total_reps: Int
                let calibration_used: Bool
                let pixels_per_meter: Double
                let weight: Double?
                let session_average: Double?
                let video_url: String?
                let processed_video_url: String?
            }
            
            let sessionData = WorkoutSessionInsert(
                user_id: userId.uuidString,
                lift_type: liftType,
                plate_size: plateSize,
                total_reps: sessionMetrics.total_reps,
                calibration_used: sessionMetrics.calibration_used,
                pixels_per_meter: sessionMetrics.pixels_per_meter,
                weight: weight,
                session_average: sessionMetrics.session_average,
                video_url: videoUrl,
                processed_video_url: processedVideoUrl
            )
            
            let insertedSession: WorkoutSession = try await supabase
                .from("workout_sessions")
                .insert(sessionData)
                .select()
                .single()
                .execute()
                .value
            
            // Save individual rep analysis
            struct RepAnalysisInsert: Encodable {
                let session_id: String
                let rep_number: Int
                let velocity: Double
            }
            
            for (index, velocity) in sessionMetrics.rep_speeds.enumerated() {
                let repData = RepAnalysisInsert(
                    session_id: insertedSession.id.uuidString,
                    rep_number: index + 1,
                    velocity: velocity
                )
                
                try await supabase
                    .from("rep_analysis")
                    .insert(repData)
                    .execute()
            }
            
            // Refresh workout sessions
            await loadWorkoutSessions()
            
            isLoading = false
            return insertedSession.id
            
        } catch {
            errorMessage = "Failed to save workout session: \(error.localizedDescription)"
            print("Save workout session error: \(error)")
            isLoading = false
            return nil
        }
    }
    
    func loadWorkoutSessions() async {
        guard let userId = try? await supabase.auth.user().id else {
            errorMessage = "User not authenticated"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let sessions: [WorkoutSession] = try await supabase
                .from("workout_sessions")
                .select()
                .eq("user_id", value: userId)
                .order("session_date", ascending: false)
                .execute()
                .value
            
            self.workoutSessions = sessions
            
        } catch {
            errorMessage = "Failed to load workout sessions: \(error.localizedDescription)"
            print("Load workout sessions error: \(error)")
        }
        
        isLoading = false
    }
    
    func getRepAnalysis(for sessionId: UUID) async -> [RepAnalysis] {
        do {
            let reps: [RepAnalysis] = try await supabase
                .from("rep_analysis")
                .select()
                .eq("session_id", value: sessionId)
                .order("rep_number", ascending: true)
                .execute()
                .value
            
            return reps
            
        } catch {
            print("Error loading rep analysis: \(error)")
            return []
        }
    }
    
    func deleteWorkoutSession(_ sessionId: UUID) async {
        isLoading = true
        errorMessage = nil
        
        do {
            try await supabase
                .from("workout_sessions")
                .delete()
                .eq("id", value: sessionId)
                .execute()
            
            // Refresh workout sessions
            await loadWorkoutSessions()
            
        } catch {
            errorMessage = "Failed to delete workout session: \(error.localizedDescription)"
            print("Delete workout session error: \(error)")
        }
        
        isLoading = false
    }
    
    // MARK: - User Settings Management
    
    func loadUserSettings() async -> UserSettings? {
        guard let userId = try? await supabase.auth.user().id else { return nil }
        
        do {
            let settings: UserSettings = try await supabase
                .from("user_settings")
                .select()
                .eq("user_id", value: userId)
                .single()
                .execute()
                .value
            
            return settings
            
        } catch {
            print("Error loading user settings: \(error)")
            return nil
        }
    }
    
    func updateUserSettings(_ settings: [String: Any]) async -> Bool {
        guard let userId = try? await supabase.auth.user().id else { return false }
        
        struct UserSettingsUpdate: Encodable {
            let preferred_units: String?
            let default_plate_size: String?
            let notifications_enabled: Bool?
        }
        
        do {
            let updateData = UserSettingsUpdate(
                preferred_units: settings["preferred_units"] as? String,
                default_plate_size: settings["default_plate_size"] as? String,
                notifications_enabled: settings["notifications_enabled"] as? Bool
            )
            
            try await supabase
                .from("user_settings")
                .update(updateData)
                .eq("user_id", value: userId)
                .execute()
            
            return true
            
        } catch {
            print("Error updating user settings: \(error)")
            return false
        }
    }
}
