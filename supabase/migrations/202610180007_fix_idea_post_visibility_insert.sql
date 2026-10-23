-- Remove the legacy all-command visibility policy that rejects unpublished
-- drafts. Draft creation and owner updates remain protected by the existing
-- creator ownership policies. Published reads continue to use the audience
-- and privacy policies installed by the Idea Lab privacy migrations.
drop policy if exists "idea_post_visibility" on public.idea_posts;
