-- Add pin_code field to profiles table
ALTER TABLE public.profiles
ADD COLUMN pin_code TEXT;

-- Add constraint to ensure pin_code is exactly 4 digits
ALTER TABLE public.profiles
ADD CONSTRAINT check_pin_code_format
CHECK (pin_code ~ '^[0-9]{4}$');

-- Enable RLS for pin_code field
CREATE POLICY "Users can see their own pin_code" ON public.profiles
FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Users can update their own pin_code" ON public.profiles
FOR UPDATE USING (auth.uid() = id)
WITH CHECK (auth.uid() = id);

COMMENT ON COLUMN public.profiles.pin_code IS 'Four-digit PIN code for user authentication'; 