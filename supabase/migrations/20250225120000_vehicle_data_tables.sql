CREATE TABLE IF NOT EXISTS public.makes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL UNIQUE
);

CREATE TABLE IF NOT EXISTS public.models (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  make_id uuid NOT NULL REFERENCES public.makes(id) ON DELETE CASCADE,
  UNIQUE(name, make_id)
);

CREATE TABLE IF NOT EXISTS public.styles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  style_name text NOT NULL,
  fuel_type text,
  model_id uuid NOT NULL REFERENCES public.models(id) ON DELETE CASCADE,
  UNIQUE(style_name, model_id)
);

CREATE TABLE IF NOT EXISTS public.model_years (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  year int NOT NULL,
  style_id uuid NOT NULL REFERENCES public.styles(id) ON DELETE CASCADE,
  UNIQUE(year, style_id)
);

CREATE INDEX IF NOT EXISTS idx_models_make_id ON public.models(make_id);
CREATE INDEX IF NOT EXISTS idx_styles_model_id ON public.styles(model_id);
CREATE INDEX IF NOT EXISTS idx_model_years_style_id ON public.model_years(style_id);
CREATE INDEX IF NOT EXISTS idx_makes_name ON public.makes(name);
CREATE INDEX IF NOT EXISTS idx_models_name ON public.models(name);

ALTER TABLE public.listings
  ADD COLUMN IF NOT EXISTS make_id uuid REFERENCES public.makes(id),
  ADD COLUMN IF NOT EXISTS model_id uuid REFERENCES public.models(id),
  ADD COLUMN IF NOT EXISTS style_id uuid REFERENCES public.styles(id),
  ADD COLUMN IF NOT EXISTS model_year_id uuid REFERENCES public.model_years(id);
