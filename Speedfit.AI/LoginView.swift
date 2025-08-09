//
//  LoginView.swift
//  Speedfit.AI
//
//  Created by Claude Code on 8/5/25.
//

import SwiftUI

struct LoginView: View {
    //creating a new instance of an ObservableObject
    //LoginView creates and owns this instance of AuthManager --> this object will be kept alive for the entire lifecycle of the LoginView
    //It also automatically subscribes the LoginView to all the @Published properties within that authManager instance
    @StateObject private var authManager = AuthManager()
    @State private var email = ""
    @State private var password = ""
    @State private var isShowingSignUp = false
    
    var body: some View {
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
                
                VStack(spacing: 30) {
                    Spacer()
                    
                    // App Logo/Title Section
                    VStack(spacing: 16) {
                        Text("⚡")
                            .font(.system(size: 60))
                        
                        Text("Speedfit.AI")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        Text("Track your barbell velocity")
                            .font(.headline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    
                    Spacer()
                    
                    // Login Form
                    VStack(spacing: 20) {
                        // Email Field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Email")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            TextField("Enter your email", text: $email)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                                .frame(height: 50)
                        }
                        
                        // Password Field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Password")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            SecureField("Enter your password", text: $password)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .frame(height: 50)
                        }
                        
                        // Error Message
                        if let errorMessage = authManager.errorMessage {
                            Text(errorMessage)
                                .foregroundColor(.red)
                                .font(.caption)
                                .multilineTextAlignment(.center)
                        }
                        
                        // Login Button
                        Button(action: {
                            Task {
                                await authManager.signIn(email: email, password: password)
                            }
                        }) {
                            HStack {
                                if authManager.isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                } else {
                                    Text("Sign In")
                                        .fontWeight(.semibold)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color.blue,
                                        Color.blue.opacity(0.8)
                                    ]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        //sign-in button is disabled if isLoading is true so that it can prevent the user to tap it mutiple times
                        .disabled(authManager.isLoading || email.isEmpty || password.isEmpty)
                        
                        // Sign Up Button
                        Button(action: {
                            isShowingSignUp = true
                        }) {
                            Text("Don't have an account? Sign Up")
                                .font(.subheadline)
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.horizontal, 40)
                    
                    Spacer()
                }
            }
        }
        .sheet(isPresented: $isShowingSignUp) {
            SignUpView()
        }
    }
}

#Preview {
    LoginView()
}
