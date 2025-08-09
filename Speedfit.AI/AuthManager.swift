

import Foundation
import Supabase
import Combine


//main actor--> it declares that every property and method within this class must be accessed on the main application thread
@MainActor
//declaring a class named AuthManager and is a reference type, meaning multiple parts of app can share and interact with the same instance of AuthManager
//ObservableObject?? --> it allows SwiftUI views to observe and subscribe to this object and automatically update themselves whenever published properties change.
class AuthManager: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var userProfile: UserProfile?
    @Published var currentSession: Session?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    //creating private, constant instance of the Supabase client
    //can be only accessed from within the AuthManager class
    private let supabase = SupabaseConfig.client
    private var cancellables = Set<AnyCancellable>()
    
    //class initializer which is called exactly once when a new instance of AuthManager is created
    init() {
        setupAuthStateListener()   //listen for login/logout events
        checkCurrentSession()      //check if users are already logged in
    }
    
   
    private func setupAuthStateListener() {
        Task {
            //this continuously provides updates whenever the user's authentication state changes
            for await state in supabase.auth.authStateChanges {
                //when new even occurs, this calls another helper method
                await handleAuthStateChange(state.event, session: state.session)
            }
        }
    }
    
    //checking the existing login or not
    private func checkCurrentSession() {
        Task {
            do {
                //process of asking supabase is user logged in?
                let session = try await supabase.auth.session
                await handleAuthStateChange(.signedIn, session: session)
            } catch {
                print("No current session: \(error)")
                await handleAuthStateChange(.signedOut, session: nil)
            }
        }
    }
    
    private func handleAuthStateChange(_ event: AuthChangeEvent, session: Session?) async {
        switch event {
        case .signedIn:
            if let session = session {
                self.currentUser = session.user
                self.currentSession = session
                self.isAuthenticated = true
                await loadUserProfile()
            }
        case .signedOut:
            self.currentUser = nil
            self.userProfile = nil
            self.currentSession = nil
            self.isAuthenticated = false
        default:
            break
        }
    }
    //async method to fetch custom user data
    private func loadUserProfile() async {
        guard let userId = currentUser?.id else { return }
        
        do {
            let profile: UserProfile = try await supabase
                .from("profiles")
                .select()
                .eq("id", value: userId)
                .single()
                .execute()
                .value
            
            self.userProfile = profile
        } catch {
            print("Error loading user profile: \(error)")
        }
    }
    
    // MARK: - Authentication Methods
    
    func signUp(email: String, password: String, fullName: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let authResponse = try await supabase.auth.signUp(
                email: email,
                password: password,
                data: ["full_name": AnyJSON.string(fullName)]
            )
            
            if authResponse.user != nil {
                // User created successfully
                print("User created successfully")
            }
        } catch {
            errorMessage = error.localizedDescription
            print("Sign up error: \(error)")
        }
        
        isLoading = false
    }
    
    func signIn(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            try await supabase.auth.signIn(
                email: email,
                password: password
            )
        } catch {
            errorMessage = error.localizedDescription
            print("Sign in error: \(error)")
        }
        
        isLoading = false
    }
    
    func signOut() async {
        isLoading = true
        errorMessage = nil
        
        do {
            try await supabase.auth.signOut()
        } catch {
            errorMessage = error.localizedDescription
            print("Sign out error: \(error)")
        }
        
        isLoading = false
    }
    
    func resetPassword(email: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            try await supabase.auth.resetPasswordForEmail(email)
        } catch {
            errorMessage = error.localizedDescription
            print("Reset password error: \(error)")
        }
        
        isLoading = false
    }
}
