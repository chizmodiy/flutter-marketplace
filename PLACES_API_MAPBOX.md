# Places API — Mapbox

Пошук міст використовує Mapbox Geocoding замість Google Places.

## Налаштування

1. Отримай токен: [mapbox.com/account/access-tokens](https://account.mapbox.com/access-tokens) → Create token → Public, scope Geocoding.

2. Додай секрет у Supabase:
   ```bash
   supabase secrets set MAPBOX_ACCESS_TOKEN=pk.eyJ1...
   ```

3. Задеплой функцію:
   ```bash
   supabase login
   supabase link --project-ref wcczieoznbopcafdatpk
   supabase functions deploy places-api
   ```

Або через Dashboard: Project Settings → Edge Functions → places-api → Redeploy (після push у репо).
