-- Allow the uploader to read its own newly inserted Storage metadata row.
-- Storage upload uses INSERT ... RETURNING; without a matching SELECT policy,
-- a valid upload can fail with 403 even when its INSERT policy passes.
create policy "creators read own Idea Lab media objects"
  on storage.objects for select to authenticated
  using (
    bucket_id = 'idea-media'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );
