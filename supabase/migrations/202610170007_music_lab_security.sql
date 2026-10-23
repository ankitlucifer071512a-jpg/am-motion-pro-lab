-- Music Lab Stage 1: additive schema and server-enforced access controls.
-- Existing Idea Lab tables, rows, and buckets are intentionally untouched.

do $$
begin
  if exists (select 1 from storage.buckets where id in ('music-audio', 'music-covers')) then
    raise exception 'A Music Lab Storage bucket already exists; inspect its configuration before applying this migration.';
  end if;
  if to_regclass('public.audios') is not null
     or to_regclass('public.audio_admins') is not null
     or to_regclass('public.audio_likes') is not null
     or to_regclass('public.audio_reports') is not null
     or to_regclass('public.audio_play_events') is not null then
    raise exception 'A Music Lab table already exists; inspect its schema before applying this migration.';
  end if;
end;
$$;

create table public.audio_admins (
  user_id uuid primary key references auth.users(id) on delete cascade,
  added_at timestamptz not null default now()
);
alter table public.audio_admins enable row level security;
revoke all on public.audio_admins from public, anon, authenticated;
grant select on public.audio_admins to authenticated;
create policy "audio admins may see their own membership" on public.audio_admins
  for select to authenticated using (user_id = (select auth.uid()));

create or replace function public.is_audio_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.audio_admins a where a.user_id = (select auth.uid())
  );
$$;
revoke all on function public.is_audio_admin() from public, anon, authenticated;
-- Needed by public-row RLS predicates; auth.uid() is null for anonymous requests.
grant execute on function public.is_audio_admin() to anon, authenticated;

create table public.audios (
  id uuid primary key default gen_random_uuid(),
  kind text not null check (kind in ('upload', 'original', 'library')),
  owner_id uuid not null references auth.users(id) on delete cascade,
  title text not null check (char_length(title) between 1 and 160 and btrim(title) <> ''),
  description text not null default '' check (char_length(description) <= 3000),
  genre text not null default '' check (char_length(genre) <= 80),
  audio_url text not null,
  cover_url text,
  duration_seconds integer not null default 0 check (duration_seconds >= 0),
  allow_use_in_videos boolean not null default false,
  rights_declared boolean not null default false,
  status text not null default 'pending'
    check (status in ('pending', 'approved', 'hidden', 'removed')),
  plays_count bigint not null default 0 check (plays_count >= 0),
  likes_count bigint not null default 0 check (likes_count >= 0),
  report_count integer not null default 0 check (report_count >= 0),
  source_post_id uuid references public.idea_posts(id) on delete set null,
  license text,
  attribution text,
  moderation_note text,
  created_at timestamptz not null default now(),
  constraint audios_non_original_source_post check (kind = 'original' or source_post_id is null),
  constraint audios_library_license_fields check (
    kind <> 'library' or (nullif(btrim(license), '') is not null and attribution is not null)
  )
);
create index audios_owner_created_idx on public.audios (owner_id, created_at desc);
create index audios_approved_created_idx on public.audios (created_at desc) where status = 'approved';
create index audios_approved_genre_idx on public.audios (lower(genre), created_at desc) where status = 'approved';

create table public.audio_likes (
  audio_id uuid not null references public.audios(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (audio_id, user_id)
);
create index audio_likes_user_idx on public.audio_likes (user_id, created_at desc);

create table public.audio_reports (
  audio_id uuid not null references public.audios(id) on delete cascade,
  reporter_id uuid not null references auth.users(id) on delete cascade,
  reason text not null check (reason in ('copyright', 'inappropriate', 'spam')),
  created_at timestamptz not null default now(),
  primary key (audio_id, reporter_id)
);

create table public.audio_play_events (
  audio_id uuid not null references public.audios(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  session_id uuid not null,
  created_at timestamptz not null default now(),
  primary key (audio_id, user_id, session_id)
);

alter table public.audios enable row level security;
alter table public.audio_likes enable row level security;
alter table public.audio_reports enable row level security;
alter table public.audio_play_events enable row level security;
revoke all on public.audios, public.audio_likes, public.audio_reports,
  public.audio_play_events from public, anon, authenticated;

grant select (id, kind, owner_id, title, description, genre, audio_url, cover_url,
  duration_seconds, allow_use_in_videos, rights_declared, status, plays_count,
  likes_count, source_post_id, license, attribution, created_at)
  on public.audios to anon, authenticated;
grant insert (id, kind, owner_id, title, description, genre, audio_url, cover_url,
  duration_seconds, allow_use_in_videos, rights_declared, source_post_id,
  license, attribution) on public.audios to authenticated;
grant update (title, description, genre, cover_url, allow_use_in_videos)
  on public.audios to authenticated;
grant delete on public.audios to authenticated;

grant select, insert, delete on public.audio_likes to authenticated;
grant select, insert on public.audio_reports to authenticated;
-- Play events and counters are only writable by the database function/triggers.

create policy "approved audio or own audio visible" on public.audios
  for select to anon, authenticated using (
    status = 'approved'
    or owner_id = (select auth.uid())
    or (select public.is_audio_admin())
  );

-- Owners can read their own moderation note without exposing that column
-- through ordinary audio queries.
create or replace function public.get_own_audio_moderation_note(target_audio uuid)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select a.moderation_note
  from public.audios a
  where a.id = target_audio
    and a.owner_id = (select auth.uid());
$$;
revoke all on function public.get_own_audio_moderation_note(uuid) from public, anon, authenticated;
grant execute on function public.get_own_audio_moderation_note(uuid) to authenticated;

create or replace function public.reset_approved_audio_for_review()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if old.status = 'approved'
     and not public.is_audio_admin()
     and (new.title is distinct from old.title
       or new.description is distinct from old.description
       or new.genre is distinct from old.genre
       or new.cover_url is distinct from old.cover_url) then
    new.status := 'pending';
  end if;
  return new;
end;
$$;
revoke all on function public.reset_approved_audio_for_review() from public, anon, authenticated;
create trigger audios_reset_approval_on_content_change
  before update of title, description, genre, cover_url on public.audios
  for each row execute function public.reset_approved_audio_for_review();

create policy "creators create pending uploads only" on public.audios
  for insert to authenticated with check (
    owner_id = (select auth.uid()) and kind = 'upload' and rights_declared
  );
create policy "creators update their upload details" on public.audios
  for update to authenticated using (
    owner_id = (select auth.uid()) and kind = 'upload'
  ) with check (
    owner_id = (select auth.uid()) and kind = 'upload'
  );
create policy "creators delete their own audio rows" on public.audios
  for delete to authenticated using (owner_id = (select auth.uid()));

create policy "users see own audio likes" on public.audio_likes
  for select to authenticated using (
    user_id = (select auth.uid()) or (select public.is_audio_admin())
  );
create policy "users like approved audios" on public.audio_likes
  for insert to authenticated with check (
    user_id = (select auth.uid()) and exists (
      select 1 from public.audios a where a.id = audio_id
        and a.status = 'approved' and a.owner_id <> (select auth.uid())
    )
  );
create policy "users remove own audio likes" on public.audio_likes
  for delete to authenticated using (user_id = (select auth.uid()));

create policy "reporters and admins read audio reports" on public.audio_reports
  for select to authenticated using (
    reporter_id = (select auth.uid()) or (select public.is_audio_admin())
  );
create policy "users report approved audios" on public.audio_reports
  for insert to authenticated with check (
    reporter_id = (select auth.uid()) and exists (
      select 1 from public.audios a where a.id = audio_id
        and a.status = 'approved' and a.owner_id <> (select auth.uid())
    )
  );

create or replace function public.validate_audio_upload_row()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  audio_meta jsonb;
  cover_meta jsonb;
  audio_path text;
  cover_path text;
  audio_mime text;
  cover_mime text;
  audio_size bigint;
  cover_size bigint;
begin
  if new.kind <> 'upload' then
    return new;
  end if;

  -- Storage enforces bucket MIME and byte limits; this also requires staged files.
  if new.audio_url !~ ('^' || new.owner_id::text || '/' || new.id::text || '/[^/]+$')
     or lower(new.audio_url) !~ '\.(mp3|m4a)$' then
    raise exception 'Audio must use an MP3/M4A path in the creator-owned audio folder.';
  end if;
  audio_path := new.audio_url;
  select o.metadata into audio_meta from storage.objects o
    where o.bucket_id = 'music-audio' and o.name = audio_path;
  if audio_meta is null then raise exception 'Audio upload is missing from Storage.'; end if;
  audio_mime := audio_meta->>'mimetype';
  audio_size := nullif(audio_meta->>'size', '')::bigint;
  if audio_mime not in ('audio/mpeg', 'audio/mp4', 'audio/x-m4a')
     or audio_size is null or audio_size <= 0 or audio_size > 10485760 then
    raise exception 'Audio Storage metadata is outside the allowed type or size.';
  end if;

  if new.cover_url is not null then
    if new.cover_url !~ ('^' || new.owner_id::text || '/' || new.id::text || '/[^/]+$')
       or lower(new.cover_url) !~ '\.(jpg|jpeg|png|webp)$' then
      raise exception 'Cover must use a supported image path in the creator-owned cover folder.';
    end if;
    cover_path := new.cover_url;
    select o.metadata into cover_meta from storage.objects o
      where o.bucket_id = 'music-covers' and o.name = cover_path;
    if cover_meta is null then raise exception 'Cover upload is missing from Storage.'; end if;
    cover_mime := cover_meta->>'mimetype';
    cover_size := nullif(cover_meta->>'size', '')::bigint;
    if cover_mime not in ('image/jpeg', 'image/png', 'image/webp')
       or cover_size is null or cover_size <= 0 or cover_size > 2097152 then
      raise exception 'Cover Storage metadata is outside the allowed type or size.';
    end if;
  end if;

  if tg_op = 'INSERT' then
    new.status := 'pending';
    new.plays_count := 0;
    new.likes_count := 0;
    new.report_count := 0;
  end if;
  return new;
end;
$$;
revoke all on function public.validate_audio_upload_row() from public, anon, authenticated;
create trigger audios_validate_upload_row
  before insert or update of audio_url, cover_url, kind, owner_id on public.audios
  for each row execute function public.validate_audio_upload_row();

create or replace function public.audio_like_counter()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    update public.audios set likes_count = likes_count + 1 where id = new.audio_id;
    return new;
  end if;
  update public.audios set likes_count = greatest(0, likes_count - 1) where id = old.audio_id;
  return old;
end;
$$;
revoke all on function public.audio_like_counter() from public, anon, authenticated;
create trigger audio_likes_counter
  after insert or delete on public.audio_likes
  for each row execute function public.audio_like_counter();

create or replace function public.audio_report_counter_and_hide()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.audios as a
    set report_count = a.report_count + 1,
        status = case when a.status = 'approved' and a.report_count + 1 >= 3
          then 'hidden' else a.status end,
        moderation_note = case when a.status = 'approved' and a.report_count + 1 >= 3
          then 'Automatically hidden after reaching the report threshold.'
          else a.moderation_note end
    where a.id = new.audio_id;
  return new;
end;
$$;
revoke all on function public.audio_report_counter_and_hide() from public, anon, authenticated;
create trigger audio_reports_counter_and_hide
  after insert on public.audio_reports
  for each row execute function public.audio_report_counter_and_hide();

create or replace function public.audio_play_counter()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.audios set plays_count = plays_count + 1 where id = new.audio_id;
  return new;
end;
$$;
revoke all on function public.audio_play_counter() from public, anon, authenticated;
create trigger audio_play_events_counter
  after insert on public.audio_play_events
  for each row execute function public.audio_play_counter();

create or replace function public.record_audio_play(target_audio uuid, target_session uuid)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  requester uuid := (select auth.uid());
  inserted_count integer := 0;
begin
  if requester is null then raise exception 'Sign in to record a play.'; end if;
  if target_session is null then raise exception 'A playback session ID is required.'; end if;
  -- Serialize attempts for this user/audio pair so simultaneous requests cannot
  -- both pass the 30-minute deduplication check.
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(
    'music-play:' || target_audio::text || ':' || requester::text, 0));
  if exists (
    select 1 from public.audio_play_events e
    where e.audio_id = target_audio
      and e.user_id = requester
      and e.created_at >= now() - interval '30 minutes'
  ) then
    return false;
  end if;
  insert into public.audio_play_events (audio_id, user_id, session_id)
  select a.id, requester, target_session
    from public.audios a
    where a.id = target_audio and a.status = 'approved'
      and a.owner_id <> requester
  on conflict (audio_id, user_id, session_id) do nothing;
  get diagnostics inserted_count = row_count;
  return inserted_count > 0;
end;
$$;
revoke all on function public.record_audio_play(uuid, uuid) from public, anon, authenticated;
grant execute on function public.record_audio_play(uuid, uuid) to authenticated;

create or replace function public.moderate_audio(
  target_audio uuid,
  next_status text,
  review_note text default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.is_audio_admin() then raise exception 'Audio administrator access is required.'; end if;
  if next_status not in ('approved', 'hidden', 'removed') then
    raise exception 'Unsupported moderation status.';
  end if;
  update public.audios set
    status = next_status,
    report_count = case when next_status = 'approved' then 0 else report_count end,
    moderation_note = nullif(btrim(review_note), '')
  where id = target_audio
    and (next_status <> 'approved' or rights_declared or kind = 'library');
  if not found then raise exception 'Audio was not found or is missing rights confirmation.'; end if;
end;
$$;
revoke all on function public.moderate_audio(uuid, text, text) from public, anon, authenticated;
grant execute on function public.moderate_audio(uuid, text, text) to authenticated;

-- New, private buckets. A pre-existing same-name bucket causes a safe migration failure.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('music-audio', 'music-audio', false, 10485760,
  array['audio/mpeg', 'audio/mp4', 'audio/x-m4a']);
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('music-covers', 'music-covers', false, 2097152,
  array['image/jpeg', 'image/png', 'image/webp']);

-- SECURITY DEFINER is required here so the object count is not filtered by the
-- caller's Storage RLS visibility. The advisory lock makes the 50-object cap
-- safe against concurrent uploads by the same user.
create or replace function public.can_upload_music_object(target_bucket text, target_name text)
returns boolean
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  requester uuid := (select auth.uid());
  object_count bigint;
begin
  if requester is null or target_bucket not in ('music-audio', 'music-covers') then
    return false;
  end if;
  if target_name !~ ('^' || requester::text
      || '/[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}/[^/]+$') then
    return false;
  end if;

  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(
    'music-upload-cap:' || requester::text, 0));
  select count(*) into object_count
  from storage.objects o
  where o.bucket_id in ('music-audio', 'music-covers')
    and left(o.name, char_length(requester::text) + 1) = requester::text || '/';
  return object_count < 50;
end;
$$;
revoke all on function public.can_upload_music_object(text, text) from public, anon, authenticated;
grant execute on function public.can_upload_music_object(text, text) to authenticated;

create policy "creators upload music to own folder" on storage.objects
  for insert to authenticated with check (
    public.can_upload_music_object(bucket_id, name)
  );
create policy "owners and approved listeners read music objects" on storage.objects
  for select to anon, authenticated using (
    bucket_id in ('music-audio', 'music-covers') and (
      (select auth.uid())::text = (storage.foldername(name))[1]
      or (select public.is_audio_admin())
      or exists (
        select 1 from public.audios a
        where a.status = 'approved'
          and ((bucket_id = 'music-audio' and a.audio_url = name)
            or (bucket_id = 'music-covers' and a.cover_url = name))
      )
    )
  );
create policy "owners delete their unapproved music objects" on storage.objects
  for delete to authenticated using (
    bucket_id in ('music-audio', 'music-covers')
    and (storage.foldername(name))[1] = (select auth.uid())::text
    and not exists (
      select 1 from public.audios a
      where a.status = 'approved'
        and ((bucket_id = 'music-audio' and a.audio_url = name)
          or (bucket_id = 'music-covers' and a.cover_url = name))
    )
  );

