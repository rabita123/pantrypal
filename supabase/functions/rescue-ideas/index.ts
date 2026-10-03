import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'

// Leftover Rescue: 3 practical meals from the food the user picked.
// Input:  { picked: [{name, daysLeft}], pantry: [{name}], servings }
// Output: { result: "<JSON array text>" }

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...cors, 'Content-Type': 'application/json' } })

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors })
  try {
    const { picked, pantry, servings } = await req.json()
    if (!Array.isArray(picked) || picked.length === 0) return json({ error: 'Pick at least one food' }, 400)
    if (picked.length > 15) return json({ error: 'Too many foods' }, 400)

    const apiKey = Deno.env.get('ANTHROPIC_API_KEY')
    if (!apiKey) return json({ error: 'Server not configured' }, 500)

    const clean = (s: unknown) => String(s ?? '').replace(/[^\p{L}\p{N} '\-]/gu, '').slice(0, 40)
    const pickedList = picked.map((p: { name: string; daysLeft?: number }) =>
      `- ${clean(p.name)}${typeof p.daysLeft === 'number' ? ` (use within ${Math.max(0, p.daysLeft)} days)` : ''}`).join('\n')
    const pantryList = (Array.isArray(pantry) ? pantry : []).slice(0, 40)
      .map((p: { name: string }) => clean(p.name)).filter(Boolean).join(', ')
    const serves = Math.min(Math.max(Number(servings) || 2, 1), 12)

    const prompt = `A home cook must use up these foods soon:
${pickedList}

Other food they have: ${pantryList || 'unknown'}.
Assume salt, pepper, oil and water are available.

Suggest 3 DIFFERENT practical meals for ${serves} people that use as many of the "must use" foods as possible.
Prefer food they already have. Each meal may need at most 2 extra ingredients they do not have.
Keep it everyday and quick (under 45 minutes where possible). No fancy techniques.

Return ONLY a JSON array of 3 objects, no markdown:
[{
  "name": "Short dish name",
  "emoji": "🍳",
  "description": "One plain sentence",
  "prepMinutes": 10,
  "cookMinutes": 20,
  "servings": ${serves},
  "ingredients": [{"name": "Spinach", "quantity": 200, "unit": "g"}],
  "steps": ["Short clear step", "..."],
  "kcalPerServing": 520,
  "proteinPerServing": 30
}]

Rules: ingredient names are plain food names that match the lists above when they are the same food.
4 to 7 steps. kcal and protein are honest per-serving estimates as whole numbers.`

    const res = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: { 'x-api-key': apiKey, 'anthropic-version': '2023-06-01', 'content-type': 'application/json' },
      body: JSON.stringify({
        model: Deno.env.get('RESCUE_MODEL') ?? 'claude-haiku-4-5-20251001',
        max_tokens: 2200,
        messages: [{ role: 'user', content: prompt }],
      }),
    })
    const data = await res.json()
    if (!res.ok) return json({ error: data.error?.message ?? 'AI error' }, 502)
    return json({ result: data.content?.[0]?.text ?? '' })
  } catch (e) {
    return json({ error: (e as Error).message }, 500)
  }
})
