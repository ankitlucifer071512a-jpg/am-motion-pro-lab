import { createClient } from 'npm:@supabase/supabase-js@2';
import { errorResponseBody, logSafeError } from '../_shared/safe_error.ts';

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: cors });
  if (request.method !== 'POST') return json({ error: 'Use POST to send a chat message.' }, 405);

  try {
    const authorization = request.headers.get('Authorization');
    if (!authorization) return json({ error: 'Sign in to use AM Creative AI.' }, 401);

    const supabaseUrl = Deno.env.get('SUPABASE_URL');
    const publishableKey = Deno.env.get('SUPABASE_ANON_KEY') ?? Deno.env.get('SUPABASE_PUBLISHABLE_KEY');
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
    const geminiKey = Deno.env.get('GEMINI_API_KEY');
    if (!supabaseUrl || !publishableKey || !serviceRoleKey) {
      return json({ error: 'The AI server is not fully configured yet.' }, 503);
    }
    if (!geminiKey) return json({ error: 'The AI provider is not configured yet.' }, 503);

    const userClient = createClient(supabaseUrl, publishableKey, {
      global: { headers: { Authorization: authorization } },
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const { data: { user }, error: authError } = await userClient.auth.getUser();
    if (authError || !user) return json({ error: 'Your session expired. Sign in again.' }, 401);

    let body: unknown;
    try {
      body = await request.json();
    } catch {
      return json({ error: 'The chat request was not valid JSON.' }, 400);
    }
    const rawMessages = (body as { messages?: unknown } | null)?.messages;
    if (!Array.isArray(rawMessages) || rawMessages.length < 1 || rawMessages.length > 11) {
      return json({ error: 'Send a message with at most 10 earlier chat messages.' }, 400);
    }

    const messages: { role: 'user' | 'model'; parts: { text: string }[] }[] = [];
    for (const item of rawMessages) {
      if (!item || typeof item !== 'object') return json({ error: 'One chat message was invalid.' }, 400);
      const { role, text } = item as { role?: unknown; text?: unknown };
      if ((role !== 'user' && role !== 'model') || typeof text !== 'string') {
        return json({ error: 'One chat message was invalid.' }, 400);
      }
      const cleanText = text.trim();
      if (!cleanText || cleanText.length > 1200) {
        return json({ error: 'Each message must contain 1 to 1,200 characters.' }, 400);
      }
      messages.push({ role, parts: [{ text: cleanText }] });
    }
    if (messages[messages.length - 1]?.role !== 'user') {
      return json({ error: 'The last chat message must be from you.' }, 400);
    }
    const totalChars = messages.reduce((sum, item) => sum + item.parts[0].text.length, 0);
    if (totalChars > 8000) return json({ error: 'This conversation context is too long. Start a new chat.' }, 400);

    const admin = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const { data: allowed, error: rateError } = await admin.rpc('consume_creative_ai_request', {
      requester_id: user.id,
    });
    if (rateError) return json({ error: 'AI request protection is not set up yet. Apply the latest database migration.' }, 503);
    if (allowed !== true) return json({ error: 'You have reached the limit of 20 AI messages per hour. Please try again later.' }, 429);

    const configuredModel = Deno.env.get('GEMINI_MODEL') ?? 'gemini-3.1-flash-lite';
    const model = /^[a-zA-Z0-9._-]+$/.test(configuredModel) ? configuredModel : 'gemini-3.1-flash-lite';
    const upstream = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'x-goog-api-key': geminiKey },
      body: JSON.stringify({
        systemInstruction: {
          parts: [{ text: 'You are AM Creative AI, a friendly and practical creative learning assistant for AM Motion Lab. Help with video editing, graphic design, motion graphics, 2D/3D animation, creative project planning, and the app’s learning content. Answer clearly and warmly. Match the user’s language, including Hindi or Hinglish when they use it. Do not claim to have accessed private account data or performed actions in the app.' }],
        },
        contents: messages,
        generationConfig: { maxOutputTokens: 700, temperature: 0.7 },
      }),
    });

    if (!upstream.ok) {
      if (upstream.status === 429) return json({ error: 'The AI provider is busy or its quota is temporarily full. Please wait and retry.' }, 429);
      if (upstream.status === 401 || upstream.status === 403) return json({ error: 'The AI provider key is invalid or does not have API access.' }, 503);
      return json({ error: 'The AI provider could not answer right now. Please try again shortly.' }, 502);
    }
    const payload = await upstream.json();
    const reply = payload?.candidates?.[0]?.content?.parts
      ?.map((part: { text?: unknown }) => typeof part.text === 'string' ? part.text : '')
      .join('')
      .trim();
    if (!reply) return json({ error: 'The AI provider returned no answer. Please try again.' }, 502);
    return json({ reply });
  } catch (error) {
    logSafeError('AI_REQUEST_FAILED', error);
    return json({ error: 'The AI service could not complete the request.', code: 'AI_REQUEST_FAILED' }, 502);
  }
});

function json(body: unknown, status = 200) {
  const safeBody = status >= 400 ? errorResponseBody(body, status) ?? body : body;
  return new Response(JSON.stringify(safeBody), {
    status,
    headers: { ...cors, 'Content-Type': 'application/json' },
  });
}
