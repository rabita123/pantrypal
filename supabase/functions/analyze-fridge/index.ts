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
  "estimatedExpiryDays": 7,
  "confidence": "high|medium|low",
  "box": [x1, y1, x2, y2]
}

"box" is where the item is in the photo, as [left, top, right, bottom] on a 0-1000 scale
(0,0 = top-left corner, 1000,1000 = bottom-right). Tightly around that ONE item. Omit "box" if you
cannot place it.
"confidence": "high" = clearly visible and certain; "medium" = fairly sure; "low" = plausible but
partly hidden or ambiguous. Include a low-confidence item only when it is genuinely visible — the
app will ask the user to confirm it.

STRICT rules:
- List items in the order you find them, most obvious first
- Only include food and drink that is actually VISIBLE in the photo. Never add items that "would
  normally be" in a fridge
- Count identical items together into one entry with the right quantity (3 visible eggs -> quantity 3)
- If you cannot tell what something is, skip it or mark it "low" — never guess a specific product
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
    const { image, mediaType, stream } = await req.json()

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
        model: Deno.env.get('SCAN_MODEL') ?? 'claude-sonnet-4-6',
        max_tokens: 1400,
        stream: stream === true,
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

    // Streaming: hand Anthropic's event stream straight to the app so items can
    // appear while the model is still writing. Older app versions omit `stream`
    // and get the single JSON reply below.
    if (stream === true && anthropicRes.ok && anthropicRes.body) {
      return new Response(anthropicRes.body, {
        headers: { ...cors, 'Content-Type': 'text/event-stream', 'Cache-Control': 'no-cache' },
      })
    }

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
