import "jsr:@supabase/functions-js/edge-runtime.d.ts"
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

const REGION_BBOX: Record<string, string> = {
  'Вінницька область': '27.5,48.2,30.2,50.0',
  'Волинська область': '23.8,50.2,26.5,52.0',
  'Дніпропетровська область': '33.5,47.2,37.2,49.5',
  'Донецька область': '36.5,46.8,40.0,49.2',
  'Житомирська область': '27.2,49.5,30.2,51.2',
  'Закарпатська область': '22.0,47.8,24.6,49.2',
  'Запорізька область': '34.2,46.5,37.5,48.2',
  'Івано-Франківська область': '23.5,48.2,26.2,49.5',
  'Київська область': '29.2,49.8,32.2,51.5',
  'Кіровоградська область': '30.8,47.8,33.8,49.2',
  'Луганська область': '37.8,47.8,40.2,50.0',
  'Львівська область': '22.8,49.0,25.2,50.5',
  'Миколаївська область': '30.2,46.2,33.5,48.2',
  'Одеська область': '28.5,45.2,31.2,47.8',
  'Полтавська область': '32.8,48.8,36.2,50.5',
  'Рівненська область': '25.2,50.0,28.2,51.8',
  'Сумська область': '32.9,50.0,36.5,52.4',
  'Тернопільська область': '24.8,48.8,27.2,50.2',
  'Харківська область': '34.8,48.5,38.2,50.5',
  'Херсонська область': '31.5,45.8,35.2,47.5',
  'Хмельницька область': '26.2,48.5,28.5,50.2',
  'Черкаська область': '29.8,48.8,33.2,50.2',
  'Чернівецька область': '25.2,47.8,27.2,48.8',
  'Чернігівська область': '30.2,50.5,33.2,52.5',
  'м. Київ': '30.2,50.2,30.9,50.8',
  'м. Севастополь': '33.3,44.4,33.8,44.8',
  'АР Крим': '32.5,44.4,36.8,46.2',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  const token = Deno.env.get('MAPBOX_ACCESS_TOKEN')
  if (!token) {
    return new Response(JSON.stringify({ error: 'MAPBOX_ACCESS_TOKEN not configured' }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }

  try {
    const url = new URL(req.url)
    const input = url.searchParams.get('input')
    const region = url.searchParams.get('region')

    if (input) {
      const params = new URLSearchParams({
        access_token: token,
        country: 'UA',
        language: 'uk',
        types: 'place,locality,neighborhood',
        limit: '10',
      })
      const bbox = region ? REGION_BBOX[region] : null
      if (bbox) params.set('bbox', bbox)
      const searchUrl =
        'https://api.mapbox.com/geocoding/v5/mapbox.places/' +
        encodeURIComponent(input) +
        '.json?' +
        params.toString()
      const res = await fetch(searchUrl)
      const data = await res.json()

      if (!data.features) {
        return new Response(JSON.stringify({ status: 'ZERO_RESULTS', predictions: [] }), {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        })
      }

      const predictions = data.features.map((f: { place_name: string; id: string; center: number[] }) => {
        const [lng, lat] = f.center || [0, 0]
        return {
          description: f.place_name,
          place_id: f.id,
          lat,
          lng,
        }
      })

      return new Response(JSON.stringify({
        status: 'OK',
        predictions,
      }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    return new Response(JSON.stringify({ error: 'Missing input parameter' }), {
      status: 400,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  } catch (error) {
    return new Response(JSON.stringify({ error: String(error) }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }
})
