# AM Motion Lab asset guide

Keep supplied creative media in these folders. The app currently ships with the brand marks and five course thumbnails; the other folders are prepared for assets you add later.

## Folders

| Folder | Put these files here | Suggested size / format |
| --- | --- | --- |
| `brand/` | App logo and icon | PNG, transparent where useful; keep original proportions |
| `images/banners/` | Wide course or campaign headers | 1600 × 900 or 1920 × 1080, WebP or JPEG |
| `images/courses/` | Course card thumbnails (current cards use 16:9; home cards crop to 16:10) | 1600 × 900, WebP or JPEG; keep important subjects near the centre |
| `images/projects/` | Project and portfolio previews | 1200 × 800, WebP or JPEG |
| `images/challenges/` | Reference images used by practice challenges | 1200 × 800, WebP or JPEG |
| `images/placeholders/` | Branded stills for unavailable media | 1200 × 800, PNG or WebP |
| `models/gallery/` | Preview images for model catalogue entries | 1200 × 800, WebP or PNG |
| `models/characters/` | Character GLB files | Self-contained `.glb`; keep interactive files at or below 20 MB |
| `models/products/` | Product and prop GLB files | Self-contained `.glb`; keep interactive files at or below 20 MB |
| `models/environments/` | Environment GLB files | Self-contained `.glb`; keep interactive files at or below 20 MB |
| `models/animations/` | Animated GLB files | `.glb` with embedded animation clips and textures |
| `textures/` | Source texture files for authoring | PNG, JPEG, or WebP; embed/pack them into the final GLB for this app's current import flow |
| `audio/` | Licensed music, narration, and sound effects | WAV for source, AAC/MP3 for delivery; record licence and attribution |
| `data/courses/` | Future course catalogue exports | UTF-8 JSON; active course content currently lives in `lib/services/course_repository.dart` |
| `data/projects/` | Future project catalogue data | UTF-8 JSON |
| `data/challenges/` | Future challenge catalogue data | UTF-8 JSON |
| `data/models/` | 3D gallery catalogue | `model_catalog.json`; paths are relative to the project root |

## Naming and replacing files

Use lowercase kebab-case names, for example `video-editing-thumbnail.webp` and `studio-character-v01.glb`. Keep the file extension accurate. Replace an existing file at the same path to update that asset without changing its catalogue identifier. Add new model records to `data/models/model_catalog.json`; the gallery reads that catalogue rather than maintaining model cards in screen code.

Each model record has `id`, `title`, `category`, `description`, `format`, `assetPath`, `previewPath`, and `animationInfo`. Use `null` for `assetPath` or `previewPath` until the file exists. The starter records are explicitly labelled empty slots; they do not represent supplied models. Model paths must stay under `assets/models/`.

## Project showcase assets

Project entries are read from `assets/data/projects/project_catalog.json`. Copy an entry and give it a unique `id`; include its title, category, description, project brief, tools, outcomes, and tags. For a preview, use a filename such as `assets/images/projects/kinetic-type-promo.webp`, then set that entry's `imagePath` to the exact path. Recommended preview size is 1200 x 800. The Home screen shows a horizontal sample strip, and **Projects & Portfolio** (open from Home or Game Lab) shows full project cards and details. Until an image is added, the app displays clearly labelled generated sample artwork.

## Registering assets in Flutter

The asset directories are declared in the root `pubspec.yaml`. After adding a file, keep its path inside a registered directory and run `flutter pub get` (or restart the Flutter app so its asset bundle is rebuilt). If you introduce a brand-new directory, add it under `flutter: assets:` in `pubspec.yaml`. Keep catalogue paths and file names in sync; Flutter asset paths are case-sensitive on some build targets.

## 3D viewer support in this project

The installed `model_viewer_plus` viewer renders glTF and GLB models on Android, iOS, and web, and supports model animation clips. The app's current interactive import flow deliberately accepts self-contained `.glb` files only, up to 20 MB, so textures travel with the model. `.gltf` often depends on sidecar `.bin` and texture files and is not accepted by that importer. USDZ is an iOS viewer capability, not part of the app's current catalogue/import workflow. A model with missing external textures or malformed data may fail in the viewer; export and validate a packed GLB from your 3D tool before registering it.

No course banners, project images, challenge thumbnails, gallery previews, or 3D model files are included yet. The screens use labelled fallbacks until you add real files.
