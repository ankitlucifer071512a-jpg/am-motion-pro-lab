import { createClient } from 'npm:@supabase/supabase-js@2';
import { errorResponseBody, logSafeError } from '../_shared/safe_error.ts';

Deno.serve(async (request) => {
  const expected = Deno.env.get('STORY_CLEANUP_SECRET');
  if (request.method !== 'POST' || !expected || request.headers.get('x-cleanup-secret') !== expected) {
    return json({ error: 'Sign in to complete this request.' }, 401);
  }
  try {
    const client = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
      { auth: { persistSession: false, autoRefreshToken: false } },
    );
    let deleted = 0;
    for (;;) {
      const { data: rows, error } = await client.from('idea_stories')
        .select('id,storage_path')
        .lte('expires_at', new Date().toISOString())
        .limit(100);
      if (error) throw error;
      if (!rows?.length) break;
      const paths = rows.map((row) => row.storage_path as string);
      const { error: storageError } = await client.storage.from('idea-stories').remove(paths);
      if (storageError) throw storageError;
      const { error: deleteError } = await client.from('idea_stories')
        .delete().in('id', rows.map((row) => row.id));
      if (deleteError) throw deleteError;
      deleted += rows.length;
    }
    return Response.json({ deleted });
  } catch (error) {
    logSafeError('STORY_CLEANUP_FAILED', error);
    return json({ error: 'Story cleanup could not be completed.', code: 'STORY_CLEANUP_FAILED' }, 500);
  }
});

function json(body: unknown, status: number) {
  const safeBody = status >= 400 ? errorResponseBody(body, status) ?? body : body;
  return Response.json(safeBody, { status });
}
