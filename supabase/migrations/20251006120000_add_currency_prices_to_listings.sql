-- Add price_in_eur and price_in_usd columns to the listings table
ALTER TABLE public.listings
ADD COLUMN price_in_eur numeric(15, 2) NULL,
ADD COLUMN price_in_usd numeric(15, 2) NULL;
