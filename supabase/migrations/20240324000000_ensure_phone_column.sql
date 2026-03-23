-- Ensure phone column exists in profiles table
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_name = 'profiles' 
        AND column_name = 'phone'
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE public.profiles ADD COLUMN phone TEXT;
    END IF;
END $$;

-- Create index on phone column for better performance
CREATE INDEX IF NOT EXISTS idx_profiles_phone ON public.profiles(phone);

-- Update RLS policies to include phone column access
CREATE POLICY IF NOT EXISTS "Users can read phone numbers" ON public.profiles
FOR SELECT USING (true);

COMMENT ON COLUMN public.profiles.phone IS 'User phone number in international format'; 