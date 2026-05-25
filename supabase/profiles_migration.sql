-- =============================================================
-- Souqna - profiles table migration
-- Run this SQL in your Supabase project → SQL Editor
-- =============================================================

CREATE TABLE IF NOT EXISTS public.profiles (
  id          UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  username    TEXT UNIQUE NOT NULL,
  account_type TEXT NOT NULL DEFAULT 'buyer'
              CHECK (account_type IN ('buyer', 'seller', 'admin')),
  avatar_url  TEXT,
  phone       TEXT,
  is_blocked  BOOLEAN NOT NULL DEFAULT FALSE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ===== Row Level Security =====
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Anyone can read any profile
CREATE POLICY "profiles_public_read"
  ON public.profiles FOR SELECT
  USING (true);

-- Authenticated users can insert their own profile
CREATE POLICY "profiles_own_insert"
  ON public.profiles FOR INSERT
  WITH CHECK (auth.uid() = id);

-- Users can update their own profile (not account_type or is_blocked)
CREATE POLICY "profiles_own_update"
  ON public.profiles FOR UPDATE
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

-- =============================================================
-- IMPORTANT: In Supabase Dashboard → Authentication → Email
-- Disable "Enable email confirmations" so users can log in
-- immediately after registration without email verification.
-- =============================================================
