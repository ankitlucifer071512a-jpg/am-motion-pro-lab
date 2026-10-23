# Idea Lab music library

The music search uses the public Openverse audio API through the authenticated
`idea-music-search` Supabase Edge Function. The function calls Openverse anonymously;
no Openverse Client ID or Client Secret is needed. Openverse says anonymous access
is free and its anonymous rate limits should be sufficient for most users. Requests
are rate-limited, so the app displays retry guidance if Openverse returns HTTP 429.
The function filters for `CC0`, Public Domain
Mark, and `CC BY` works only. It excludes NonCommercial, NoDerivatives, and
ShareAlike results because this app's deployment and user-created publishing
can be commercial and content is adapted/synchronized. The API returns real
catalogue results; it does not expose a live trending chart. “Trending” and
“Popular / Featured” are disclosed as search-ranked catalogue results, not a
live trend feed. Categories include Indian instrumental/classical, folk,
devotional, cinematic, lo-fi, ambient, upbeat, emotional, motivational,
electronic, acoustic, and sound effects, alongside Hindi/Bollywood, Tamil,
Telugu, Punjabi, Carnatic, and Hindustani. Search pages load on demand and are
cached in memory for five minutes; duplicate IDs are removed. Related Music
first uses Openverse's related-audio endpoint and expands sparse results using
the selected track's actual title, creator, genres, and tags. Openverse currently
indexes text using English analysis, so regional
language coverage depends on English metadata. These results are not guaranteed
to include popular commercial Indian film songs; only tracks with compatible
open licences are shown.

Openverse aggregates third-party metadata and explicitly does not verify the
underlying licence. Creators must check the original landing page and the
track's licence before publishing. Attribution/source/licence data is retained
with Idea Lab post/story metadata. CC BY requires attribution. A search result
does not by itself grant a separate right to redistribute a standalone track.

Free To Use was not selected: its current Free License permits use in individual
user-generated social content, but expressly excludes use in a digital product
such as this app. Commercial app use requires a paid licence.

## Setup and deployment

No Openverse account, API credentials, or Supabase secrets are required for search.
The Edge Function calls `GET /v1/audio/` and
`GET /v1/audio/{identifier}/related/`. Anonymous Openverse API usage is free but
rate-limited; related-audio results may be empty for some tracks.
After updating the Edge Function, deploy it from the project root:

   ```powershell
   npx.cmd supabase functions deploy idea-music-search
   ```

Then start Flutter with the normal Supabase credential file, sign in, and open
Idea Lab's music icon. The app's own signed-in user session is still required to
invoke the Supabase function; these are separate from Openverse credentials.


## Music in posts and stories

Track metadata, source, licence, attribution, selected segment, and chosen music
volume are stored as JSON on the post/story. Story creation offers an explicit
choice to add music or continue without it. The in-app media viewer plays the original image or
video and a separate music stream; original video audio remains adjustable and
music has its own volume control, with reduced levels to avoid clipping. A
static image remains an image: current publishing does not encode/mux a new MP4
file with music, and a downloaded original will not contain music. That needs a
real media-export/transcoding pipeline before it can be promised as an audio
embedded video. The 5-second image story display may also outlast/shorten a
selected audio segment according to the creator's segment choice.
