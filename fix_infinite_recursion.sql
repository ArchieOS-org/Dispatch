-- =============================================
-- FIX: Infinite Recursion in 'users' RLS Policy
-- Run this in Supabase Dashboard > SQL Editor
-- =============================================

-- 1. Create a "Security Definer" function to check admin status.
-- This function runs with "postgres" privileges, bypassing RLS checks.
-- This breaks the infinite loop when the 'users' table queries itself.
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM users
    WHERE id = auth.uid()
    AND user_type = 'admin'
  );
$$;

-- 2. Clean up existing policies (Drop potential recursive ones)
-- We try to guess common names. If you named it something else, you might need to drop it manually.
DROP POLICY IF EXISTS "Admins can do everything" ON users;
DROP POLICY IF EXISTS "Admins can see all users" ON users;
DROP POLICY IF EXISTS "admin_all" ON users;
DROP POLICY IF EXISTS "Users can read all users" ON users;
DROP POLICY IF EXISTS "Users can update own profile" ON users;

-- 3. Re-apply Safe Policies

-- READ: All authenticated users can read all profiles (required for collaboration)
CREATE POLICY "Users can read all users" ON users
    FOR SELECT TO authenticated
    USING (true);

-- UPDATE: Users can only update their own profile
CREATE POLICY "Users can update own profile" ON users
    FOR UPDATE TO authenticated
    USING (id = auth.uid());

-- ADMIN: Admins can do everything (using the non-recursive function)
CREATE POLICY "Admins can do everything" ON users
    FOR ALL TO authenticated
    USING ( is_admin() );

-- =============================================
-- VERIFICATION
-- =============================================
-- After running, try syncing the app again.
