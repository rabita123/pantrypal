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
    const { picked, pantry, servings, mode, avoid } = await req.json()
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

    const isPlan = mode === 'plan'
    const avoidList = (Array.isArray(avoid) ? avoid : []).slice(0, 20).map(clean).filter(Boolean)

    const prompt = `You are a practical home cook helping someone ${isPlan ? 'plan dinners for the week' : 'use up food before it goes off'}.

Foods to build the meals around (use soonest first):
${pickedList}

Everything else they have: ${pantryList || 'unknown'}.
Always available: salt, pepper, oil, water, basic dried herbs and spices.

Suggest 3 different, ${isPlan ? 'everyday dinners' : 'practical meals'} for ${serves} people.
${avoidList.length ? `Do not suggest these, they are already planned: ${avoidList.join(', ')}.` : ''}

How to choose:
- Only combine foods that genuinely go together in a normal dish someone would happily eat.
${isPlan ? '- Every idea must be a filling main dinner (protein, vegetables and/or a staple like rice, pasta, bread or potatoes) — never a drink, smoothie, snack or dessert.\n- If a listed food only suits breakfast or dessert, leave it out.' : '- A sweet idea is fine only if the foods to use are sweet (fruit, yogurt); keep at least two ideas savoury.'}
- You do NOT have to use every food listed. Skip anything that does not fit a sensible meal.
- Never put sweets, snacks, cookies, crackers, chips or desserts into savoury dishes.
- Use 1 to 3 of the listed foods as the heart of each dish; it is fine for a dish to use just one.
- Make the 3 meals clearly different: different main ingredient and a different style (e.g. a stir-fry, a pasta, a soup, a curry, a salad, a bake).
- Do not repeat a staple: at most one rice dish, one pasta dish and one bread/sandwich dish among the 3.
- Prefer real, well-known dishes with plain names (e.g. "Spinach Omelette", "Chicken Fried Rice", "Tomato Pasta"). No odd mash-up names.
- Each meal may need at most 3 extra ingredients they do not have; fewer is better.
- Keep it quick and doable: under 45 minutes, common equipment, no fancy techniques.

Return ONLY a JSON array of 3 objects, no markdown:
[{
  "name": "Plain dish name",
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

Rules: ingredient names are plain food names, written the same way as in the lists above when it is the same food.
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
