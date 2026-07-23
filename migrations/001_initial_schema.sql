-- RewardFlow Initial Schema Migration
-- Migration: 001_initial_schema

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- =============================================
-- PROFILES TABLE (extends Supabase auth.users)
-- =============================================
CREATE TABLE IF NOT EXISTS public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name TEXT NOT NULL DEFAULT '',
  email TEXT NOT NULL DEFAULT '',
  is_premium BOOLEAN NOT NULL DEFAULT FALSE,
  is_admin BOOLEAN NOT NULL DEFAULT FALSE,
  balance NUMERIC(10,2) NOT NULL DEFAULT 0.00,
  total_earned NUMERIC(10,2) NOT NULL DEFAULT 0.00,
  tasks_completed INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- =============================================
-- TASKS TABLE
-- =============================================
CREATE TABLE IF NOT EXISTS public.tasks (
  id SERIAL PRIMARY KEY,
  title TEXT NOT NULL,
  description TEXT NOT NULL,
  reward NUMERIC(10,2) NOT NULL,
  is_premium BOOLEAN NOT NULL DEFAULT FALSE,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- =============================================
-- TASK COMPLETIONS TABLE
-- =============================================
CREATE TABLE IF NOT EXISTS public.task_completions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  task_id INTEGER NOT NULL REFERENCES public.tasks(id) ON DELETE CASCADE,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
  proof_text TEXT,
  submitted_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  reviewed_at TIMESTAMPTZ,
  reviewed_by UUID REFERENCES public.profiles(id),
  UNIQUE(user_id, task_id)
);

-- =============================================
-- WITHDRAWALS TABLE
-- =============================================
CREATE TABLE IF NOT EXISTS public.withdrawals (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  amount NUMERIC(10,2) NOT NULL,
  method TEXT NOT NULL CHECK (method IN ('bank', 'paypal', 'crypto')),
  wallet_address TEXT,
  paypal_email TEXT,
  bank_details TEXT,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected', 'processing')),
  reference_id TEXT UNIQUE NOT NULL DEFAULT 'RW-' || UPPER(SUBSTRING(MD5(RANDOM()::TEXT), 1, 8)),
  notes TEXT,
  requested_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  processed_at TIMESTAMPTZ,
  processed_by UUID REFERENCES public.profiles(id)
);

-- =============================================
-- PREMIUM REQUESTS TABLE
-- =============================================
CREATE TABLE IF NOT EXISTS public.premium_requests (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
  payment_proof_url TEXT,
  amount NUMERIC(10,2) NOT NULL DEFAULT 15.00,
  submitted_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  reviewed_at TIMESTAMPTZ,
  reviewed_by UUID REFERENCES public.profiles(id),
  notes TEXT
);

-- =============================================
-- SEED DEFAULT TASKS
-- =============================================
INSERT INTO public.tasks (title, description, reward, is_premium) VALUES
  ('Test Shopping App', 'Download the app, browse products for 2 minutes, take a screenshot', 4.00, FALSE),
  ('Watch 2-Minute Ad', 'Watch the full advertisement, describe what you saw', 2.00, FALSE),
  ('Review Music Video', 'Watch the music video, leave a 3-sentence review', 3.00, FALSE),
  ('Complete Market Survey', 'Answer 10 questions about consumer preferences', 5.00, FALSE),
  ('Test Game App', 'Download the game, play for 5 minutes, submit a screenshot of your high score', 6.00, TRUE),
  ('Leave Google Review', 'Leave a 5-star review for a partner business', 4.00, FALSE),
  ('Watch Crypto Tutorial', 'Watch the 5-minute tutorial, summarize what you learned', 7.00, TRUE),
  ('Test Fitness App', 'Download the app, complete one workout, submit screenshot', 5.00, FALSE),
  ('Complete Feedback Form', 'Fill out a 5-question feedback form', 3.00, FALSE),
  ('Test Social Media App', 'Create a post, take a screenshot of the engagement', 8.00, TRUE),
  ('Rate YouTube Video', 'Watch and rate a video on a scale of 1 to 5', 2.00, FALSE),
  ('Test Food Delivery App', 'Browse the menu, add items to cart, take a screenshot', 5.00, FALSE),
  ('Review E-book', 'Read the first chapter, write a 5-sentence review', 4.00, TRUE),
  ('Complete App Tutorial', 'Follow the in-app tutorial, submit a completion screenshot', 3.00, FALSE),
  ('Test VPN App', 'Download and test the VPN app, report your experience', 10.00, TRUE)
ON CONFLICT DO NOTHING;

-- =============================================
-- ROW LEVEL SECURITY (RLS)
-- =============================================

-- Enable RLS on all tables
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.task_completions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.withdrawals ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.premium_requests ENABLE ROW LEVEL SECURITY;

-- PROFILES policies
CREATE POLICY "Users can view their own profile"
  ON public.profiles FOR SELECT
  USING (auth.uid() = id);

CREATE POLICY "Users can update their own profile"
  ON public.profiles FOR UPDATE
  USING (auth.uid() = id);

CREATE POLICY "Admins can view all profiles"
  ON public.profiles FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.is_admin = TRUE
    )
  );

CREATE POLICY "Admins can update all profiles"
  ON public.profiles FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.is_admin = TRUE
    )
  );

-- TASKS policies
CREATE POLICY "Anyone can view active tasks"
  ON public.tasks FOR SELECT
  USING (is_active = TRUE);

CREATE POLICY "Admins can manage tasks"
  ON public.tasks FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.is_admin = TRUE
    )
  );

-- TASK COMPLETIONS policies
CREATE POLICY "Users can view their own completions"
  ON public.task_completions FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own completions"
  ON public.task_completions FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Admins can view all completions"
  ON public.task_completions FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.is_admin = TRUE
    )
  );

CREATE POLICY "Admins can update completions"
  ON public.task_completions FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.is_admin = TRUE
    )
  );

-- WITHDRAWALS policies
CREATE POLICY "Users can view their own withdrawals"
  ON public.withdrawals FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own withdrawals"
  ON public.withdrawals FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Admins can view all withdrawals"
  ON public.withdrawals FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.is_admin = TRUE
    )
  );

CREATE POLICY "Admins can update withdrawals"
  ON public.withdrawals FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.is_admin = TRUE
    )
  );

-- PREMIUM REQUESTS policies
CREATE POLICY "Users can view their own premium requests"
  ON public.premium_requests FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own premium requests"
  ON public.premium_requests FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Admins can view all premium requests"
  ON public.premium_requests FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.is_admin = TRUE
    )
  );

CREATE POLICY "Admins can update premium requests"
  ON public.premium_requests FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.is_admin = TRUE
    )
  );

-- =============================================
-- FUNCTIONS & TRIGGERS
-- =============================================

-- Function to auto-create profile on user signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, full_name, email)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'full_name', ''),
    COALESCE(NEW.email, '')
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger: create profile on new user
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger: auto-update updated_at on profiles
DROP TRIGGER IF EXISTS update_profiles_updated_at ON public.profiles;
CREATE TRIGGER update_profiles_updated_at
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- =============================================
-- STORAGE BUCKET FOR PAYMENT PROOFS
-- =============================================
INSERT INTO storage.buckets (id, name, public)
VALUES ('payment-proofs', 'payment-proofs', FALSE)
ON CONFLICT (id) DO NOTHING;

-- Storage policies for payment proofs
CREATE POLICY "Users can upload their own payment proofs"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'payment-proofs' AND
    auth.uid()::text = (storage.foldername(name))[1]
  );

CREATE POLICY "Users can view their own payment proofs"
  ON storage.objects FOR SELECT
  USING (
    bucket_id = 'payment-proofs' AND
    auth.uid()::text = (storage.foldername(name))[1]
  );

CREATE POLICY "Admins can view all payment proofs"
  ON storage.objects FOR SELECT
  USING (
    bucket_id = 'payment-proofs' AND
    EXISTS (
      SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.is_admin = TRUE
    )
  );
