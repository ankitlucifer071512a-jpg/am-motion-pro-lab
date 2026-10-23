-- Add duration metadata to Idea Lab videos. Existing rows remain valid and null.
alter table public.idea_post_media
  add column if not exists duration_seconds integer
  check (duration_seconds is null or duration_seconds >= 0);
