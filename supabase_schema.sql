-- Supabase Database Schema for Speedfit.AI
-- Run these commands in your Supabase SQL editor

-- Enable necessary extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Users table (handled by Supabase Auth automatically)
-- But we'll create a profiles table for additional user data
CREATE TABLE public.profiles (
    id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
    email TEXT,
    full_name TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Workout sessions table
CREATE TABLE public.workout_sessions (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    session_date TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    lift_type TEXT NOT NULL, -- 'Squat', 'Bench Press', 'Deadlift'
    weight DECIMAL(5,2), -- Weight in kg/lbs
    plate_size TEXT NOT NULL, -- '45cm (Olympic)', '35cm (Standard)', '25cm (Small)'
    session_average DECIMAL(5,3), -- Average velocity for session
    total_reps INTEGER DEFAULT 0,
    calibration_used BOOLEAN DEFAULT FALSE,
    pixels_per_meter DECIMAL(10,4),
    video_url TEXT, -- Storage URL for original video
    processed_video_url TEXT, -- Storage URL for processed video
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Individual rep analysis table
CREATE TABLE public.rep_analysis (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    session_id UUID REFERENCES public.workout_sessions(id) ON DELETE CASCADE NOT NULL,
    rep_number INTEGER NOT NULL,
    velocity DECIMAL(5,3) NOT NULL, -- Rep velocity in m/s
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- User settings table
CREATE TABLE public.user_settings (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL UNIQUE,
    preferred_units TEXT DEFAULT 'metric', -- 'metric' or 'imperial'
    default_plate_size TEXT DEFAULT '45cm (Olympic)',
    notifications_enabled BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Row Level Security (RLS) Policies
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.workout_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rep_analysis ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_settings ENABLE ROW LEVEL SECURITY;

-- Profiles policies
CREATE POLICY "Users can view own profile" ON public.profiles
    FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Users can update own profile" ON public.profiles
    FOR UPDATE USING (auth.uid() = id);

CREATE POLICY "Users can insert own profile" ON public.profiles
    FOR INSERT WITH CHECK (auth.uid() = id);

-- Workout sessions policies
CREATE POLICY "Users can view own sessions" ON public.workout_sessions
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own sessions" ON public.workout_sessions
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own sessions" ON public.workout_sessions
    FOR UPDATE USING (auth.uid() = user_id);

-- Rep analysis policies
CREATE POLICY "Users can view own rep analysis" ON public.rep_analysis
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.workout_sessions 
            WHERE id = rep_analysis.session_id AND user_id = auth.uid()
        )
    );

CREATE POLICY "Users can insert own rep analysis" ON public.rep_analysis
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.workout_sessions 
            WHERE id = rep_analysis.session_id AND user_id = auth.uid()
        )
    );

-- User settings policies
CREATE POLICY "Users can view own settings" ON public.user_settings
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can update own settings" ON public.user_settings
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own settings" ON public.user_settings
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Functions to automatically create profile and settings on user signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.profiles (id, email, full_name)
    VALUES (NEW.id, NEW.email, NEW.raw_user_meta_data->>'full_name');
    
    INSERT INTO public.user_settings (user_id)
    VALUES (NEW.id);
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to call the function on new user signup
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Storage bucket for workout videos
INSERT INTO storage.buckets (id, name, public) VALUES ('workout-videos', 'workout-videos', false);

-- Storage policies for workout videos
CREATE POLICY "Users can upload their own videos" ON storage.objects
    FOR INSERT WITH CHECK (bucket_id = 'workout-videos' AND auth.uid()::text = (storage.foldername(name))[1]);

CREATE POLICY "Users can view their own videos" ON storage.objects
    FOR SELECT USING (bucket_id = 'workout-videos' AND auth.uid()::text = (storage.foldername(name))[1]);

CREATE POLICY "Users can delete their own videos" ON storage.objects
    FOR DELETE USING (bucket_id = 'workout-videos' AND auth.uid()::text = (storage.foldername(name))[1]);