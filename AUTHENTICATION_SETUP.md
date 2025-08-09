 # Authentication & User Data Setup Guide

This guide will help you set up authentication and user data management for Speedfit.AI using Supabase.

## 1. Supabase Setup

### Create Supabase Project
1. Go to [supabase.com](https://supabase.com) and create a new project
2. Note down your project URL and anon key from the project settings
3. Go to the SQL Editor and run the contents of `supabase_schema.sql`

### Configure Environment Variables

#### Backend Configuration
1. Copy `.env.example` to `.env` in the `backend/` directory
2. Fill in your Supabase credentials:
```env
SUPABASE_URL=https://your-project-id.supabase.co
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key
SUPABASE_ANON_KEY=your-anon-key
JWT_SECRET=your-jwt-secret-from-supabase-dashboard
```

#### iOS Configuration
1. Open `Speedfit.AI/SupabaseConfig.swift`
2. Replace the placeholder values:
```swift
static let url = "https://your-project-id.supabase.co"
static let anonKey = "your-anon-key"
```

## 2. iOS Dependencies

### Add Supabase Swift SDK
1. In Xcode, go to File → Add Package Dependencies
2. Add: `https://github.com/supabase/supabase-swift`
3. Select the following products:
   - Supabase
   - Auth
   - PostgREST
   - Storage
   - Realtime

### Project Configuration
Make sure all the new Swift files are added to your Xcode project:
- `SupabaseConfig.swift`
- `AuthManager.swift` 
- `DataManager.swift`
- `LoginView.swift`
- `SignUpView.swift`
- `ProfileView.swift`
- `HistoryView.swift`

## 3. Backend Dependencies

Install the new Python dependencies:
```bash
cd backend
pip install -r requirements.txt
```

## 4. Database Schema

The `supabase_schema.sql` file creates:
- **profiles**: User profile data (linked to Supabase Auth)
- **workout_sessions**: User workout session data
- **rep_analysis**: Individual rep velocity data
- **user_settings**: User preferences and settings
- **Storage bucket**: For workout videos (optional)

## 5. Authentication Flow

### How it works:
1. **Sign Up**: Users create account with email/password in `SignUpView`
2. **Sign In**: Users log in through `LoginView` 
3. **Session Management**: `AuthManager` handles auth state
4. **Data Sync**: `DataManager` saves/loads user workout data
5. **Profile**: Users can manage settings in `ProfileView`
6. **History**: Users view past workouts in `HistoryView`

### App Flow:
- **Unauthenticated**: Shows `LoginView`
- **Authenticated**: Shows main app (`HomeView` with full features)

## 6. Features Added

### For Users:
- ✅ Email/password authentication
- ✅ User profiles with settings
- ✅ Workout history and progress tracking
- ✅ Individual rep analysis
- ✅ Data persistence across devices
- ✅ Offline-first design (backend optional)

### For Backend:
- ✅ Optional authentication (works with or without login)
- ✅ User session storage when authenticated
- ✅ Individual rep data tracking
- ✅ User-specific data access with RLS (Row Level Security)

## 7. Testing the Setup

### Test Authentication:
1. Launch the app
2. Tap "Sign Up" and create a test account
3. Verify email (check Supabase Auth dashboard)
4. Sign in with your credentials
5. Check that you reach the main HomeView

### Test Data Storage:
1. Import and process a workout video
2. Check that session is saved (message should say "saved to your history")
3. Go to History view and verify the session appears
4. Check Supabase dashboard to see data in the tables

### Test Profile:
1. Go to History → Profile (person icon)
2. Modify settings
3. Sign out and sign back in
4. Verify settings are preserved

## 8. Optional Enhancements

The authentication system is now ready for additional features:

### Immediate Next Steps:
- Add Apple Sign-In for iOS users
- Implement password reset functionality
- Add email verification requirements

### Advanced Features:
- Social sharing of workout results
- Workout program templates
- Coach/athlete relationships
- Exercise form analysis comparisons

## 9. Troubleshooting

### Common Issues:

**"No current session" error:**
- Check that Supabase URL and keys are correct
- Verify JWT secret matches your Supabase project

**Authentication not working:**
- Make sure all Supabase Swift packages are properly added
- Check that environment variables are loaded correctly

**Data not saving:**
- Verify database schema was applied correctly
- Check RLS policies are enabled
- Ensure user is properly authenticated

**Build errors:**
- Make sure all new Swift files are added to Xcode target
- Check that import statements are correct
- Verify Supabase dependencies are properly linked

## 10. Current Limitations

- JWT token refresh not implemented (sessions may expire)
- No offline data sync (Core Data integration pending)
- Video storage uses local files (not Supabase Storage yet)
- Basic error handling (could be more user-friendly)

These limitations can be addressed in future iterations as needed.
