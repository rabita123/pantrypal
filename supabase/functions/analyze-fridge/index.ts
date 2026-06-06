import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

const PROMPT = `
Analyze this photo of a refrigerator or food storage area.
Identify visible food and drink items.

Return ONLY a valid JSON array — no markdown, no explanation, nothing else.
Each element:
{
  "name": "specific item name (e.g. Whole Milk, Greek Yogurt, Cheddar Cheese, Lemon)",
  "category": "dairy|meat|vegetables|fruits|grains|frozen|beverages|snacks|condiments|other",
  "quantity": 1,
  "unit": "item|kg|g|L|ml|pack|bottle|can|bunch|loaf",
  "estimatedExpiryDays": 7
}

STRICT rules:
- ONLY include items you can clearly and confidently identify — if unsure, skip it
- Look carefully at color, shape, and size before naming an item (a lemon is yellow and round, an onion is brown/purple with papery skin — do not confuse them)
- Do not guess — if an item is partially hidden or unclear, skip it
- Do not include non-food items, containers, or appliances
- Use realistic shelf-life (milk ~7d, eggs ~21d, raw meat ~3d, condiments ~90d, hard cheese ~30d)
- Maximum 20 items
`

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: cors })
  }

  try {
    const { image, mediaType } = await req.json()

    if (!image || !mediaType) {
      return new Response(
        JSON.stringify({ error: 'Missing image or mediaType' }),
        { status: 400, headers: { ...cors, 'Content-Type': 'application/json' } }
      )
    }

    const apiKey = Deno.env.get('ANTHROPIC_API_KEY')
    if (!apiKey) {
      return new Response(
        JSON.stringify({ error: 'Server not configured' }),
        { status: 500, headers: { ...cors, 'Content-Type': 'application/json' } }
      )
    }

    const anthropicRes = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: {
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01',
        'content-type': 'application/json',
      },
      body: JSON.stringify({
        model: 'claude-sonnet-4-6',
        max_tokens: 1024,
        messages: [{
          role: 'user',
          content: [
            {
              type: 'image',
              source: { type: 'base64', media_type: mediaType, data: image },
            },
            { type: 'text', text: PROMPT },
          ],
        }],
      }),
    })

    const data = await anthropicRes.json()

    if (!anthropicRes.ok) {
      return new Response(
        JSON.stringify({ error: data.error?.message ?? `Anthropic error ${anthropicRes.status}` }),
        { status: 502, headers: { ...cors, 'Content-Type': 'application/json' } }
      )
    }

    const text: string = data.content[0].text
    return new Response(
      JSON.stringify({ result: text }),
      { headers: { ...cors, 'Content-Type': 'application/json' } }
    )
  } catch (e) {
    return new Response(
      JSON.stringify({ error: (e as Error).message }),
      { status: 500, headers: { ...cors, 'Content-Type': 'application/json' } }
    )
  }
})
