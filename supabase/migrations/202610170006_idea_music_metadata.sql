alter table public.idea_posts
  add column if not exists music_metadata jsonb;

alter table public.idea_stories
  add column if not exists music_metadata jsonb;

grant insert (music_metadata) on public.idea_posts to authenticated;
grant insert (music_metadata) on public.idea_stories to authenticated;

alter table public.idea_posts
  add constraint idea_posts_music_metadata_valid check (
    music_metadata is null or (
      jsonb_typeof(music_metadata) = 'object' and
      music_metadata->>'provider' = 'Openverse' and
      music_metadata->>'license_code' in ('cc0', 'pdm', 'by') and
      music_metadata->>'audio_url' like 'https://%' and
      music_metadata->>'source_url' like 'https://%' and
      music_metadata->>'license_url' like 'https://%' and
      coalesce((music_metadata->>'segment_start_ms')::bigint, -1) >= 0 and
      coalesce((music_metadata->>'segment_end_ms')::bigint, 0) >
        coalesce((music_metadata->>'segment_start_ms')::bigint, -1)
    )
  );

alter table public.idea_stories
  add constraint idea_stories_music_metadata_valid check (
    music_metadata is null or (
      jsonb_typeof(music_metadata) = 'object' and
      music_metadata->>'provider' = 'Openverse' and
      music_metadata->>'license_code' in ('cc0', 'pdm', 'by') and
      music_metadata->>'audio_url' like 'https://%' and
      music_metadata->>'source_url' like 'https://%' and
      music_metadata->>'license_url' like 'https://%' and
      coalesce((music_metadata->>'segment_start_ms')::bigint, -1) >= 0 and
      coalesce((music_metadata->>'segment_end_ms')::bigint, 0) >
        coalesce((music_metadata->>'segment_start_ms')::bigint, -1)
    )
  );
