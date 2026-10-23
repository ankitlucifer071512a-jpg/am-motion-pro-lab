import { createClient } from 'npm:@supabase/supabase-js@2';
import { errorResponseBody, logSafeError } from '../_shared/safe_error.ts';

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: cors });
  try {
    const authorization = request.headers.get('Authorization');
    if (!authorization) return json({ error: 'Sign in is required.' }, 401);
    const url = Deno.env.get('SUPABASE_URL');
    const anonKey = Deno.env.get('SUPABASE_ANON_KEY') ?? Deno.env.get('SUPABASE_PUBLISHABLE_KEY');
    const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
    if (!url || !anonKey || !serviceKey) {
      return json({ error: 'Contact matching server is not configured.' }, 503);
    }

    const userClient = createClient(url, anonKey, {
      global: { headers: { Authorization: authorization } },
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const { data: { user }, error: authError } = await userClient.auth.getUser();
    if (authError || !user) return json({ error: 'Session is invalid.' }, 401);

    const body = await request.json();
    const emails = Array.isArray(body.emails)
      ? body.emails.slice(0, 5000).map((v: unknown) => String(v).trim().toLowerCase())
          .filter((v: string) => /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(v))
      : [];
    const phones = Array.isArray(body.phones)
      ? body.phones.slice(0, 5000).map((v: unknown) => String(v).replace(/\D/g, ''))
          .filter((v: string) => v.length >= 8 && v.length <= 15)
      : [];
    if (emails.length + phones.length === 0) return json({ matches: [] });

    const admin = createClient(url, serviceKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const { data: allowed, error: rateError } = await admin.rpc('consume_idea_contact_match', {
      requester_id: user.id,
    });
    if (rateError) return json({ error: 'Contact matching setup is incomplete.' }, 503);
    if (allowed !== true) return json({ error: 'Contact sync limit reached. Please try again later.' }, 429);
    const { data, error } = await admin.rpc('match_idea_contacts', {
      requester_id: user.id,
      contact_emails: [...new Set(emails)],
      contact_phones: [...new Set(phones)],
    });
    if (error) return json({ error: 'Contact matching setup is incomplete.' }, 503);
    return json({ matches: data ?? [] });
  } catch (error) {
    logSafeError('CONTACT_MATCH_FAILED', error);
    return json({ error: 'Contact matching could not be completed.', code: 'CONTACT_MATCH_FAILED' }, 400);
  }
});

function json(body: unknown, status = 200) {
  const safeBody = status >= 400 ? errorResponseBody(body, status) ?? body : body;
  return new Response(JSON.stringify(safeBody), {
    status,
    headers: { ...cors, 'Content-Type': 'application/json' },
  });
}
