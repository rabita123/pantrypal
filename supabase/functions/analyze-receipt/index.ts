import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { image, mediaType, stream } = await req.json()

    const anthropicKey = Deno.env.get('ANTHROPIC_API_KEY')
    if (!anthropicKey) throw new Error('ANTHROPIC_API_KEY not configured')

    const response = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: {
        'x-api-key': anthropicKey,
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
              source: {
                type: 'base64',
                media_type: mediaType ?? 'image/jpeg',
                data: image,
              },
            },
            {
              type: 'text',
              text: `This is a grocery receipt. Extract only the FOOD and DRINK items purchased.

Ignore completely: store name, address, phone numbers, BIN numbers, invoice numbers, barcodes/SKU codes, payment info, totals, and any non-food items (toothbrush, toothpaste, cleaning products, etc.).

For each food/drink item return a JSON object:
- "name": clean short name (e.g. "Cucumber", "Vermicelli", "Pineapple", "Biscuit", "Toast Biscuit")
- "category": one of: dairy, eggs, meat, vegetables, fruits, grains, frozen, beverages, snacks, condiments, other
- "quantity": numeric quantity (use the QTY column if visible, otherwise 1)
- "unit": unit of measure (kg, g, pcs, pack, item, etc.)
- "price": price paid (use AMOUNT column if visible, otherwise null)
- "estimatedExpiryDays": estimated days until expiry (e.g. cucumber=5, biscuit=90, pineapple=7)
- "confidence": "high" if the line is clearly legible and clearly food, "medium" if fairly sure, "low" if the text is smudged, cut off or you are guessing what the abbreviation means

Only list lines that are actually printed on the receipt. Never add items that are not there. List items in the order they appear.

Return ONLY a valid JSON array. No explanation, no markdown, just the array.`,
            },
          ],
        }],
      }),
    })

    if (!response.ok) {
      const err = await response.text()
      throw new Error(`Anthropic API error: ${err}`)
    }

    // Streaming: pass Anthropic's event stream straight through so items can
    // appear while the model is still writing. Older app versions omit `stream`
    // and get the single JSON reply below.
    if (stream === true && response.body) {
      return new Response(response.body, {
        headers: { ...corsHeaders, 'Content-Type': 'text/event-stream', 'Cache-Control': 'no-cache' },
      })
    }

    const data = await response.json()
    const result: string = data.content[0].text

    return new Response(JSON.stringify({ result }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  } catch (error) {
    return new Response(JSON.stringify({ error: (error as Error).message }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }
})
