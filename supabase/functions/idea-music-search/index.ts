import { errorResponseBody, logSafeError } from '../_shared/safe_error.ts';

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

const allowedLicenses = new Set(['cc0', 'pdm', 'by']);

// A conservative metadata filter. It is a word/phrase list, not a classifier.
const unsafeTerms = new Set([
  'fuck', 'fucking', 'fucked', 'fucker', 'motherfucker', 'shit', 'bullshit',
  'bitch', 'bastard', 'ass', 'arse', 'asshole', 'arsehole', 'dick', 'cock', 'pussy', 'cunt', 'whore',
  'slut', 'porn', 'porno', 'xxx', 'hentai', 'nude', 'nudes', 'naked', 'erotic',
  'sex', 'sexy', 'sexual', 'topless', 'boobs', 'tits', 'blowjob', 'handjob',
  'orgasm', 'penis', 'vagina', 'masturbation', 'masturbate', 'fetish', 'incest',
  'rape', 'rapist', 'molest', 'prostitute', 'hooker', 'stripper', 'wanker', 'twat',
  'chut', 'chutiya', 'chutiye', 'bhosdi', 'bhosdike', 'bhosadike', 'bhosada',
  'madarchod', 'madarchodd', 'maderchod', 'behenchod', 'bhenchod', 'gaand',
  'gand', 'gandu', 'lund', 'loda', 'lauda', 'lavda', 'randi', 'rand',
  'harami', 'haramzada', 'kamina', 'kaminey', 'suar', 'sala', 'saala', 'bhadwa', 'bsdk', 'bkl',
  'चूत', 'चूतिया', 'भोसड़ी', 'भोसड़ीके', 'भोसड़ीवाले', 'मादरचोद', 'मदरचोद',
  'बहनचोद', 'गांड', 'गांडू', 'लंड', 'लौड़ा', 'रंडी',
  'हरामी', 'हरामजादा', 'कमीना', 'साला', 'पोर्न', 'सेक्स', 'नग्न', 'अश्लील',
  'वेश्या', 'बलात्कार',
]);

const categoryQueries: Record<string, { query: string; category: string }> = {
  trending: { query: 'music', category: 'music' },
  popular: { query: 'featured music', category: 'music' },
  instrumental: { query: 'instrumental music', category: 'music' },
  indian: { query: 'Indian music', category: 'music' },
  indian_instrumental: { query: 'Indian instrumental', category: 'music' },
  indian_classical: { query: 'Indian classical music', category: 'music' },
  folk: { query: 'Indian folk music', category: 'music' },
  devotional: { query: 'Indian devotional music', category: 'music' },
  cinematic: { query: 'cinematic background music', category: 'music' },
  lofi: { query: 'lo-fi music', category: 'music' },
  ambient: { query: 'ambient music', category: 'music' },
  upbeat: { query: 'upbeat music', category: 'music' },
  emotional: { query: 'emotional music', category: 'music' },
  motivational: { query: 'motivational music', category: 'music' },
  electronic: { query: 'electronic music', category: 'music' },
  acoustic: { query: 'acoustic music', category: 'music' },
  sound_effects: { query: 'sound effect', category: 'sound_effect' },
  hindi: { query: 'Hindi Bollywood music', category: 'music' },
  tamil: { query: 'Tamil music', category: 'music' },
  telugu: { query: 'Telugu music', category: 'music' },
  punjabi: { query: 'Punjabi music', category: 'music' },
  carnatic: { query: 'Carnatic music', category: 'music' },
  hindustani: { query: 'Hindustani music', category: 'music' },
};

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') return json({ ok: true });
  if (request.method !== 'POST') return json({ error: 'Use POST to search music.' }, 405);
  if (!request.headers.get('Authorization')) return json({ error: 'Sign in to search music.' }, 401);

  try {
    const body = await request.json();
    if (body?.action === 'related') return await related(body?.track);
    if (body?.action && body.action !== 'search') return json({ error: 'Unsupported music request.' }, 400);

    const rawQuery = typeof body?.query === 'string' ? body.query.trim() : '';
    const category = typeof body?.category === 'string' ? body.category : 'popular';
    const requestedPage = Number(body?.page ?? 1);
    if (rawQuery.length > 120) return json({ error: 'Search text must be 120 characters or less.' }, 400);
    if (!Number.isInteger(requestedPage) || requestedPage < 1 || requestedPage > 20) {
      return json({ error: 'Music results page must be between 1 and 20.' }, 400);
    }
    const config = categoryQueries[category] ?? categoryQueries.popular;
    const query = rawQuery
      ? `${rawQuery} ${['popular', 'trending'].includes(category) ? '' : config.query}`.trim()
      : config.query;
    const openverse = await searchOpenverse(query, config.category, requestedPage);
    if (openverse.status !== 200) {
      return json({
        error: openverse.status === 429 ? 'Openverse is rate-limiting music search. Wait briefly and retry.' : 'No music provider could complete the search. Check provider status and try again.',
      }, 502);
    }
    return json({
      tracks: openverse.tracks,
      hasMore: openverse.hasMore,
      provider: 'Openverse',
      chart: 'search-ranked; no live trending chart',
    });
  } catch (error) {
    logSafeError('MUSIC_SEARCH_FAILED', error);
    return json({ error: 'Could not reach the music catalogue. Check the network and retry.' }, 502);
  }
});

async function related(track: Record<string, unknown>) {
  const id = typeof track?.id === 'string' ? track.id : '';
  if (!/^[0-9a-f-]{20,64}$/i.test(id)) return json({ error: 'This track has no valid Openverse ID for related music.' }, 400);
  let tracks: Record<string, unknown>[] = [];
  try {
    const response = await fetch(`https://api.openverse.org/v1/audio/${encodeURIComponent(id)}/related/`, {
      headers: { Accept: 'application/json' },
    });
    if (response.ok) {
      const payload = await response.json();
      tracks = safeTracks(payload?.results).filter((item) => item.id !== id);
    } else {
      console.warn('Openverse related route unavailable; using metadata search:', response.status);
    }
  } catch (error) {
    logSafeError('MUSIC_RELATED_LOOKUP_FAILED', error);
  }
  // Openverse related ranking can be sparse. Expand only from actual metadata supplied by this result.
  if (tracks.length < 6) {
    const terms = [track.title, track.creator, ...(Array.isArray(track.genres) ? track.genres : []), ...(Array.isArray(track.tags) ? track.tags : [])]
      .filter((v): v is string => typeof v === 'string').map((v) => v.trim()).filter(Boolean);
    const fallbackQuery = [...new Set(terms)].join(' ').slice(0, 180);
    if (fallbackQuery) {
      const category = track.category === 'sound_effect' ? 'sound_effect' : 'music';
      const openverse = await searchOpenverse(fallbackQuery, category, 1);
      tracks = [...tracks, ...openverse.tracks];
    }
  }
  const unique = dedupe(tracks.filter((item) => item.id !== id));
  return json({ tracks: unique.slice(0, 20), provider: 'Openverse', related: true });
}

async function searchOpenverse(query: string, category: string, page: number) {
  try {
    const response = await openverseSearch(query, category, page);
    if (!response.ok) return { status: response.status, count: 0, tracks: [], hasMore: false };
    const payload = await response.json();
    const tracks = safeTracks(payload?.results);
    return {
      status: response.status,
      count: tracks.length,
      tracks,
      hasMore: Number(payload?.page ?? page) < Number(payload?.page_count ?? page),
    };
  } catch (error) {
    logSafeError('MUSIC_PROVIDER_SEARCH_FAILED', error);
    return { status: 0, count: 0, tracks: [], hasMore: false };
  }
}

function openverseSearch(query: string, category: string, page: number) {
  const params = new URLSearchParams({
    q: query, category, license: 'cc0,pdm,by', license_type: 'commercial,modification',
    page_size: '20', page: String(page), filter_dead: 'true', mature: 'false',
  });
  return fetch(`https://api.openverse.org/v1/audio/?${params}`, { headers: { Accept: 'application/json' } });
}

function dedupe(items: Record<string, unknown>[]) {
  return [...new Map(items.map((item) => [String(item.id), item])).values()];
}

function safeTracks(results: unknown) {
  return (Array.isArray(results) ? results : [])
    .filter((item: Record<string, unknown>) =>
      typeof item.id === 'string' && typeof item.license === 'string' && allowedLicenses.has(item.license.toLowerCase()) &&
      typeof item.url === 'string' && item.url.startsWith('https://') &&
      typeof item.foreign_landing_url === 'string' && item.foreign_landing_url.startsWith('https://') &&
      typeof item.license_url === 'string' && item.license_url.startsWith('https://') &&
      !hasUnsafeMetadata(item))
    .map((item: Record<string, unknown>) => ({
      id: item.id, title: item.title, creator: item.creator, duration: item.duration, url: item.url,
      thumbnail: item.thumbnail, foreign_landing_url: item.foreign_landing_url,
      creator_url: item.creator_url, license: item.license, license_version: item.license_version,
      license_url: item.license_url, attribution: item.attribution, tags: item.tags,
      genres: item.genres, category: item.category, provider: 'Openverse',
    }));
}

function hasUnsafeMetadata(item: Record<string, unknown>) {
  const values = [item.title, item.creator, item.tags];
  const tokens = values.flatMap((value) => metadataStrings(value))
    .join(' ')
    .normalize('NFKD')
    .toLowerCase()
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/[^a-z0-9\u0900-\u097f]+/g, ' ')
    .trim()
    .split(/\s+/);
  return tokens.some((token) => unsafeTerms.has(token));
}

function metadataStrings(value: unknown): string[] {
  if (typeof value === 'string') return [value];
  if (Array.isArray(value)) return value.flatMap(metadataStrings);
  if (value && typeof value === 'object') {
    const record = value as Record<string, unknown>;
    return ['name', 'title', 'label', 'tag'].flatMap((key) => metadataStrings(record[key]));
  }
  return [];
}

function json(body: unknown, status = 200) {
  const safeBody = status >= 400 ? errorResponseBody(body, status) ?? body : body;
  return new Response(JSON.stringify(safeBody), {
    status,
    headers: { ...cors, 'Content-Type': 'application/json' },
  });
}
