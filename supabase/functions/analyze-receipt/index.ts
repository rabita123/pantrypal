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
    const { image, mediaType } = await req.json()

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
        model: 'claude-sonnet-4-6',
        max_tokens: 1024,
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
