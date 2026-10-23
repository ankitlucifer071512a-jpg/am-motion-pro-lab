# Idea Lab backend setup

## What the app uses

The repository had no server source, Idea Lab API, authentication, or configured database/media provider. The old Render URL in `AppConstants` has no Idea Lab integration. This implementation uses Supabase Auth, Postgres, and Supabase Storage. Originals are stored in the `idea-media` object-storage bucket; post rows and media paths are stored in Postgres. The app uses only the project URL and publishable key. No service-role or secret key belongs in Flutter.

## Create and configure the project

1. Create a Supabase project in the [Supabase dashboard](https://supabase.com/dashboard). Choose a region near your users and save the project database password in your password manager.
2. In **SQL Editor**, run [`supabase/migrations/202610160001_idea_lab.sql`](../supabase/migrations/202610160001_idea_lab.sql) once. It creates the creator profile trigger, seeded categories, posts, media, tags, saved posts, story metadata/view tables, RLS policies, and the `idea-media` and `idea-stories` buckets.
3. In **Authentication → Providers**, enable Email. For testing, keep email confirmation on and confirm the signup message. Add the eventual app URLs to **Authentication → URL Configuration** if using confirmation redirects.
4. In **Project Settings → API**, copy the full Project URL (including `https://`) and the **publishable** key (the `sb_publishable_...` key; legacy `anon` keys also work). Store them in the ignored `supabase-credentials.json` file using the same JSON field names as [`supabase-credentials.example.json`](../supabase-credentials.example.json). Never add privileged keys to this file.
5. Install the Supabase CLI, run `supabase login`, then `supabase link --project-ref YOUR_PROJECT_REF`. Deploy the server validator and story cleanup function with `supabase functions deploy validate-idea-media` and `supabase functions deploy expire-idea-stories`.
6. Follow the safer local secret-file method in **Exact setup checklist for this workspace** below. The privileged key and random cleanup token are stored only as Edge Function secrets; never put them in Flutter or commit them. The validator also uses the platform's `SUPABASE_URL` and `SUPABASE_ANON_KEY` environment values.
7. Run `flutter pub get`, then either choose the **AM Motion Lab (Supabase)** VS Code launch profile (defined in `.vscode/launch.json`) or run `flutter run --dart-define-from-file=supabase-credentials.json` from the project root. The launch profile passes the ignored JSON file to Flutter's compile-time environment; merely creating the file does not load it automatically.
8. Open Idea Lab → **Create Post**. Create an account, confirm the email if requested, sign in, select images and/or an MP4, add a caption/category/tags, and press **Publish**. A success message appears only after object upload, server byte/dimension validation, and the database publish update succeed.
9. To physically delete expired story files, enable **pg_cron**, **pg_net**, and **Vault** in Database → Extensions. Add the project URL, publishable key, and the same `STORY_CLEANUP_SECRET` value to Vault. In SQL Editor, run this schedule after replacing each value locally; keep the cleanup token in Vault and never commit it:

   ```sql
   select vault.create_secret('https://YOUR_PROJECT_REF.supabase.co', 'idea_project_url');
   select vault.create_secret('sb_publishable_YOUR_KEY', 'idea_publishable_key');
   select vault.create_secret('YOUR_RANDOM_CLEANUP_SECRET', 'idea_story_cleanup_secret');

   select cron.schedule(
     'expire-idea-stories-every-five-minutes',
     '*/5 * * * *',
     $$
       select net.http_post(
         url := (select decrypted_secret from vault.decrypted_secrets where name = 'idea_project_url') || '/functions/v1/expire-idea-stories',
         headers := jsonb_build_object(
           'Content-Type', 'application/json',
           'apikey', (select decrypted_secret from vault.decrypted_secrets where name = 'idea_publishable_key'),
           'x-cleanup-secret', (select decrypted_secret from vault.decrypted_secrets where name = 'idea_story_cleanup_secret')
         ),
         body := '{}'::jsonb
       );
     $$
   );
   ```

   Run these `vault.create_secret` statements once. Supabase's [scheduled Edge Function guide](https://supabase.com/docs/guides/functions/schedule-functions) documents this pattern. The migration makes the story bucket private and signed URLs stop being issued at expiry; the scheduled cleanup also removes stored objects.

The client can also build without credentials; in that state publishing stays disabled and no local preview is described as an upload. `supabase-credentials.json` contains a public client key, not a privileged key, but should still not be committed. RLS is the security boundary. Never use a service-role key in this file.

## Exact setup checklist for this workspace

The ignored `supabase-credentials.json` file is present in this checkout. Its key field is present and non-placeholder, but its Project URL is not a full HTTPS URL, so the app will not initialize Supabase from it yet. I did not include either credential value in this documentation. There is no local Supabase project link or deployment record, and `supabase`, `psql`, and `deno` are not installed in the current shell; therefore database, bucket, function, authentication, and upload status cannot be confirmed from this workspace. Publishing stays disabled until the URL is corrected, the file is passed to Flutter at launch, and the live setup check succeeds.

1. Create or open your project in the Supabase dashboard. In **Project Settings → API**, copy the full Project URL and the **publishable** client key (or legacy anon key). Do not use a service-role/secret key in Flutter.
2. The ignored `supabase-credentials.json` already exists locally. Correct its `SUPABASE_URL` to the full HTTPS Project URL and ensure `SUPABASE_PUBLISHABLE_KEY` is the publishable/anon key. Do not paste either value into reports or chat. The file is passed to Flutter using the VS Code profile or `--dart-define-from-file`; ordinary `.env` files are not read by this app.
3. In the dashboard **SQL Editor**, run the complete file [`supabase/migrations/202610160001_idea_lab.sql`](../supabase/migrations/202610160001_idea_lab.sql) once. It creates the tables, signup profile trigger and backfill, indexes, validation trigger, grants, RLS policies, and both buckets. Verify that `idea-media` is **public** and `idea-stories` is **private**, both with the 50 MiB file limit and the JPG/PNG/WebP/MP4 MIME list. The migration creates storage policies too; do not add broad anonymous write policies.
4. In **Authentication → Providers**, enable Email. Set the confirmation behavior you want; if confirmation is on, confirm the email before signing into the app. Configure the app/site redirect URL in **Authentication → URL Configuration** if your auth email links need to return to the app.
5. Install the Supabase CLI from the [official CLI setup guide](https://supabase.com/docs/guides/cli), sign in with `supabase login`, then run `supabase link --project-ref YOUR_PROJECT_REF` from the repository root. Keep the project ref public; never paste a key into chat.
6. Create `supabase/.env.local` locally (it is ignored by Git) with these two lines, replacing values locally:

   ```text
   SUPABASE_SERVICE_ROLE_KEY=YOUR_PROJECT_SERVICE_ROLE_KEY
   STORY_CLEANUP_SECRET=YOUR_LONG_RANDOM_TOKEN
   ```

   In **Project Settings → API**, retrieve the project service-role key only for this local CLI secret upload. Run `supabase secrets set --env-file supabase/.env.local`, then delete the local file when done. The key is stored as an Edge Function secret; do not put it in the credentials JSON, Flutter code, screenshots, or chat. The platform supplies `SUPABASE_URL` and the client anon key to deployed functions.
7. Deploy the functions from the repository root: `supabase functions deploy validate-idea-media` and `supabase functions deploy expire-idea-stories`. `validate-idea-media` is required for publishing and the app checks it, the schema, creator profile, and buckets before enabling Publish. Story cleanup also needs the scheduled-function setup in step 9 below. The social profile feature additionally deploys `match-idea-contacts` as described in the addendum below.
8. Run `flutter pub get`, then launch from the project root with `flutter run --dart-define-from-file=supabase-credentials.json`. In the app open Idea Lab → Create Post, create an account, confirm email if requested, then sign in. The app checks the actual backend; if setup is incomplete, the specific missing schema/bucket/function is shown and Publish stays disabled.
9. To physically delete expired story files, enable **pg_cron**, **pg_net**, and **Vault** in Database → Extensions, then use the Vault/cron SQL below. This is optional for normal post publishing but required to purge expired story objects automatically.

The RLS and Storage policies are defined in the migration and enforce authenticated owner-folder uploads, public read access only for the published-media bucket, private active-story reads, and creator-owned metadata writes. Avoid adding permissive dashboard policies that bypass those rules.

### First test graphic and first 100 graphics

In Idea Lab, press **Create Post**, create/sign into the creator account, select JPG/JPEG/PNG/WebP images, add MP4 videos one at a time, enter a caption and category, then press **Publish**. The client and database no longer enforce a 100-item-per-post cap. Each object is still limited to 50 MiB by the configured bucket, and the Supabase project plan controls total storage and bandwidth; storage is not unlimited. Videos are validated as exactly 16:9 or 9:16.

## Data and access rules

The migration configures RLS on every Idea Lab table. Public visitors can read published posts, active stories, categories, profiles, and media; only authenticated creators can write under their own user ID. Draft rows and their media are visible to their creator. The database rejects publishing if the post has no media, storage paths outside the creator/post folder, or unvalidated media. Storage object paths are `auth-user-id/post-id/random-name.ext`.

Image types allowed are JPEG, PNG, and WebP; MP4 is accepted for video. The Edge Function reads uploaded bytes, checks file signatures, extracts MP4 display dimensions, rejects video ratios other than 16:9 or 9:16, then marks draft media validated using the server-only service key. The Edge Function also verifies that the caller owns the draft/story. A 50 MiB maximum applies per object in the buckets; after migration `202610170002`, the app and database no longer enforce a media-count or aggregate-per-post cap. Stories are limited to 30-second videos, use signed URLs that expire no later than the story, and expire using database timestamps after 24 hours. The client uses a 24-item paginated feed. Supabase plan storage, bandwidth, and database quotas still apply; this is not unlimited storage. No generated video thumbnail service is configured; video cards show a play icon and story video thumbnails are placeholders.

## Current verification boundary

The user has confirmed that the app initializes against Supabase and has published an image post. Remote migration status could not be read from this workspace. Follow and messaging require migration `202610160002`; post engagement requires `202610170001`; story engagement and unbounded per-post media require `202610170002`. Verify each ID under Remote before relying on those features.

## Creator profiles, follows, messages, views, and contacts

1. In the Supabase **SQL Editor**, run [`supabase/migrations/202610160002_idea_social.sql`](../supabase/migrations/202610160002_idea_social.sql). It adds usernames, bios, public creator avatars, follower relationships, authenticated post views, direct messages, and the server-only contact match function. It also creates the `idea-avatars` bucket.
2. Deploy the contact matcher: `supabase functions deploy match-idea-contacts`. It verifies the caller's Supabase session and limits each account to five matching requests per hour. The service-role key is used only by the Edge Function and must never be placed in Flutter or shared in chat. This function receives contact addresses only after the user taps a sync button and approves the in-app prompt; it does not persist the contact list.
3. For Google Contacts, enable **Manual Linking** in Supabase Authentication settings, configure the Google provider and redirect URLs, and enable the **People API** in the linked Google Cloud project. Google requires the `contacts.readonly` scope; Google may require a consent-screen setup or review for production. The app requests that scope only after the user chooses **Connect Google contacts**. See [Supabase identity linking](https://supabase.com/docs/reference/dart/auth-linkidentity) and [Google People API contacts](https://developers.google.com/people/api/rest/v1/people/connections/list).
4. Phone contacts are supported in the Android/iOS app after OS permission. Browser builds cannot read the device address book and should use username search or Google Contacts. Phone-number matching only finds accounts with a verified phone number in Supabase Auth; this app's current sign-in screen does not yet offer phone-number authentication. Contact phone numbers should include the country code for reliable matching.
5. Profiles support avatar files up to 5 MiB in `idea-avatars`; creator avatars and published Idea Lab media are public. RLS limits profile edits and file writes to the signed-in owner's ID. Messages are visible only to their two participants. Followers, views, and posts are tied to Supabase rows; Game Lab's practice rating remains local to the current device and is not an expert/AI assessment.

Home remains unchanged and does not fetch these posts because the existing Home showcase has no Idea Lab data connection and this request limits changes to Idea Lab. Story image/MP4 upload, seen state, full-screen viewer, signed URL expiry, creator-only deletion, and a scheduled file-cleanup function are implemented; the cleanup schedule must be enabled in the project dashboard. Stories do not have generated video thumbnails. Large selections consume device memory and are constrained by the project's actual storage and bandwidth quota.

## Post and story likes, comments, replies, and reports

The client includes post likes, threaded comments/replies, reports, and device sharing. These require [`supabase/migrations/202610170001_idea_post_interactions.sql`](../supabase/migrations/202610170001_idea_post_interactions.sql). Story likes/comments and removal of the old 100-media-row per-post cap require [`supabase/migrations/202610170002_idea_story_interactions_unbounded_posts.sql`](../supabase/migrations/202610170002_idea_story_interactions_unbounded_posts.sql). Migration `202610170003_allow_self_likes.sql` lets creators like their own posts. Migration `202610170004_fix_comment_policy_recursion.sql` prevents recursive comment RLS checks. From the linked project root run `npx supabase db push`, then verify exact IDs `202610170001` through `202610170004` under Remote in `npx supabase migration list`. The IDs start with `202610`, not `202510`. Reports are private; no moderation dashboard/alerts are configured. The post download action downloads the original media through the platform save dialog.

Messages use the existing `idea_messages` table from migration `202610160002`; the list shows actual last-message previews and unread counts, and the chat refreshes from Supabase every eight seconds. No realtime publication/subscription is configured in this project. Enable `idea_messages` in **Database → Publications → supabase_realtime** and add a Supabase Realtime subscription before expecting instant push updates; polling is the current fallback.
# Google/Facebook OAuth and Creative AI setup

## Google and Facebook sign-in

The Flutter sign-in buttons already use Supabase OAuth. Keep provider client secrets in the provider dashboard and Supabase Auth only; do not add them to Flutter or `supabase-credentials.json`.

1. In Supabase Dashboard, open **Authentication → Providers** and copy the callback URL shown by each provider.
2. In Google Cloud, create an OAuth client of type **Web application**. For repeatable local testing, run Chrome on port 5000 and add `http://localhost:5000` as an Authorized JavaScript origin; add the Supabase callback URL as an Authorized redirect URI. Add its Client ID and Client Secret to **Supabase → Authentication → Providers → Google**, then enable and save. Google requires the `openid`, email, and profile scopes.
3. In Meta for Developers, create/configure a Facebook app and Facebook Login. Set the Supabase callback URL in **Facebook Login → Settings → Valid OAuth Redirect URIs**. Enable `public_profile` and `email`; then place the App ID and App Secret in **Supabase → Authentication → Providers → Facebook**, enable, and save. Facebook may require adding test users or switching the app to Live before general users can sign in.
4. In **Supabase → Authentication → URL Configuration**, set Site URL to the deployed app URL and add redirect URLs for local web development (`http://localhost:5000/**`), the deployed app origin, and the native callback `ammotionlab://login-callback/`. The Android and iOS URL schemes are already registered in this project.
5. Run Chrome with `flutter run -d chrome --web-port 5000 --dart-define-from-file=supabase-credentials.json` and test Google and Facebook separately. The browser build returns to its current origin; mobile returns via the registered `ammotionlab` deep link. OAuth cannot complete until provider credentials are saved.

Provider setup references: [Google](https://supabase.com/docs/guides/auth/social-login/auth-google), [Facebook](https://supabase.com/docs/guides/auth/social-login/auth-facebook), and [redirect URLs](https://supabase.com/docs/guides/auth/redirect-urls).

## Gemini Creative AI

The Flutter client calls the authenticated `creative-ai-chat` Edge Function. The function validates the current user, limits each message to 1,200 characters and the context to 8,000 characters, caps history at 10 earlier turns, and enforces 20 requests per user per hour in Postgres. Gemini's key and model are read only on the server. No chat transcript is saved by this app.

1. Create a Gemini API key in Google AI Studio. Free access is limited by model/project rate limits and Google states that free-tier prompts/responses may be used to improve products; paid service has different data handling. Review Google's current [pricing](https://ai.google.dev/gemini-api/docs/pricing), [rate limits](https://ai.google.dev/gemini-api/docs/rate-limits), and [terms](https://ai.google.dev/gemini-api/terms) before production use. The default model is configurable and currently `gemini-3.1-flash-lite`.
2. Add `GEMINI_API_KEY=your-key` and `GEMINI_MODEL=gemini-3.1-flash-lite` to the ignored `supabase/.env.local` file. If that file already contains other secrets, append these entries rather than replacing it.
3. The AI quota migration and `creative-ai-chat` function are already deployed for this workspace. From the project root, upload the secret:

   ```powershell
   npx.cmd supabase secrets set --env-file supabase/.env.local
   ```

   Supabase makes newly set Edge Function secrets available without redeploying the function. If deploying this feature to another project, first run `npx.cmd supabase db push` and `npx.cmd supabase functions deploy creative-ai-chat`.
4. Restart the app, sign in, and send a chat prompt. Only a returned Gemini response confirms live AI is connected. The database quota is a basic per-user cap; it is not a global spend ceiling, so review Google AI Studio usage/billing if the app is exposed publicly.
