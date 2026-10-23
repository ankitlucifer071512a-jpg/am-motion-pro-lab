-- Phase 3: connect published video posts to public audio pages.
-- Additive only. Existing audio and post rows are preserved.

alter table public.audios
  add column if not exists artist_name text not null default '',
  add column if not exists source_url text,
  add column if not exists source_provider text,
  add column if not exists source_track_id text,
  add column if not exists uses_count bigint not null default 0
    check (uses_count >= 0);

alter table public.idea_posts
  add column if not exists audio_id uuid references public.audios(id) on delete set null;

create unique index if not exists audios_source_track_unique
  on public.audios (source_provider, source_track_id)
  where source_provider is not null and source_track_id is not null;
create unique index if not exists audios_original_post_unique
  on public.audios (source_post_id)
  where kind = 'original' and source_post_id is not null;
create index if not exists idea_posts_audio_created_idx
  on public.idea_posts (audio_id, created_at desc) where published_at is not null;

grant select (artist_name, source_url, source_provider, source_track_id, uses_count)
  on public.audios to anon, authenticated;

create table if not exists public.audio_saves (
  audio_id uuid not null references public.audios(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (audio_id, user_id)
);
alter table public.audio_saves enable row level security;
revoke all on public.audio_saves from public, anon, authenticated;
grant select, insert, delete on public.audio_saves to authenticated;
create policy "users read their audio saves" on public.audio_saves
  for select to authenticated using (user_id = (select auth.uid()));
create policy "users save approved audio" on public.audio_saves
  for insert to authenticated with check (
    user_id = (select auth.uid()) and exists (
      select 1 from public.audios a where a.id = audio_id and a.status = 'approved'
    )
  );
create policy "users remove their audio saves" on public.audio_saves
  for delete to authenticated using (user_id = (select auth.uid()));

create or replace function public.attach_audio_to_published_video()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  video_row record;
  track jsonb;
  selected_audio uuid;
  artist text;
  provider text;
  track_id text;
  license_code text;
  track_url text;
  track_title text;
  track_creator text;
begin
  if tg_op = 'INSERT' and new.published_at is null then return new; end if;
  if tg_op = 'UPDATE' and (new.published_at is null or old.published_at is not null) then
    return new;
  end if;
  if auth.uid() is null or auth.uid() <> new.creator_id then
    raise exception 'Only the post creator can publish its audio.';
  end if;

  select m.storage_path, m.thumbnail_url, m.duration_seconds
    into video_row
  from public.idea_post_media m
  where m.post_id = new.id and m.mime_type = 'video/mp4'
  order by m.position limit 1;
  if not found then return new; end if;

  track := new.music_metadata;
  if nullif(track->>'audio_id', '') is not null then
    select a.id into selected_audio from public.audios a
      where a.id = (track->>'audio_id')::uuid and a.status = 'approved'
        and a.allow_use_in_videos;
    if selected_audio is null then
      raise exception 'This audio is unavailable or the creator does not allow reuse.';
    end if;
    new.audio_id := selected_audio;
    return new;
  end if;
  track_id := nullif(btrim(track->>'track_id'), '');
  if track_id is not null then
    provider := lower(coalesce(track->>'provider', ''));
    license_code := lower(coalesce(track->>'license_code', ''));
    track_url := track->>'audio_url';
    track_title := nullif(btrim(track->>'title'), '');
    track_creator := nullif(btrim(track->>'creator'), '');
    if provider not in ('openverse', 'jamendo')
       or license_code not in ('cc0', 'pdm', 'by')
       or track_url !~ '^https://'
       or coalesce(track->>'source_url', '') !~ '^https://'
       or coalesce(track->>'license_url', '') !~ '^https://'
       or track_title is null or track_creator is null then
      raise exception 'Selected music is missing an approved provider or licence.';
    end if;

    insert into public.audios (
      kind, owner_id, title, artist_name, description, genre, audio_url,
      cover_url, duration_seconds, allow_use_in_videos, rights_declared,
      status, license, attribution, source_url, source_provider, source_track_id
    ) values (
      'library', new.creator_id, track_title, track_creator, '',
      coalesce(nullif(track->'genres'->>0, ''), ''), track_url,
      nullif(track->>'artwork_url', ''),
      greatest(0, coalesce((track->>'duration_ms')::integer, 0) / 1000),
      true, true, 'approved', track->>'license',
      coalesce(track->>'attribution', ''), track->>'source_url', provider, track_id
    ) on conflict (source_provider, source_track_id)
      where source_provider is not null and source_track_id is not null do nothing;

    select a.id into selected_audio from public.audios a
    where a.source_provider = provider and a.source_track_id = track_id
      and a.status = 'approved' and a.allow_use_in_videos;
    if selected_audio is null then
      raise exception 'Selected music is unavailable or is not approved for reuse.';
    end if;
    new.audio_id := selected_audio;
  else
    select p.display_name into artist from public.idea_profiles p where p.id = new.creator_id;
    insert into public.audios (
      kind, owner_id, title, artist_name, description, genre, audio_url,
      cover_url, duration_seconds, allow_use_in_videos, rights_declared,
      status, source_post_id, license, attribution
    ) values (
      'original', new.creator_id,
      left(coalesce(nullif(btrim(artist), ''), 'Creator') || '''s original audio', 160),
      coalesce(nullif(btrim(artist), ''), 'Creator'), '', '', video_row.storage_path,
      video_row.thumbnail_url, greatest(coalesce(video_row.duration_seconds, 0), 0),
      coalesce(new.allow_audio_use, true), false, 'approved', new.id,
      null, 'Original audio by ' || coalesce(nullif(btrim(artist), ''), 'Creator') || '. Rights have not been verified.'
    ) on conflict (source_post_id) where kind = 'original' and source_post_id is not null
      do nothing;
    select a.id into selected_audio from public.audios a
      where a.kind = 'original' and a.source_post_id = new.id;
    new.audio_id := selected_audio;
  end if;
  return new;
end;
$$;
revoke all on function public.attach_audio_to_published_video() from public, anon, authenticated;
drop trigger if exists idea_posts_attach_audio on public.idea_posts;
create trigger idea_posts_attach_audio
  before insert or update of published_at on public.idea_posts
  for each row execute function public.attach_audio_to_published_video();

create or replace function public.hide_original_audio_with_post()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is not null and auth.uid() <> old.creator_id then
    raise exception 'Only the post creator can hide its original audio.';
  end if;
  update public.audios set status = 'hidden'
    where kind = 'original' and source_post_id = old.id;
  return old;
end;
$$;
revoke all on function public.hide_original_audio_with_post() from public, anon, authenticated;
drop trigger if exists idea_posts_hide_original_audio on public.idea_posts;
create trigger idea_posts_hide_original_audio
  before delete on public.idea_posts
  for each row execute function public.hide_original_audio_with_post();

create or replace function public.hide_original_audio_when_post_unpublished()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if old.published_at is not null and new.published_at is null then
    if auth.uid() is not null and auth.uid() <> old.creator_id then
      raise exception 'Only the post creator can hide its original audio.';
    end if;
    update public.audios set status = 'hidden'
      where kind = 'original' and source_post_id = old.id;
  end if;
  return new;
end;
$$;
revoke all on function public.hide_original_audio_when_post_unpublished() from public, anon, authenticated;
drop trigger if exists idea_posts_hide_original_audio_unpublished on public.idea_posts;
create trigger idea_posts_hide_original_audio_unpublished
  before update of published_at on public.idea_posts
  for each row execute function public.hide_original_audio_when_post_unpublished();

create or replace function public.refresh_audio_uses_count()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op <> 'INSERT' and old.audio_id is not null then
    update public.audios a set uses_count = (
      select count(*) from public.idea_posts p where p.audio_id = a.id and p.published_at is not null
    ) where a.id = old.audio_id;
  end if;
  if tg_op <> 'DELETE' and new.audio_id is not null then
    update public.audios a set uses_count = (
      select count(*) from public.idea_posts p where p.audio_id = a.id and p.published_at is not null
    ) where a.id = new.audio_id;
  end if;
  if tg_op = 'DELETE' then return old; end if;
  return new;
end;
$$;
revoke all on function public.refresh_audio_uses_count() from public, anon, authenticated;
drop trigger if exists idea_posts_refresh_audio_uses on public.idea_posts;
create trigger idea_posts_refresh_audio_uses
  after insert or update of audio_id, published_at or delete on public.idea_posts
  for each row execute function public.refresh_audio_uses_count();

create or replace function public.idea_audio_reel_view_counts(target_posts uuid[])
returns table(post_id uuid, view_count bigint)
language sql stable security definer set search_path = '' as $$
  select v.post_id, count(*)::bigint
  from public.idea_post_views v
  where v.post_id = any(target_posts)
    and public.idea_post_is_visible(v.post_id)
  group by v.post_id;
$$;
revoke all on function public.idea_audio_reel_view_counts(uuid[]) from public;
grant execute on function public.idea_audio_reel_view_counts(uuid[]) to anon, authenticated;

-- Backfill links and audio rows for videos published before this migration.
-- The original post/media rows are left untouched.
insert into public.audios (
  kind, owner_id, title, artist_name, description, genre, audio_url, cover_url,
  duration_seconds, allow_use_in_videos, rights_declared, status, license,
  attribution, source_url, source_provider, source_track_id
)
select distinct on (lower(coalesce(p.music_metadata->>'provider', '')),
                    p.music_metadata->>'track_id')
  'library', p.creator_id,
  left(coalesce(nullif(btrim(p.music_metadata->>'title'), ''), 'Licensed audio'), 160),
  coalesce(nullif(btrim(p.music_metadata->>'creator'), ''), 'Creator'), '',
  coalesce(nullif(p.music_metadata->'genres'->>0, ''), ''),
  p.music_metadata->>'audio_url', nullif(p.music_metadata->>'artwork_url', ''),
  greatest(0, coalesce((p.music_metadata->>'duration_ms')::integer, 0) / 1000),
  true, true, 'approved', p.music_metadata->>'license',
  coalesce(p.music_metadata->>'attribution', ''), p.music_metadata->>'source_url',
  lower(p.music_metadata->>'provider'), p.music_metadata->>'track_id'
from public.idea_posts p
join public.idea_post_media m on m.post_id = p.id and m.mime_type = 'video/mp4'
where p.published_at is not null
  and nullif(p.music_metadata->>'track_id', '') is not null
  and lower(coalesce(p.music_metadata->>'provider', '')) in ('openverse', 'jamendo')
  and lower(coalesce(p.music_metadata->>'license_code', '')) in ('cc0', 'pdm', 'by')
  and coalesce(p.music_metadata->>'audio_url', '') ~ '^https://'
  and coalesce(p.music_metadata->>'source_url', '') ~ '^https://'
  and coalesce(p.music_metadata->>'license_url', '') ~ '^https://'
  and nullif(btrim(p.music_metadata->>'title'), '') is not null
  and nullif(btrim(p.music_metadata->>'creator'), '') is not null
on conflict (source_provider, source_track_id)
  where source_provider is not null and source_track_id is not null do nothing;

insert into public.audios (
  kind, owner_id, title, artist_name, description, genre, audio_url, cover_url,
  duration_seconds, allow_use_in_videos, rights_declared, status, source_post_id,
  license, attribution
)
select 'original', p.creator_id,
  left(coalesce(nullif(btrim(profile.display_name), ''), 'Creator') || '''s original audio', 160),
  coalesce(nullif(btrim(profile.display_name), ''), 'Creator'), '', '',
  media.storage_path, media.thumbnail_url, greatest(coalesce(media.duration_seconds, 0), 0),
  coalesce(p.allow_audio_use, true), false, 'approved', p.id,
  null, 'Original audio by ' || coalesce(nullif(btrim(profile.display_name), ''), 'Creator') || '. Rights have not been verified.'
from public.idea_posts p
join public.idea_post_media media on media.post_id = p.id and media.mime_type = 'video/mp4'
left join public.idea_profiles profile on profile.id = p.creator_id
where p.published_at is not null
  and (p.music_metadata is null or nullif(p.music_metadata->>'track_id', '') is null)
on conflict (source_post_id) where kind = 'original' and source_post_id is not null do nothing;

update public.idea_posts p set audio_id = coalesce(
  (select a.id from public.audios a
   where a.source_provider = lower(p.music_metadata->>'provider')
     and a.source_track_id = p.music_metadata->>'track_id' and a.status = 'approved'),
  (select a.id from public.audios a
   where a.kind = 'original' and a.source_post_id = p.id and a.status = 'approved')
)
where p.published_at is not null and p.audio_id is null
  and exists (select 1 from public.idea_post_media m where m.post_id = p.id and m.mime_type = 'video/mp4')
  and (p.music_metadata is null or nullif(p.music_metadata->>'track_id', '') is null
    or exists (select 1 from public.audios a
      where a.source_provider = lower(p.music_metadata->>'provider')
        and a.source_track_id = p.music_metadata->>'track_id' and a.status = 'approved'));
