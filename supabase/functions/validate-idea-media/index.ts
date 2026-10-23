import { createClient } from 'npm:@supabase/supabase-js@2';
import { errorResponseBody, logSafeError } from '../_shared/safe_error.ts';

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: cors });
  try {
    const authorization = request.headers.get('Authorization');
    if (!authorization) return json({ error: 'Sign in is required.' }, 401);
    const body = await request.json();
    const { bucket, path, action } = body;
    console.log('[UPLOAD] validator.start');
    const url = Deno.env.get('SUPABASE_URL');
    const anonKey = Deno.env.get('SUPABASE_ANON_KEY') ?? Deno.env.get('SUPABASE_PUBLISHABLE_KEY');
    const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
    if (!url || !anonKey || !serviceKey) {
      return json({ error: 'Server validator secrets are not configured.' }, 503);
    }

    const userClient = createClient(url, anonKey, {
      global: { headers: { Authorization: authorization } },
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const { data: { user }, error: authError } = await userClient.auth.getUser();
    if (authError || !user) {
      if (authError) logSafeError('MEDIA_AUTH_FAILED', authError);
      return json({ error: 'Session is invalid.' }, 401);
    }

    const admin = createClient(url, serviceKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
    if (action === 'thumbnail') {
      if (bucket !== 'idea-media' || typeof path !== 'string' || typeof body.post_id !== 'string' ||
          !new RegExp(`^${user.id}/${body.post_id}/[^/]+\\.(jpg|jpeg|png|webp)$`, 'i').test(path)) {
        return json({ error: 'Video cover must be an image in your own post folder.' }, 400);
      }
      const { data: post, error: postError } = await admin.from('idea_posts')
        .select('id,creator_id').eq('id', body.post_id).eq('creator_id', user.id).maybeSingle();
      if (postError || !post) return json({ error: 'Only a post creator can validate its video cover.' }, 403);
      const { data: image, error: imageError } = await userClient.storage.from('idea-media').download(path);
      if (imageError || !image) return json({ error: 'Uploaded cover could not be read.' }, 400);
      const imageBytes = new Uint8Array(await image.arrayBuffer());
      const imageExt = path.split('.').pop()?.toLowerCase();
      const imageType = isJpeg(imageBytes) && ['jpg', 'jpeg'].includes(imageExt ?? '') ? 'image/jpeg'
        : isPng(imageBytes) && imageExt === 'png' ? 'image/png'
        : isWebp(imageBytes) && imageExt === 'webp' ? 'image/webp' : null;
      if (!imageType) return json({ error: 'Cover contents must match JPG, PNG, or WebP.' }, 415);
      if (imageBytes.length === 0 || imageBytes.length > 2 * 1024 * 1024) {
        return json({ error: 'Video covers must be no larger than 2 MiB.' }, 413);
      }
      return json({ mimeType: imageType, size: imageBytes.length }, 200);
    }
    if (action === 'preflight-thumbnail') {
      if (bucket !== 'idea-media' || typeof path !== 'string' ||
          !new RegExp(`^${user.id}/[0-9a-fA-F-]{36}/[^/]+\\.(jpg|jpeg|png|webp)$`, 'i').test(path)) {
        return json({ error: 'Video cover must be an image in your own media folder.' }, 400);
      }
      const { data: image, error: imageError } = await userClient.storage.from(bucket).download(path);
      if (imageError || !image) return json({ error: 'Uploaded cover could not be read.' }, 400);
      const imageBytes = new Uint8Array(await image.arrayBuffer());
      const imageExt = path.split('.').pop()?.toLowerCase();
      const imageType = isJpeg(imageBytes) && ['jpg', 'jpeg'].includes(imageExt ?? '') ? 'image/jpeg'
        : isPng(imageBytes) && imageExt === 'png' ? 'image/png'
        : isWebp(imageBytes) && imageExt === 'webp' ? 'image/webp' : null;
      if (!imageType) return json({ error: 'Cover contents must match JPG, PNG, or WebP.' }, 415);
      if (imageBytes.length === 0 || imageBytes.length > 2 * 1024 * 1024) {
        return json({ error: 'Video covers must be no larger than 2 MiB.' }, 413);
      }
      return json({ mimeType: imageType, size: imageBytes.length }, 200);
    }
    if (action === 'health') {
      const [profile, categories, posts, media, tags, stories, mediaBucket, storyBucket] = await Promise.all([
        admin.from('idea_profiles').select('id').eq('id', user.id).maybeSingle(),
        admin.from('idea_categories').select('id').limit(1),
        admin.from('idea_posts').select('id').limit(1),
        admin.from('idea_post_media').select('id,thumbnail_url,duration_seconds').limit(1),
        admin.from('idea_post_tags').select('post_id').limit(1),
        admin.from('idea_stories').select('id').limit(1),
        admin.storage.getBucket('idea-media'),
        admin.storage.getBucket('idea-stories'),
      ]);
      const missing = [
        profile.error && 'creator profiles schema',
        !profile.data && 'creator profile row (apply the profile trigger/backfill from the migration)',
        categories.error && 'Idea Lab migration/categories',
        posts.error && 'Idea Lab posts schema',
        media.error && 'Idea Lab post media schema',
        tags.error && 'Idea Lab post tags schema',
        stories.error && 'Idea Lab stories schema',
        mediaBucket.error && 'idea-media storage bucket',
        storyBucket.error && 'idea-stories storage bucket',
      ].filter(Boolean);
      if (missing.length) {
        return json({ ready: false, error: `Missing setup: ${missing.join(', ')}.` }, 503);
      }
      return json({ ready: true }, 200);
    }

    if (!['idea-media', 'idea-stories'].includes(bucket) || typeof path !== 'string') {
      return json({ error: 'Invalid media reference.' }, 400);
    }
    const segments = path.split('/');
    if (segments.length !== 3 || segments[0] !== user.id) {
      return json({ error: 'You can validate only your own uploaded media.' }, 403);
    }

    const ext = path.split('.').pop()?.toLowerCase();
    console.log('[UPLOAD] validator.file.detected');
    let mimeType: string;
    let width: number | null = null;
    let height: number | null = null;
    let durationSeconds: number | null = null;

    if (ext === 'mp4') {
      const { data: signed, error: signedError } = await admin.storage.from(bucket).createSignedUrl(path, 120);
      if (signedError || !signed?.signedUrl) {
        if (signedError) logSafeError('MEDIA_SIGNED_URL_FAILED', signedError);
        return json({ error: 'Uploaded video could not be inspected.' }, 400);
      }
      const signedUrl = new URL(signed.signedUrl, url).toString();
      const header = await readByteRange(signedUrl, 0, 11);
      if (!header || !isMp4(header)) {
        console.log('[UPLOAD] validator.video.header_rejected', { rangeRead: header?.length ?? 0, isMp4: header ? isMp4(header) : false });
        return json({ error: 'File contents do not match an MP4 video.' }, 415);
      }
      const moov = await readMp4MovieBox(signedUrl);
      if (!moov) {
        console.log('[UPLOAD] validator.video.moov_unreadable', { reason: 'movie_metadata_atom_unavailable_or_range_request_failed' });
        return json({ error: 'MP4 metadata could not be read. Re-export the video as a standard MP4 and try again.' }, 422);
      }
      mimeType = 'video/mp4';
      ({ width, height } = readMp4Dimensions(moov));
      durationSeconds = readMp4DurationSeconds(moov);
      if (!width || !height || !isAllowedVideoRatio(width, height)) {
        console.log('[UPLOAD] validator.video.metadata_rejected', { width, height, durationSeconds, reason: 'unsupported_aspect_ratio_or_missing_dimensions' });
        return json({ error: `Video dimensions ${width ?? '?'}×${height ?? '?'} are unsupported. Use a portrait, square, or landscape video with an aspect ratio from 1:2 through 2.4:1.` }, 422);
      }
      if (durationSeconds === null || durationSeconds <= 0) {
        console.log('[UPLOAD] validator.video.duration_rejected', { width, height, durationSeconds });
        return json({ error: 'The video duration could not be read from this MP4.' }, 422);
      }
      const requestedDuration = body.max_duration_seconds;
      const allowedDuration = requestedDuration === 60 || requestedDuration === 120
        ? requestedDuration
        : 120;
      if (durationSeconds > allowedDuration || durationSeconds > 120) {
        console.log('[UPLOAD] validator.video.duration_rejected', { width, height, durationSeconds, allowedDuration });
        return json({
          error: `This video is ${durationSeconds} seconds. The selected format allows up to ${allowedDuration === 60 ? '1 minute' : '2 minutes'}.`,
        }, 422);
      }
      console.log('[UPLOAD] validator.video.metadata_ok', { width, height, durationSeconds, ratio: width / height });
    } else {
      const { data: blob, error: downloadError } = await userClient.storage.from(bucket).download(path);
      if (downloadError || !blob) return json({ error: 'Uploaded object could not be read.' }, 400);
      const bytes = new Uint8Array(await blob.arrayBuffer());
      if (bytes.length === 0 || bytes.length > 20000000) {
        return json({ error: `This image is ${(bytes.length / 1000000).toFixed(1)} MB. The maximum is 20 MB. Please resize or compress it.` }, 413);
      }
      if (isJpeg(bytes) && ['jpg', 'jpeg'].includes(ext ?? '')) mimeType = 'image/jpeg';
      else if (isPng(bytes) && ext === 'png') mimeType = 'image/png';
      else if (isWebp(bytes) && ext === 'webp') mimeType = 'image/webp';
      else return json({ error: 'File contents do not match a supported JPG, PNG, WebP, or MP4 type.' }, 415);
    }

    if (action === 'preflight') {
      return json({ mimeType, width, height, durationSeconds }, 200);
    }

    const { data: media } = await admin
      .from('idea_post_media')
      .select('id,post_id')
      .eq('storage_path', path)
      .maybeSingle();
    if (bucket === 'idea-media') {
      if (!media) return json({ error: 'Post media metadata must be staged before validation.' }, 409);
      const { data: post } = await admin.from('idea_posts')
        .select('creator_id,published_at').eq('id', media.post_id).single();
      if (!post || post.creator_id !== user.id || post.published_at !== null) {
        return json({ error: 'Only your unpublished draft can be validated.' }, 403);
      }
      const { error } = await admin.from('idea_post_media')
        .update({ mime_type: mimeType, width, height, video_validated: true, duration_seconds: durationSeconds })
        .eq('id', media.id);
      if (error) throw error;
    } else {
      const { data: story, error: storyError } = await admin.from('idea_stories')
        .select('id,creator_id,media_validated').eq('storage_path', path).maybeSingle();
      if (storyError || !story || story.creator_id !== user.id || story.media_validated) {
        return json({ error: 'Only your unvalidated story can be validated.' }, 403);
      }
      const { error } = await admin.from('idea_stories')
        .update({ mime_type: mimeType, width, height, media_validated: true }).eq('id', story.id);
      if (error) throw error;
    }
    return json({ mimeType, width, height, durationSeconds }, 200);
  } catch (error) {
    logSafeError('MEDIA_VALIDATION_FAILED', error);
    return json({ error: 'The uploaded media could not be verified.', code: 'MEDIA_VALIDATION_FAILED' }, 400);
  }
});

function json(body: unknown, status: number) {
  const safeBody = status >= 400 ? errorResponseBody(body, status) ?? body : body;
  return new Response(JSON.stringify(safeBody), {
    status,
    headers: { ...cors, 'Content-Type': 'application/json' },
  });
}

function isJpeg(b: Uint8Array) { return b[0] === 0xff && b[1] === 0xd8 && b[2] === 0xff; }
function isPng(b: Uint8Array) {
  return b.length >= 8 && [137,80,78,71,13,10,26,10].every((v, i) => b[i] === v);
}
function isWebp(b: Uint8Array) {
  return b.length >= 12 && ascii(b, 0, 4) === 'RIFF' && ascii(b, 8, 4) === 'WEBP';
}
function isMp4(b: Uint8Array) { return b.length >= 12 && ascii(b, 4, 4) === 'ftyp'; }
function ascii(b: Uint8Array, start: number, length: number) {
  return String.fromCharCode(...b.slice(start, start + length));
}

async function readByteRange(url: string, start: number, end: number): Promise<Uint8Array | null> {
  const response = await fetch(url, { headers: { Range: `bytes=${start}-${end}` } });
  if (response.status !== 206) {
    try { await response.body?.cancel(); } catch (_) {}
    return null;
  }
  const bytes = new Uint8Array(await response.arrayBuffer());
  return bytes.length === end - start + 1 ? bytes : null;
}

/// Reads only MP4 atom headers and the movie metadata atom. This keeps large
/// video validation below the Edge Function memory ceiling instead of loading
/// the full uploaded video into the function's 256 MB runtime.
async function readMp4MovieBox(url: string): Promise<Uint8Array | null> {
  const maxMovieBoxBytes = 16 * 1024 * 1024;
  const maxVideoBytes = 50000000;
  let offset = 0;
  for (let atom = 0; atom < 2048 && offset < maxVideoBytes; atom++) {
    const baseHeader = await readByteRange(url, offset, offset + 7);
    if (!baseHeader) return null;
    let size = new DataView(baseHeader.buffer, baseHeader.byteOffset, baseHeader.byteLength).getUint32(0);
    const type = ascii(baseHeader, 4, 4);
    let headerSize = 8;
    if (size === 1) {
      const extended = await readByteRange(url, offset, offset + 15);
      if (!extended) return null;
      const view = new DataView(extended.buffer, extended.byteOffset, extended.byteLength);
      size = view.getUint32(8) * 0x100000000 + view.getUint32(12);
      headerSize = 16;
    } else if (size === 0) {
      // A zero-sized atom extends to EOF. It cannot contain a later moov atom.
      return null;
    }
    if (!Number.isSafeInteger(size) || size < headerSize || offset + size > maxVideoBytes) return null;
    if (type === 'moov') {
      if (size > maxMovieBoxBytes) return null;
      return readByteRange(url, offset, offset + size - 1);
    }
    offset += size;
  }
  return null;
}

function readMp4Dimensions(bytes: Uint8Array): { width: number | null; height: number | null } {
  const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
  const findTkhd = (start: number, end: number, depth: number): { width: number; height: number } | null => {
    if (depth > 6) return null;
    for (let offset = start; offset + 8 <= end;) {
      let size = view.getUint32(offset);
      const type = ascii(bytes, offset + 4, 4);
      let header = 8;
      if (size === 1) {
        if (offset + 16 > end) return null;
        const high = view.getUint32(offset + 8);
        const low = view.getUint32(offset + 12);
        size = high * 0x100000000 + low;
        header = 16;
      } else if (size === 0) size = end - offset;
      if (size < header || offset + size > end) return null;
      const payload = offset + header;
      const boxEnd = offset + size;
      if (type === 'tkhd' && size >= header + 84) {
        const version = bytes[payload];
        const width = view.getUint32(boxEnd - 8) / 65536;
        const height = view.getUint32(boxEnd - 4) / 65536;
        const matrixOffset = payload + (version === 1 ? 52 : 40);
        const a = view.getInt32(matrixOffset);
        const b = view.getInt32(matrixOffset + 4);
        const c = view.getInt32(matrixOffset + 12);
        const d = view.getInt32(matrixOffset + 16);
        const rotated = Math.abs(a) < 8 && Math.abs(d) < 8 && Math.abs(b) > 65000 && Math.abs(c) > 65000;
        return rotated ? { width: height, height: width } : { width, height };
      }
      if (type === 'moov' || type === 'trak') {
        const result = findTkhd(payload, boxEnd, depth + 1);
        if (result) return result;
      }
      offset = boxEnd;
    }
    return null;
  };
  const dimensions = findTkhd(0, bytes.length, 0);
  return dimensions ?? { width: null, height: null };
}

function readMp4DurationSeconds(bytes: Uint8Array): number | null {
  const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
  const findMovieHeader = (start: number, end: number, depth: number): number | null => {
    if (depth > 4) return null;
    for (let offset = start; offset + 8 <= end;) {
      let size = view.getUint32(offset);
      const type = ascii(bytes, offset + 4, 4);
      let header = 8;
      if (size === 1) {
        if (offset + 16 > end) return null;
        size = view.getUint32(offset + 8) * 0x100000000 + view.getUint32(offset + 12);
        header = 16;
      } else if (size === 0) size = end - offset;
      if (size < header || offset + size > end) return null;
      const payload = offset + header;
      const boxEnd = offset + size;
      if (type === 'mvhd') {
        if (payload + 20 > boxEnd) return null;
        const version = bytes[payload];
        const timescaleOffset = payload + (version === 1 ? 20 : 12);
        const durationOffset = payload + (version === 1 ? 24 : 16);
        if (timescaleOffset + 4 > boxEnd || durationOffset + (version === 1 ? 8 : 4) > boxEnd) return null;
        const timescale = view.getUint32(timescaleOffset);
        const duration = version === 1
          ? view.getUint32(durationOffset) * 0x100000000 + view.getUint32(durationOffset + 4)
          : view.getUint32(durationOffset);
        return timescale > 0 ? Math.round(duration / timescale) : null;
      }
      if (type === 'moov') {
        const result = findMovieHeader(payload, boxEnd, depth + 1);
        if (result !== null) return result;
      }
      offset = boxEnd;
    }
    return null;
  };
  return findMovieHeader(0, bytes.length, 0);
}

function isAllowedVideoRatio(width: number, height: number) {
  const ratio = width / height;
  return Number.isFinite(ratio) && ratio >= 0.5 && ratio <= 2.4;
}
