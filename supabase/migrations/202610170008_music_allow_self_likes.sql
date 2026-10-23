-- Allow creators to like any approved audio, including their own.
-- Reporting one's own audio and audio play counting rules are unchanged.
drop policy if exists "users like approved audios" on public.audio_likes;

create policy "users like approved audios" on public.audio_likes
  for insert to authenticated with check (
    user_id = (select auth.uid()) and exists (
      select 1 from public.audios a
      where a.id = audio_id and a.status = 'approved'
    )
  );
