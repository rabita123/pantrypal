import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors })

  try {
    const { items } = await req.json()

    if (!items || items.length === 0) {
      return new Response(
        JSON.stringify({ error: 'No pantry items provided' }),
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

    // Format items for the prompt
    const itemList = items
      .map((i: { name: string; daysLeft: number; category: string }) =>
        `- ${i.name} (${i.category}, expires in ${i.daysLeft} day${i.daysLeft === 1 ? '' : 's'})`
      )
      .join('\n')

    const prompt = `You are a creative chef. A user has these food items in their fridge:

${itemList}

Generate ONE delicious recipe that uses as many of the expiring items (those with fewer days left) as possible.

Return ONLY valid JSON — no markdown, no explanation:
{
  "name": "Recipe name",
  "description": "One enticing sentence about the dish",
  "emoji": "🍝",
  "prepTime": "10 mins",
  "cookTime": "20 mins",
  "servings": 2,
  "usesExpiring": ["item1", "item2"],
  "ingredients": [
    {"item": "ingredient name", "amount": "200g"}
  ],
  "steps": [
    "Step 1: detailed instruction",
    "Step 2: detailed instruction"
  ],
  "tip": "One helpful chef tip"
}

Rules:
- Prioritise ingredients expiring soonest
- Write clear, detailed step-by-step instructions (6-10 steps)
- Be realistic — only use ingredients a home cook would have
- Make it actually delicious
`

    const res = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: {
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01',
        'content-type': 'application/json',
      },
      body: JSON.stringify({
        model: 'claude-haiku-4-5-20251001',
        max_tokens: 900,
        messages: [{ role: 'user', content: prompt }],
      }),
    })

    const data = await res.json()
    if (!res.ok) {
      return new Response(
        JSON.stringify({ error: data.error?.message ?? 'AI error' }),
        { status: 502, headers: { ...cors, 'Content-Type': 'application/json' } }
      )
    }

    return new Response(
      JSON.stringify({ result: data.content[0].text }),
      { headers: { ...cors, 'Content-Type': 'application/json' } }
    )
  } catch (e) {
    return new Response(
      JSON.stringify({ error: (e as Error).message }),
      { status: 500, headers: { ...cors, 'Content-Type': 'application/json' } }
    )
  }
})
