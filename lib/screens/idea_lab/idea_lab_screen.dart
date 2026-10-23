import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/transitions.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../models/idea_lab_idea.dart';
import '../../models/idea_music_track.dart';
import '../../services/idea_bookmark_store.dart';
import '../../services/idea_lab_backend.dart';
import '../../services/idea_lab_repository.dart';
import '../../services/idea_lab_social_service.dart';
import '../../services/idea_local_video_controller.dart';
import '../../services/idea_video_compressor.dart';
import '../../services/video_frame_picker.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/idea_community_video_preview.dart';
import '../../widgets/idea_lab_artwork.dart';
import '../../widgets/idea_lab_card.dart';
import '../../widgets/idea_post_media_player.dart';
import 'idea_detail_screen.dart';
import 'idea_reels_screen.dart';
import 'idea_story_viewer.dart';
import 'idea_music_library_screen.dart';
import '../profile/idea_social_screens.dart';

class IdeaLabScreen extends StatefulWidget {
  const IdeaLabScreen({super.key});

  @override
  State<IdeaLabScreen> createState() => _IdeaLabScreenState();
}

class _IdeaLabScreenState extends State<IdeaLabScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  String _category = 'All Ideas';
  bool _savedOnly = false;
  Set<String> _savedIds = {};
  bool _bookmarksLoaded = false;
  String? _bookmarkError;
  final Set<String> _savingIds = {};
  final _postService = IdeaLabPostService();
  final _socialService = IdeaLabSocialService();
  final _storyService = IdeaLabStoryService();
  final List<IdeaLabPost> _communityPosts = [];
  List<IdeaLabStory> _stories = [];
  bool _storiesLoading = false;
  String? _storiesError;
  bool _postsLoading = false;
  bool _postsHaveMore = true;
  int _postsOffset = 0;
  String? _postsError;
  Set<String> _savedPostIds = {};

  Future<void> _showCreatePost() async {
    final caption = TextEditingController();
    final tags = TextEditingController();
    final email = TextEditingController();
    final password = TextEditingController();
    var category = IdeaLabRepository.categories[1];
    final selected = <XFile>[];
    XFile? selectedVideo;
    final videoCovers = <XFile, XFile>{};
    List<Uint8List> videoFrames = const [];
    int? selectedCoverFrame;
    int? selectedVideoDurationSeconds;
    double? selectedVideoAspectRatio;
    String? selectedVideoBadge;
    IdeaMusicSelection? selectedMusic;
    var audience = 'public';
    var commentsAccess = 'everyone';
    var hideLikeCount = false;
    var allowAudioUse = true;
    var allowSaving = true;
    final altText = TextEditingController();
    final location = TextEditingController();
    final previews = <XFile, Uint8List>{};
    var busy = false;
    var cancelRequested = false;
    var uploaded = 0;
    var videoBytesSent = 0;
    var videoBytesTotal = 0;
    var previewBytes = 0;
    String? dialogError;
    String? readinessError;
    var checkingReadiness = false;
    var backendReady = false;
    var published = false;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            IdeaLabBackend.currentUser == null
                ? 'Creator account'
                : 'Create a post',
          ),
          content: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 560,
              maxHeight: MediaQuery.sizeOf(dialogContext).height * 0.7,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (IdeaLabBackend.isConfigured &&
                      IdeaLabBackend.currentUser != null &&
                      !checkingReadiness &&
                      !backendReady &&
                      readinessError == null) ...[
                    Builder(
                      builder: (context) {
                        checkingReadiness = true;
                        Future.microtask(() async {
                          try {
                            await _postService.checkPublishingReady();
                            if (dialogContext.mounted) {
                              setDialogState(() {
                                backendReady = true;
                                checkingReadiness = false;
                              });
                            }
                          } catch (error) {
                            if (dialogContext.mounted) {
                              setDialogState(() {
                                readinessError = _readableError(error);
                                checkingReadiness = false;
                              });
                            }
                          }
                        });
                        return const SizedBox.shrink();
                      },
                    ),
                  ],
                  if (!IdeaLabBackend.isConfigured)
                    Text(IdeaLabBackend.configurationMessage)
                  else if (IdeaLabBackend.currentUser == null) ...[
                    const Text(
                      'Sign in or create a creator account to publish.',
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'Email'),
                    ),
                    TextField(
                      controller: password,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'Password'),
                    ),
                    if (dialogError != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        dialogError!,
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: busy
                                ? null
                                : () async {
                                    setDialogState(() {
                                      busy = true;
                                      dialogError = null;
                                    });
                                    try {
                                      await IdeaLabBackend.client.auth
                                          .signInWithPassword(
                                            email: email.text.trim(),
                                            password: password.text,
                                          );
                                      _savedPostIds = await _postService
                                          .fetchSavedIds();
                                      await _loadCommunityPosts(reset: true);
                                      await _loadStories();
                                      setDialogState(() {});
                                    } catch (error) {
                                      setDialogState(
                                        () =>
                                            dialogError = _readableError(error),
                                      );
                                    } finally {
                                      setDialogState(() => busy = false);
                                    }
                                  },
                            child: const Text('Sign in'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton(
                            onPressed: busy
                                ? null
                                : () async {
                                    setDialogState(() {
                                      busy = true;
                                      dialogError = null;
                                    });
                                    try {
                                      final response = await IdeaLabBackend
                                          .client
                                          .auth
                                          .signUp(
                                            email: email.text.trim(),
                                            password: password.text,
                                          );
                                      if (response.session == null) {
                                        dialogError =
                                            'Check your email to confirm your account, then sign in.';
                                      } else {
                                        _savedPostIds = await _postService
                                            .fetchSavedIds();
                                        await _loadCommunityPosts(reset: true);
                                        await _loadStories();
                                      }
                                      setDialogState(() {});
                                    } catch (error) {
                                      setDialogState(
                                        () =>
                                            dialogError = _readableError(error),
                                      );
                                    } finally {
                                      setDialogState(() => busy = false);
                                    }
                                  },
                            child: const Text('Create account'),
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    if (checkingReadiness)
                      const Text(
                        'Checking Idea Lab database, storage, and media validator setup…',
                      ),
                    if (readinessError != null)
                      Text(
                        'Publishing setup required: $readinessError',
                        style: const TextStyle(color: Colors.orangeAccent),
                      ),
                    if (readinessError != null)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: () => setDialogState(() {
                            readinessError = null;
                            checkingReadiness = false;
                          }),
                          child: const Text('Check setup again'),
                        ),
                      ),
                    const Text(
                      'Add multiple photos or one MP4 video. Photos and video are detected automatically.',
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () async {
                        // Open the browser file chooser immediately from this
                        // tap, before any async work or dialog is shown.
                        final result = await ImagePicker().pickMultipleMedia();
                        if (result.isEmpty) return;
                        final videos = result.where((file) {
                          final ext = file.name.split('.').last.toLowerCase();
                          return ext == 'mp4';
                        }).toList();
                        final imageFiles = result.where((file) {
                          final ext = file.name.split('.').last.toLowerCase();
                          return const {'jpg', 'jpeg', 'png', 'webp'}
                              .contains(ext);
                        }).toList();
                        if (videos.isNotEmpty) {
                          if (videos.length != 1 || result.length != 1) {
                            setDialogState(() => dialogError =
                                'Choose one MP4 video by itself, or choose photos only.');
                            return;
                          }
                          var video = videos.single;
                          var size = await video.length();
                          if (!kIsWeb &&
                              (defaultTargetPlatform == TargetPlatform.android ||
                                  defaultTargetPlatform == TargetPlatform.iOS) &&
                              size > 25000000) {
                            try {
                              final candidate = await compressIdeaVideo(video);
                              if (candidate != null) {
                                final compressedSize = await candidate.length();
                                if (compressedSize > 0 && compressedSize < size) {
                                  video = candidate;
                                  size = compressedSize;
                                }
                              }
                            } catch (error) {
                               if (kDebugMode) {
                                 debugPrint('[UPLOAD] mobile_compression.failed');
                               }
                            }
                          }
                          if (size <= 0 ||
                              size > IdeaLabPostService.maxVideoBytes) {
                            final actualMb = (size / 1000000).toStringAsFixed(1);
                            setDialogState(() => dialogError =
                                'This video is $actualMb MB. The maximum is 50 MB. Please trim or compress it. ${kIsWeb ? 'Video compression is not available in the browser.' : (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS) ? 'Mobile compression could not reduce it enough.' : 'Compression is not available on this device.'}');
                            return;
                          }
                          setDialogState(() {
                            dialogError = null;
                            selectedVideoDurationSeconds = null;
                            selectedVideoAspectRatio = null;
                            selectedVideoBadge = null;
                            videoFrames = const [];
                            selectedCoverFrame = null;
                            selected.clear();
                            previews.clear();
                            previewBytes = 0;
                          });
                          Duration? decodedDuration;
                          double? aspectRatio;
                          List<Uint8List> frames = const [];
                          final controller = localVideoController(video);
                          try {
                            await controller.initialize();
                            decodedDuration = controller.value.duration;
                            final dimensions = controller.value.size;
                            if (dimensions.width > 0 && dimensions.height > 0) {
                              aspectRatio = dimensions.width / dimensions.height;
                            }
                            if (decodedDuration > const Duration(minutes: 2)) {
                              setDialogState(() => dialogError =
                                  'Videos can be up to 2 minutes long. Trim this video and try again.');
                              return;
                            }
                            if (aspectRatio == null ||
                                aspectRatio < 0.5 || aspectRatio > 2.4) {
                              setDialogState(() => dialogError =
                                  'Video dimensions must have an aspect ratio from 1:2 to 2.4:1.');
                              return;
                            }
                            frames = await generateVideoFrameCovers(
                              video,
                              decodedDuration,
                            );
                          } catch (_) {
                            setDialogState(() => dialogError =
                                'This browser could not decode the video. Please export it as H.264 MP4 and try again.');
                            return;
                          } finally {
                            await controller.dispose();
                          }
                          setDialogState(() {
                            selectedVideo = video;
                            videoCovers.clear();
                            videoFrames = frames;
                            selectedCoverFrame = null;
                            if (frames.isNotEmpty) {
                              videoCovers[video] = XFile.fromData(
                                frames.first,
                                name: 'video-cover-0.jpg',
                                mimeType: 'image/jpeg',
                              );
                              selectedCoverFrame = 0;
                            }
                            selectedVideoDurationSeconds =
                                decodedDuration?.inSeconds;
                            selectedVideoAspectRatio = aspectRatio;
                            selectedVideoBadge = aspectRatio! < 0.8
                                ? 'Reel 9:16'
                                : aspectRatio > 1.2
                                    ? 'Video 16:9'
                                    : 'Square';
                            dialogError = null;
                          });
                          return;
                        }
                        final resultImages = imageFiles;
                        final valid = <XFile>[];
                        final validBytes = <XFile, Uint8List>{};
                        var totalBytes = 0;
                        String? selectionError;
                        if (resultImages.length >
                            IdeaLabPostService.maxPostMediaItems) {
                          selectionError =
                              'Choose up to ${IdeaLabPostService.maxPostMediaItems} photos in one post.';
                        }
                        for (final file in resultImages) {
                          if (valid.length >=
                              IdeaLabPostService.maxPostMediaItems) {
                            selectionError =
                                'Choose up to ${IdeaLabPostService.maxPostMediaItems} photos in one post.';
                            break;
                          }
                          final extension = file.name
                              .split('.')
                              .last
                              .toLowerCase();
                          if (const {
                                'jpg',
                                'jpeg',
                                'png',
                                'webp',
                              }.contains(extension)) {
                            final size = await file.length();
                            if (size <= 0) {
                              selectionError = 'This image is empty. Choose another image.';
                              continue;
                            }
                            if (size > IdeaLabPostService.maxImageBytes) {
                              selectionError =
                                  'This image is ${(size / 1000000).toStringAsFixed(1)} MB. The maximum is 20 MB. Please resize or compress it.';
                              continue;
                            }
                            if (totalBytes + size >
                                IdeaLabPostService.maxPostBytes) {
                              selectionError =
                                  'These photos total more than 100 MB. Remove or compress some images.';
                              continue;
                            }
                            final bytes = await file.readAsBytes();
                            if (bytes.isNotEmpty &&
                              bytes.length <=
                                  IdeaLabPostService.maxImageBytes &&
                              totalBytes + bytes.length <=
                                  IdeaLabPostService.maxPostBytes) {
                            valid.add(file);
                            validBytes[file] = bytes;
                            totalBytes += bytes.length;
                            }
                          }
                        }
                        setDialogState(() {
                          selectedVideo = null;
                          videoCovers.clear();
                          videoFrames = const [];
                          selected
                            ..clear()
                            ..addAll(valid);
                          previews
                            ..clear()
                            ..addAll(validBytes);
                          previewBytes = totalBytes;
                          dialogError = selectionError ??
                              (result.length > valid.length
                                  ? 'One or more files are not supported. Choose JPG, JPEG, PNG, WebP, or one MP4 video.'
                                  : null);
                        });
                      },
                      icon: const Icon(Icons.add_photo_alternate_outlined),
                      label: Text(
                        selectedVideo != null
                            ? 'Replace video'
                            : selected.isEmpty
                                ? 'Add photos or videos'
                                : 'Add photos or videos (${selected.length}, ${(previewBytes / (1024 * 1024)).toStringAsFixed(1)} MiB)',
                      ),
                    ),
                    if (selectedVideo != null) ...[
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final cover = await ImagePicker().pickImage(
                            source: ImageSource.gallery,
                          );
                          if (cover == null) return;
                          setDialogState(() {
                            videoCovers[selectedVideo!] = cover;
                            dialogError = null;
                          });
                        },
                        icon: const Icon(Icons.photo_library_outlined),
                        label: Text(videoCovers[selectedVideo] == null
                            ? 'Upload custom cover'
                            : 'Replace custom cover'),
                      ),
                      if (videoFrames.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text('Edit cover · choose a video frame',
                            style: AppText.caption),
                        SizedBox(
                          height: 78,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: videoFrames.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 8),
                            itemBuilder: (context, index) => InkWell(
                              onTap: () {
                                final cover = XFile.fromData(
                                  videoFrames[index],
                                  name: 'video-cover-$index.jpg',
                                  mimeType: 'image/jpeg',
                                );
                                setDialogState(() {
                                  selectedCoverFrame = index;
                                  videoCovers[selectedVideo!] = cover;
                                  dialogError = null;
                                });
                              },
                              child: Container(
                                width: 58,
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: selectedCoverFrame == index
                                        ? AppColors.sky
                                        : Colors.white24,
                                    width: selectedCoverFrame == index ? 2 : 1,
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(5),
                                  child: Image.memory(
                                    videoFrames[index],
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                      if (selectedVideoBadge != null)
                        Text(
                          '${selectedVideoBadge!} · ${selectedVideoDurationSeconds ?? 0}s · ${selectedVideoAspectRatio!.toStringAsFixed(2)}:1',
                          style: AppText.caption,
                        ),
                      if (selectedVideoDurationSeconds != null)
                        Text('Video · ${selectedVideoDurationSeconds}s',
                            style: AppText.caption),
                      if (selectedVideoDurationSeconds == null)
                        const Text(
                          'Video duration could not be read in this browser. Upload a custom cover; the server will validate the video format and duration.',
                          style: TextStyle(color: Colors.orangeAccent),
                        ),
                    ],
                    if (selected.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 90,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              for (final file in selected)
                                Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: Column(
                                    children: [
                                      SizedBox(
                                        width: 60,
                                        height: 60,
                                        child: Image.memory(
                                          previews[file]!,
                                          fit: BoxFit.contain,
                                        ),
                                      ),
                                      SizedBox(
                                        width: 72,
                                        child: Text(
                                          file.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextField(
                      controller: caption,
                      maxLines: 3,
                      onChanged: (_) => setDialogState(() {}),
                      decoration: const InputDecoration(labelText: 'Caption'),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: category,
                      decoration: const InputDecoration(labelText: 'Category'),
                      items: IdeaLabRepository.categories
                          .skip(1)
                          .map(
                            (item) => DropdownMenuItem(
                              value: item,
                              child: Text(item),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => category = value);
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: tags,
                      decoration: const InputDecoration(
                        labelText: 'Tags (optional, comma separated)',
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final track = await Navigator.of(dialogContext)
                            .push<IdeaMusicTrack>(
                              MaterialPageRoute(
                                builder: (_) => const IdeaMusicLibraryScreen(),
                              ),
                            );
                        if (track != null && dialogContext.mounted) {
                          setDialogState(() {
                            selectedMusic = IdeaMusicSelection(
                              track: track,
                              start: Duration.zero,
                              end: track.duration,
                            );
                          });
                        }
                      },
                      icon: const Icon(Icons.music_note_rounded),
                      label: Text(selectedMusic == null
                          ? 'Add music'
                          : '${selectedMusic!.track.title} · ${selectedMusic!.track.creator}'),
                    ),
                    if (selectedMusic != null) ...[
                      Row(
                        children: [
                          if (selectedMusic!.track.artworkUrl != null)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Image.network(
                                selectedMusic!.track.artworkUrl!,
                                width: 40,
                                height: 40,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Icon(
                                  Icons.music_note_rounded,
                                  color: AppColors.sky,
                                ),
                              ),
                            ),
                          const SizedBox(width: 8),
                          Expanded(child: Text(selectedMusic!.track.title)),
                          IconButton(
                            tooltip: 'Remove music',
                            onPressed: () =>
                                setDialogState(() => selectedMusic = null),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          const Text('Music volume'),
                          Expanded(
                            child: Slider(
                              value: selectedMusic!.volume,
                              onChanged: (volume) => setDialogState(() {
                                selectedMusic = IdeaMusicSelection(
                                  track: selectedMusic!.track,
                                  start: selectedMusic!.start,
                                  end: selectedMusic!.end,
                                  volume: volume,
                                );
                              }),
                            ),
                          ),
                        ],
                      ),
                    ],
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: const Text('Advanced settings'),
                      children: [
                        DropdownButtonFormField<String>(
                          initialValue: audience,
                          decoration: const InputDecoration(labelText: 'Audience'),
                          items: const [
                            DropdownMenuItem(value: 'public', child: Text('Public')),
                            DropdownMenuItem(value: 'followers', child: Text('Followers only')),
                          ],
                          onChanged: (value) => setDialogState(() => audience = value ?? 'public'),
                        ),
                        DropdownButtonFormField<String>(
                          initialValue: commentsAccess,
                          decoration: const InputDecoration(labelText: 'Comments'),
                          items: const [
                            DropdownMenuItem(value: 'everyone', child: Text('Everyone')),
                            DropdownMenuItem(value: 'followers', child: Text('Followers')),
                            DropdownMenuItem(value: 'off', child: Text('Off')),
                          ],
                          onChanged: (value) => setDialogState(() => commentsAccess = value ?? 'everyone'),
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Hide like count'),
                          value: hideLikeCount,
                          onChanged: (value) => setDialogState(() => hideLikeCount = value),
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Allow others to use this audio'),
                          value: allowAudioUse,
                          onChanged: (value) => setDialogState(() => allowAudioUse = value),
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Allow saving'),
                          value: allowSaving,
                          onChanged: (value) => setDialogState(() => allowSaving = value),
                        ),
                        TextField(
                          controller: altText,
                          maxLength: 500,
                          decoration: const InputDecoration(labelText: 'Alt text'),
                        ),
                        TextField(
                          controller: location,
                          maxLength: 120,
                          decoration: const InputDecoration(labelText: 'Location (optional)'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (dialogError != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        dialogError!,
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    ],
                    if (busy) ...[
                      const SizedBox(height: 12),
                      LinearProgressIndicator(
                        value: selectedVideo != null && videoBytesTotal > 0
                            ? (videoBytesSent / videoBytesTotal).clamp(0.0, 1.0)
                            : selected.isEmpty && selectedVideo == null
                                ? null
                                : uploaded /
                                  (selected.length +
                                      (selectedVideo == null
                                          ? 0
                                          : 1 +
                                                (videoCovers.containsKey(
                                                      selectedVideo,
                                                    )
                                                    ? 1
                                                    : 0))),
                      ),
                      const SizedBox(height: 5),
                      Text(selectedVideo != null && videoBytesTotal > 0
                          ? 'Video upload ${(videoBytesSent / 1000000).toStringAsFixed(1)} MB / ${(videoBytesTotal / 1000000).toStringAsFixed(1)} MB · Uploaded $uploaded media items'
                          : 'Uploaded $uploaded media items'),
                    ],
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                cancelRequested = true;
                Navigator.pop(dialogContext);
              },
              child: const Text('Cancel'),
            ),
            if (IdeaLabBackend.currentUser != null &&
                IdeaLabBackend.isConfigured)
              FilledButton(
                onPressed:
                    busy ||
                        !backendReady ||
                        (selected.isEmpty && selectedVideo == null) ||
                        (selectedVideo != null &&
                            videoCovers[selectedVideo] == null) ||
                        caption.text.trim().isEmpty
                    ? null
                    : () async {
                        setDialogState(() {
                          busy = true;
                          uploaded = 0;
                          videoBytesSent = 0;
                          videoBytesTotal = 0;
                          dialogError = null;
                        });
                        try {
                          final filesToPublish = [
                            ...selected,
                            if (selectedVideo != null) selectedVideo!,
                          ];
                          videoBytesTotal = selectedVideo == null
                              ? 0
                              : await selectedVideo!.length();
                           if (kDebugMode) {
                             debugPrint('[UPLOAD] publish.selection');
                           }
                          await _postService.publishImages(
                            files: filesToPublish,
                            bytes: previews,
                            videoCovers: videoCovers,
                            caption: caption.text,
                            category: category,
                            tags: tags.text.split(','),
                            music: selectedMusic,
                            maxVideoDurationSeconds: 120,
                            videoDurationSeconds: selectedVideoDurationSeconds,
                            postSettings: {
                              'audience': audience,
                              'comments_access': commentsAccess,
                              'hide_like_count': hideLikeCount,
                              'allow_audio_use': allowAudioUse,
                              'allow_saving': allowSaving,
                              'alt_text': altText.text.trim().isEmpty
                                  ? null
                                  : altText.text.trim(),
                              'location_label': location.text.trim().isEmpty
                                  ? null
                                  : location.text.trim(),
                            },
                            isCancelled: () => cancelRequested,
                            onProgress: (done, total) {
                              if (dialogContext.mounted) {
                                setDialogState(() => uploaded = done);
                              }
                            },
                            onVideoProgress: (_, sent, total) {
                              if (dialogContext.mounted) {
                                  setDialogState(() {
                                    videoBytesSent = sent;
                                    videoBytesTotal = total;
                                  });
                              }
                            },
                          );
                          published = true;
                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext);
                          }
                        } catch (error) {
                          if (!cancelRequested && dialogContext.mounted) {
                            setDialogState(
                              () => dialogError = _readableError(error),
                            );
                          }
                        } finally {
                          if (dialogContext.mounted) {
                            setDialogState(() => busy = false);
                          }
                        }
                      },
                child: Text(
                  busy ? 'Uploading…' : dialogError != null ? 'Retry' : 'Publish',
                ),
              ),
          ],
        ),
      ),
    );
    if (published && mounted) {
      await _loadCommunityPosts(reset: true);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Your post is published.')));
    }
  }

  String _readableError(Object error) {
    final message = error.toString().replaceFirst('Exception: ', '');
    final lower = message.toLowerCase();
    if (lower.contains('post media metadata must be staged')) {
      return 'The media verifier rejected the upload before it could read the staged media details. The uploaded files were cleaned up. Refresh the app and retry; if it continues, the deployed validate-idea-media function needs updating.';
    }
    if (lower.contains('functionsexception') ||
        lower.contains('functionshttpexception')) {
      return 'The server could not verify this media upload. Uploaded files were cleaned up. Check your connection and retry; if it continues, compare the deployed validate-idea-media function with the project source.';
    }
    if (lower.contains('storageexception')) {
      if (lower.contains('413') || lower.contains('payload too large')) {
        return 'Storage rejected this file because it exceeds the upload limit. Videos must be 50 MB or smaller; images must be 20 MB or smaller.';
      }
      if (lower.contains('403') || lower.contains('row-level security')) {
        return 'Storage denied this upload. Your files were cleaned up. Check that you are signed in and that the current storage upload policy is installed.';
      }
      return 'Storage could not upload the selected media. Any uploaded files were cleaned up. Check your connection and retry.';
    }
    if (lower.contains('postgresexception')) {
      if (lower.contains('42501') || lower.contains('row-level security')) {
        return 'The database denied saving this post. Uploaded files were cleaned up. Check the post privacy policies and that your session is still valid.';
      }
      return 'The database could not save this post. Uploaded files were cleaned up. Please retry; if it continues, check the database error in the app log.';
    }
    return message;
  }

  @override
  void initState() {
    super.initState();
    _loadBookmarks();
    _loadCommunityPosts(reset: true);
    _loadStories();
  }

  Future<void> _loadCommunityPosts({bool reset = false}) async {
    if (!IdeaLabBackend.isConfigured) return;
    if (_postsLoading) return;
    setState(() {
      _postsLoading = true;
      if (reset) {
        _postsOffset = 0;
        _postsHaveMore = true;
        _postsError = null;
      }
    });
    try {
      final page = await _postService.fetchPage(offset: _postsOffset);
      if (!mounted) return;
      setState(() {
        if (reset) _communityPosts.clear();
        _communityPosts.addAll(page);
        _postsOffset = _communityPosts.length;
        _postsHaveMore = page.length == IdeaLabPostService.pageSize;
        _postsError = null;
      });
    } catch (error) {
      if (mounted) setState(() => _postsError = _readableError(error));
    } finally {
      if (mounted) setState(() => _postsLoading = false);
    }
  }

  Future<void> _loadStories() async {
    if (!IdeaLabBackend.isConfigured || _storiesLoading) return;
    setState(() {
      _storiesLoading = true;
      _storiesError = null;
    });
    try {
      final stories = await _storyService.fetchActive();
      if (mounted) setState(() => _stories = stories);
    } catch (error) {
      if (mounted) setState(() => _storiesError = _readableError(error));
    } finally {
      if (mounted) setState(() => _storiesLoading = false);
    }
  }

  Future<void> _createStory() async {
    if (IdeaLabBackend.currentUser == null) {
      await _showCreatePost();
      if (!mounted || IdeaLabBackend.currentUser == null) return;
    }
    final isVideo = await showModalBottomSheet<bool>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_outlined),
              title: const Text('Photo story'),
              onTap: () => Navigator.pop(context, false),
            ),
            ListTile(
              leading: const Icon(Icons.video_library_outlined),
              title: const Text('Short video story (MP4, up to 30 seconds)'),
              onTap: () => Navigator.pop(context, true),
            ),
          ],
        ),
      ),
    );
    if (isVideo == null || !mounted) return;
    try {
      final file = isVideo
          ? await ImagePicker().pickVideo(
              source: ImageSource.gallery,
              maxDuration: const Duration(seconds: 30),
            )
          : await ImagePicker().pickImage(source: ImageSource.gallery);
      if (file == null) return;
      await _storyService.publish(file);
      await _loadStories();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your story is live for 24 hours.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Story upload failed: ${_readableError(error)}'),
        ),
      );
    }
  }

  void _openStory(int index) {
    final stories = List<IdeaLabStory>.from(_stories);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog.fullscreen(
        child: IdeaStoryViewer(
          stories: stories,
          initialIndex: index,
          resolveUrl: _storyService.signedUrl,
          onViewed: (story) {
            _storyService
                .markViewed(story.id)
                .then((_) {
                  if (mounted) {
                    setState(() {
                      _stories = [
                        for (final item in _stories)
                          if (item.id == story.id)
                            IdeaLabStory(
                              id: item.id,
                              creatorId: item.creatorId,
                              creator: item.creator,
                              avatarUrl: item.avatarUrl,
                              createdAt: item.createdAt,
                              url: item.url,
                              storagePath: item.storagePath,
                              mimeType: item.mimeType,
                              expiresAt: item.expiresAt,
                              seen: true,
                            )
                          else
                            item,
                      ];
                    });
                  }
                })
                .catchError((_) {});
          },
          onDelete: (story) async {
            try {
              await _storyService.delete(story);
              if (mounted) {
                setState(
                  () => _stories.removeWhere((item) => item.id == story.id),
                );
              }
            } catch (error) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Could not delete story: ${_readableError(error)}',
                    ),
                  ),
                );
              }
            }
          },
        ),
      ),
    );
  }

  List<IdeaLabPost> get _filteredCommunityPosts => _communityPosts.where((
    post,
  ) {
    final categoryMatches =
        _category == 'All Ideas' ||
        post.category == _category ||
        (_category == 'Beginner Tutorials' &&
            post.tags.any((tag) => tag.toLowerCase() == 'beginner tutorials'));
    final query = _query.trim().toLowerCase();
    final searchMatches =
        query.isEmpty ||
        post.caption.toLowerCase().contains(query) ||
        post.category.toLowerCase().contains(query) ||
        post.tags.any((tag) => tag.toLowerCase().contains(query)) ||
        post.creator.toLowerCase().contains(query);
    return categoryMatches &&
        searchMatches &&
        (!_savedOnly || _savedPostIds.contains(post.id));
  }).toList();

  Future<void> _togglePostSaved(IdeaLabPost post) async {
    try {
      final saved = await _postService.toggleSaved(post.id, _savedPostIds);
      if (mounted) setState(() => _savedPostIds = saved);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_readableError(error))));
      }
    }
  }

  Future<void> _deleteCommunityPost(IdeaLabPost post) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete post?'),
        content: const Text('This removes the post and its uploaded media.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _postService.deletePost(post);
      if (mounted) {
        setState(
          () => _communityPosts.removeWhere((item) => item.id == post.id),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not delete post: ${_readableError(error)}'),
          ),
        );
      }
    }
  }

  Future<void> _showCommunityPostMenu(IdeaLabPost post) async {
    final isOwn = post.creatorId == IdeaLabBackend.currentUser?.id;
    final action = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 520),
      backgroundColor: AppColors.navyDeep,
      builder: (sheetContext) => SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => ConstrainedBox(
            constraints: BoxConstraints(maxHeight: constraints.maxHeight),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                  child: Row(
                    children: [
                      Expanded(child: Text(post.creator, style: AppText.h3)),
                      Text(
                        post.media.any((m) => m.mimeType == 'video/mp4')
                            ? 'VIDEO'
                            : 'POST',
                        style: AppText.label,
                      ),
                    ],
                  ),
                ),
                Flexible(
                  fit: FlexFit.loose,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isOwn) ...[
                          _PostMenuTile(
                            icon: Icons.edit_outlined,
                            label: 'Edit Post',
                            onTap: () => Navigator.pop(sheetContext, 'edit'),
                          ),
                          _PostMenuTile(
                            icon: Icons.delete_outline,
                            label: 'Delete Post',
                            isDestructive: true,
                            onTap: () => Navigator.pop(sheetContext, 'delete'),
                          ),
                          _PostMenuTile(
                            icon: post.hideLikeCount
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            label: post.hideLikeCount
                                ? 'Show Like Count'
                                : 'Hide Like Count',
                            onTap: () => Navigator.pop(sheetContext, 'likes'),
                          ),
                          _PostMenuTile(
                            icon: Icons.mode_comment_outlined,
                            label: post.commentsAccess == 'off'
                                ? 'Turn On Comments'
                                : 'Turn Off Comments',
                            onTap: () => Navigator.pop(sheetContext, 'comments'),
                          ),
                        ] else
                          _PostMenuTile(
                            icon: Icons.flag_outlined,
                            label: 'Report Post',
                            onTap: () => Navigator.pop(sheetContext, 'report'),
                          ),
                        _PostMenuTile(
                          icon: Icons.open_in_new_rounded,
                          label: 'View Post',
                          onTap: () => Navigator.pop(sheetContext, 'view'),
                        ),
                        _PostMenuTile(
                          icon: Icons.share_outlined,
                          label: 'Share Post',
                          onTap: () => Navigator.pop(sheetContext, 'share'),
                        ),
                        _PostMenuTile(
                          icon: Icons.link_rounded,
                          label: 'Copy Link',
                          onTap: () => Navigator.pop(sheetContext, 'copy'),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'edit':
        await _editCommunityPost(post);
      case 'delete':
        await _deleteCommunityPost(post);
      case 'likes':
        await _updateCommunityPost(post, hideLikeCount: !post.hideLikeCount);
      case 'comments':
        await _updateCommunityPost(
          post,
          commentsAccess: post.commentsAccess == 'off' ? 'everyone' : 'off',
        );
      case 'view':
        if (post.media.any((m) => m.mimeType == 'video/mp4')) {
          await Navigator.of(context).push<void>(
            MaterialPageRoute<void>(
              builder: (_) => IdeaReelsScreen(
                posts: [post],
                initialPostId: post.id,
              ),
            ),
          );
        } else {
          _openCommunityPost(post);
        }
      case 'share':
        await _shareCommunityPost(post);
      case 'copy':
        _showCopyLinkUnavailable();
      case 'report':
        await _reportCommunityPost(post);
    }
  }

  Future<void> _updateCommunityPost(
    IdeaLabPost post, {
    bool? hideLikeCount,
    String? commentsAccess,
  }) async {
    try {
      await _postService.updatePostOwnerFields(
        postId: post.id,
        caption: post.caption,
        category: post.category,
        tags: post.tags,
        hideLikeCount: hideLikeCount ?? post.hideLikeCount,
        commentsAccess: commentsAccess ?? post.commentsAccess,
      );
      await _loadCommunityPosts(reset: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post settings updated.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update post: ${_readableError(error)}')),
        );
      }
    }
  }

  Future<void> _editCommunityPost(IdeaLabPost post) async {
    final caption = TextEditingController(text: post.caption);
    final tags = TextEditingController(text: post.tags.join(', '));
    final video = post.media.where((m) => m.mimeType == 'video/mp4').firstOrNull;
    XFile? replacementCover;
    Uint8List? replacementCoverBytes;
    String? errorText;
    var saving = false;
    try {
      final categoryRows = await IdeaLabBackend.client
          .from('idea_categories')
          .select('id,name')
          .order('name');
      if (!mounted) return;
      final categories = categoryRows
          .map((row) => row['name'] as String)
          .toList(growable: false);
      var category = categories.contains(post.category)
          ? post.category
          : (categories.isEmpty ? '' : categories.first);
      final result = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Edit Post'),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: caption,
                      minLines: 2,
                      maxLines: 5,
                      maxLength: 2200,
                      decoration: const InputDecoration(labelText: 'Caption'),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: category.isEmpty ? null : category,
                      decoration: const InputDecoration(labelText: 'Category'),
                      items: categories
                          .map((name) => DropdownMenuItem(
                                value: name,
                                child: Text(name),
                              ))
                          .toList(),
                      onChanged: (value) {
                        if (value != null) setDialogState(() => category = value);
                      },
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: tags,
                      decoration: const InputDecoration(
                        labelText: 'Tags (comma separated, up to 10)',
                      ),
                    ),
                    if (video != null) ...[
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final cover = await ImagePicker().pickImage(
                            source: ImageSource.gallery,
                          );
                          if (cover == null) return;
                          final extension = cover.name.split('.').last.toLowerCase();
                          final bytes = await cover.readAsBytes();
                          if (!const {'jpg', 'jpeg', 'png', 'webp'}.contains(extension) ||
                              bytes.isEmpty || bytes.length > 2 * 1024 * 1024) {
                            setDialogState(() => errorText =
                                'Choose a JPG, PNG, or WebP cover no larger than 2 MiB.');
                            return;
                          }
                          setDialogState(() {
                            replacementCover = cover;
                            replacementCoverBytes = bytes;
                            errorText = null;
                          });
                        },
                        icon: const Icon(Icons.photo_library_outlined),
                        label: Text(replacementCover == null
                            ? 'Replace video cover'
                            : 'Choose a different cover'),
                      ),
                      if (replacementCoverBytes != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.memory(
                            replacementCoverBytes!,
                            height: 120,
                            fit: BoxFit.contain,
                          ),
                        ),
                    ],
                    if (errorText != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(errorText!,
                            style: const TextStyle(color: Colors.redAccent)),
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: saving || categories.isEmpty
                    ? null
                    : () async {
                        final cleanTags = tags.text
                            .split(',')
                            .map((tag) => tag.trim())
                            .where((tag) => tag.isNotEmpty)
                            .toSet()
                            .toList();
                        if (caption.text.trim().isEmpty ||
                            caption.text.trim().length > 2200 ||
                            cleanTags.length > 10 ||
                            cleanTags.any((tag) => tag.length > 40)) {
                          setDialogState(() => errorText =
                              'Add a caption (max 2200 characters) and up to 10 tags (max 40 characters each).');
                          return;
                        }
                        setDialogState(() => saving = true);
                        try {
                          await _postService.updatePostOwnerFields(
                            postId: post.id,
                            caption: caption.text,
                            category: category,
                            tags: cleanTags,
                            hideLikeCount: post.hideLikeCount,
                            commentsAccess: post.commentsAccess,
                          );
                          String? coverFailure;
                          if (replacementCover != null && replacementCoverBytes != null && video != null) {
                            try {
                              await _postService.replaceVideoThumbnail(
                                post: post,
                                media: video,
                                cover: replacementCover!,
                                bytes: replacementCoverBytes!,
                              );
                            } catch (error) {
                              coverFailure = _readableError(error);
                            }
                          }
                          await _loadCommunityPosts(reset: true);
                          if (!dialogContext.mounted) return;
                          Navigator.pop(dialogContext, true);
                          if (coverFailure != null && mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Post text was saved, but the cover was not changed: $coverFailure')),
                            );
                          }
                        } catch (error) {
                          setDialogState(() {
                            saving = false;
                            errorText = _readableError(error);
                          });
                        }
                      },
                child: saving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save'),
              ),
            ],
          ),
        ),
      );
      if (result == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post updated.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load edit options: ${_readableError(error)}')),
        );
      }
    } finally {
      caption.dispose();
      tags.dispose();
    }
  }

  Future<void> _shareCommunityPost(IdeaLabPost post) async {
    final mediaUrl = post.media.isEmpty ? '' : post.media.first.url;
    try {
      await SharePlus.instance.share(
        ShareParams(
          text: [post.caption, mediaUrl].where((value) => value.isNotEmpty).join('\n\n'),
          title: 'AM Motion Lab · ${post.creator}',
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not share post: ${_readableError(error)}')),
        );
      }
    }
  }

  void _showCopyLinkUnavailable() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Post links are not configured yet. Share Post can send a temporary media link.'),
      ),
    );
  }

  Future<void> _reportCommunityPost(IdeaLabPost post) async {
    String reason = 'Inappropriate content';
    final details = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Report Post'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: reason,
                items: const [
                  'Inappropriate content',
                  'Spam',
                  'Copyright concern',
                ].map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(),
                onChanged: (value) {
                  if (value != null) setDialogState(() => reason = value);
                },
              ),
              TextField(
                controller: details,
                maxLength: 1000,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Details (optional)'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Submit report')),
          ],
        ),
      ),
    );
    if (confirmed != true) {
      details.dispose();
      return;
    }
    try {
      await _socialService.reportPost(post.id, reason, details.text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report submitted.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not report post: ${_readableError(error)}')),
        );
      }
    } finally {
      details.dispose();
    }
  }

  void _openCommunityPost(IdeaLabPost post) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720, maxHeight: 760),
          child: ListView(
            padding: const EdgeInsets.all(18),
            children: [
              Row(
                children: [
                  Expanded(child: Text(post.creator, style: AppText.h3)),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              for (final media in post.media)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: media.mimeType.startsWith('video/')
                      ? IdeaPostMediaPlayer(
                          media: media,
                          music: post.music,
                        )
                      : Image.network(
                          media.url,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const SizedBox(
                            height: 140,
                            child: Center(
                              child: Text('Media preview unavailable'),
                            ),
                          ),
                        ),
                ),
              Text(post.caption, style: AppText.body),
              const SizedBox(height: 8),
              Text(
                '${post.category} · ${post.tags.join(' · ')}',
                style: AppText.caption,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _loadBookmarks() async {
    try {
      final saved = await IdeaBookmarkStore.instance.savedIds;
      if (!mounted) return;
      setState(() {
        _savedIds = saved;
        _bookmarksLoaded = true;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _bookmarksLoaded = true;
        _bookmarkError = 'Saved ideas could not be loaded: $error';
      });
    }
  }

  Future<bool> _toggleSaved(IdeaLabIdea idea) async {
    if (!_savingIds.add(idea.id)) return false;
    setState(() {});
    try {
      final saved = await IdeaBookmarkStore.instance.toggle(idea.id);
      if (!mounted) return false;
      setState(() {
        _savedIds = saved;
        _bookmarkError = null;
      });
      return true;
    } catch (error) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('Could not update saved ideas: $error')),
        );
      return false;
    } finally {
      _savingIds.remove(idea.id);
      if (mounted) setState(() {});
    }
  }

  List<IdeaLabIdea> get _filteredIdeas {
    return [
      for (final idea in IdeaLabRepository.ideas)
        if (idea.matchesCategory(_category) &&
            idea.matchesSearch(_query) &&
            (!_savedOnly || _savedIds.contains(idea.id)))
          idea,
    ];
  }

  void _openIdea(IdeaLabIdea idea) {
    Navigator.of(context).push(
      AppRoutes.slideUp(
        IdeaDetailScreen(
          idea: idea,
          saved: _savedIds.contains(idea.id),
          onToggleSaved: () => _toggleSaved(idea),
          onOpenRelated: _openIdea,
        ),
      ),
    );
  }

  void _clearFilters() {
    _searchController.clear();
    setState(() {
      _query = '';
      _category = 'All Ideas';
      _savedOnly = false;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredIdeas;
    final showFeatured =
        _category == 'All Ideas' && _query.trim().isEmpty && !_savedOnly;
    final featured = IdeaLabRepository.ideas.first;
    final cards = showFeatured
        ? filtered.where((idea) => idea.id != featured.id).toList()
        : filtered;
    final communityPosts = _filteredCommunityPosts;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final horizontalPadding = width < 540
            ? 16.0
            : width < 960
            ? 26.0
            : 36.0;
        return ListView(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            26,
            horizontalPadding,
            36,
          ),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1240),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('CREATIVE INSPIRATION', style: AppText.label),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Idea Lab',
                            style: AppText.h1.copyWith(fontSize: 32),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Reels',
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => IdeaReelsScreen(
                                posts: _communityPosts,
                              ),
                            ),
                          ),
                          icon: const Icon(Icons.movie_outlined),
                        ),
                        IconButton(
                          tooltip: 'Messages',
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const IdeaMessagesScreen(),
                            ),
                          ),
                          icon: const Icon(Icons.chat_bubble_outline),
                        ),
                        Tooltip(
                          message: 'Create Post',
                          child: FilledButton.icon(
                            onPressed: _showCreatePost,
                            icon: const Icon(Icons.add_rounded),
                            label: MediaQuery.sizeOf(context).width < 520
                                ? const SizedBox.shrink()
                                : const Text('Create Post'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Discover ideas. Learn techniques. Create something original.',
                      style: AppText.body,
                    ),
                    const SizedBox(height: 20),
                    _SearchField(
                      controller: _searchController,
                      onChanged: (value) => setState(() => _query = value),
                      onClear: () {
                        _searchController.clear();
                        setState(() => _query = '');
                      },
                    ),
                    const SizedBox(height: 14),
                    _CategoryFilters(
                      selected: _category,
                      onSelected: (category) =>
                          setState(() => _category = category),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        FilterChip(
                          avatar: Icon(
                            _savedOnly
                                ? Icons.bookmark_rounded
                                : Icons.bookmark_border_rounded,
                            size: 17,
                            color: _savedOnly
                                ? AppColors.sky
                                : AppColors.inkDim,
                          ),
                          label: const Text('Saved ideas'),
                          selected: _savedOnly,
                          onSelected: (selected) =>
                              setState(() => _savedOnly = selected),
                        ),
                        TextButton.icon(
                          onPressed: _clearFilters,
                          icon: const Icon(
                            Icons.filter_alt_off_outlined,
                            size: 17,
                          ),
                          label: const Text('Reset filters'),
                        ),
                        if (_bookmarkError != null)
                          Text(
                            _bookmarkError!,
                            style: AppText.caption.copyWith(
                              color: const Color(0xFFFF9A9A),
                            ),
                          ),
                      ],
                    ),
                    if (showFeatured) ...[
                      const SizedBox(height: 17),
                      _FeaturedIdea(
                        idea: featured,
                        saved: _savedIds.contains(featured.id),
                        saving: _savingIds.contains(featured.id),
                        onOpen: () => _openIdea(featured),
                        onToggleSaved: () => _toggleSaved(featured),
                      ),
                    ],
                    if (IdeaLabBackend.isConfigured) ...[
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(child: Text('Stories', style: AppText.h2)),
                          IconButton(
                            tooltip: 'Refresh stories',
                            onPressed: _loadStories,
                            icon: const Icon(Icons.refresh_rounded),
                          ),
                        ],
                      ),
                      if (_storiesError != null)
                        TextButton.icon(
                          onPressed: _loadStories,
                          icon: const Icon(Icons.refresh_rounded),
                          label: Text(
                            'Stories failed to load. Retry: $_storiesError',
                          ),
                        )
                      else
                        SizedBox(
                          height: 112,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: _stories.length + 1,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 12),
                            itemBuilder: (context, index) {
                              if (index == 0) {
                                return _StoryBubble(
                                  label: 'Your Story',
                                  isOwn: true,
                                  onTap: _createStory,
                                );
                              }
                              final storyIndex = index - 1;
                              final story = _stories[storyIndex];
                              return _StoryBubble(
                                label:
                                    story.creatorId ==
                                        IdeaLabBackend.currentUser?.id
                                    ? 'Your Story'
                                    : story.creator,
                                story: story,
                                isOwn:
                                    story.creatorId ==
                                    IdeaLabBackend.currentUser?.id,
                                onTap: () => _openStory(storyIndex),
                              );
                            },
                          ),
                        ),
                      if (_storiesLoading && _stories.isEmpty)
                        const LinearProgressIndicator(minHeight: 2),
                    ],
                    if (IdeaLabBackend.isConfigured) ...[
                      const SizedBox(height: 25),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Community creations',
                              style: AppText.h2,
                            ),
                          ),
                          IconButton(
                            tooltip: 'Refresh community posts',
                            onPressed: () => _loadCommunityPosts(reset: true),
                            icon: const Icon(Icons.refresh_rounded),
                          ),
                        ],
                      ),
                      if (_postsError != null)
                        GlassCard(
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Posts could not be loaded: $_postsError',
                                  style: AppText.caption,
                                ),
                              ),
                              TextButton(
                                onPressed: () =>
                                    _loadCommunityPosts(reset: true),
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        )
                      else if (_postsLoading && _communityPosts.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(28),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: AppColors.sky,
                            ),
                          ),
                        )
                      else if (communityPosts.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            _savedOnly
                                ? 'No saved community posts.'
                                : 'No published community posts yet.',
                            style: AppText.caption,
                          ),
                        )
                      else
                        LayoutBuilder(
                          builder: (context, postConstraints) {
                            final available = postConstraints.maxWidth;
                            final columns = available < 360
                                ? 1
                                : available < 650
                                ? 2
                                : available < 1000
                                ? 3
                                : 4;
                            const gap = 14.0;
                            final cardWidth =
                                (available - (columns - 1) * gap) / columns;
                            return Wrap(
                              spacing: gap,
                              runSpacing: gap,
                              children: [
                                for (final post in communityPosts)
                                  SizedBox(
                                    width: cardWidth,
                                    child: _CommunityPostCard(
                                      post: post,
                                      saved: _savedPostIds.contains(post.id),
                                      onTap: () => _openCommunityPost(post),
                                      onToggleSaved: () =>
                                          _togglePostSaved(post),
                                      onMenu: () => _showCommunityPostMenu(post),
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                      if (_postsHaveMore && !_postsLoading)
                        Center(
                          child: TextButton.icon(
                            onPressed: () => _loadCommunityPosts(),
                            icon: const Icon(Icons.expand_more_rounded),
                            label: const Text('Load more creations'),
                          ),
                        ),
                      if (_postsLoading && _communityPosts.isNotEmpty)
                        const Padding(
                          padding: EdgeInsets.all(12),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: AppColors.sky,
                            ),
                          ),
                        ),
                    ],
                    const SizedBox(height: 25),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            showFeatured ? 'Explore ideas' : 'Matching ideas',
                            style: AppText.h2,
                          ),
                        ),
                        Text(
                          '${cards.length} ${cards.length == 1 ? 'idea' : 'ideas'}',
                          style: AppText.caption,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (!_bookmarksLoaded)
                      const Padding(
                        padding: EdgeInsets.all(36),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: AppColors.sky,
                            strokeWidth: 2,
                          ),
                        ),
                      )
                    else if (cards.isEmpty)
                      _EmptyIdeas(savedOnly: _savedOnly, onReset: _clearFilters)
                    else
                      LayoutBuilder(
                        builder: (context, gridConstraints) {
                          final available = gridConstraints.maxWidth;
                          final columns = available < 360
                              ? 1
                              : available < 650
                              ? 2
                              : available < 1000
                              ? 3
                              : 4;
                          const gap = 14.0;
                          final cardWidth =
                              (available - (columns - 1) * gap) / columns;
                          return Wrap(
                            spacing: gap,
                            runSpacing: gap,
                            children: [
                              for (var index = 0; index < cards.length; index++)
                                SizedBox(
                                  width: cardWidth,
                                  child: IdeaLabCard(
                                    idea: cards[index],
                                    saved: _savedIds.contains(cards[index].id),
                                    onTap: () => _openIdea(cards[index]),
                                    onToggleSaved: () =>
                                        _toggleSaved(cards[index]),
                                    imageHeight: index.isEven ? 142 : 174,
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    if (showFeatured) ...[
                      const SizedBox(height: 28),
                      GlassCard(
                        strong: true,
                        padding: const EdgeInsets.all(17),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.lightbulb_outline_rounded,
                              color: AppColors.sky,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'These are practice prompts, not client commissions. Bring your own references and make each idea your own.',
                                style: AppText.caption,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    onChanged: onChanged,
    textInputAction: TextInputAction.search,
    decoration: InputDecoration(
      hintText: 'Search ideas, effects, tutorials…',
      prefixIcon: const Icon(Icons.search_rounded),
      suffixIcon: controller.text.isEmpty
          ? null
          : IconButton(
              tooltip: 'Clear search',
              onPressed: onClear,
              icon: const Icon(Icons.close_rounded),
            ),
      filled: true,
      fillColor: AppColors.glassFillStrong,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: AppColors.glassBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: AppColors.glassBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: AppColors.sky),
      ),
    ),
  );
}

class _CategoryFilters extends StatelessWidget {
  const _CategoryFilters({required this.selected, required this.onSelected});

  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 43,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: IdeaLabRepository.categories.length,
      separatorBuilder: (context, index) => const SizedBox(width: 7),
      itemBuilder: (context, index) {
        final category = IdeaLabRepository.categories[index];
        return ChoiceChip(
          label: Text(category),
          selected: selected == category,
          onSelected: (_) => onSelected(category),
        );
      },
    ),
  );
}

class _FeaturedIdea extends StatelessWidget {
  const _FeaturedIdea({
    required this.idea,
    required this.saved,
    required this.saving,
    required this.onOpen,
    required this.onToggleSaved,
  });

  final IdeaLabIdea idea;
  final bool saved;
  final bool saving;
  final VoidCallback onOpen;
  final VoidCallback onToggleSaved;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxWidth < 640;
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onOpen,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.glassBorderStrong),
              boxShadow: [
                BoxShadow(
                  color: AppColors.blue.withValues(alpha: .16),
                  blurRadius: 24,
                  spreadRadius: -3,
                ),
              ],
            ),
            child: Stack(
              children: [
                Hero(
                  tag: 'idea-art-${idea.id}',
                  child: IdeaLabArtwork(
                    idea: idea,
                    height: compact ? 250 : 275,
                    borderRadius: 0,
                    showLabel: false,
                  ),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: compact
                            ? Alignment.bottomCenter
                            : Alignment.centerLeft,
                        end: compact
                            ? Alignment.topCenter
                            : Alignment.centerRight,
                        colors: [
                          AppColors.navyDeep.withValues(alpha: .96),
                          AppColors.navyDeep.withValues(alpha: .75),
                          Colors.transparent,
                        ],
                        stops: const [0, .48, 1],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: Material(
                    color: AppColors.navyDeep.withValues(alpha: .85),
                    shape: const CircleBorder(
                      side: BorderSide(color: AppColors.glassBorder),
                    ),
                    child: IconButton(
                      tooltip: saved ? 'Remove saved idea' : 'Save idea',
                      onPressed: saving ? null : onToggleSaved,
                      icon: Icon(
                        saved
                            ? Icons.bookmark_rounded
                            : Icons.bookmark_border_rounded,
                        color: AppColors.sky,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: compact ? 16 : 28,
                  right: compact ? 16 : 25,
                  bottom: compact ? 17 : 25,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('FEATURED IDEA', style: AppText.label),
                      const SizedBox(height: 5),
                      Text(
                        idea.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.h1.copyWith(fontSize: compact ? 21 : 29),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        idea.description,
                        maxLines: compact ? 2 : 3,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.body.copyWith(
                          color: AppColors.ink,
                          fontSize: compact ? 11 : 13,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 7,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _FeatureBadge(idea.category),
                          _FeatureBadge(idea.difficulty),
                          const Icon(
                            Icons.arrow_forward_rounded,
                            color: AppColors.sky,
                            size: 19,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _FeatureBadge extends StatelessWidget {
  const _FeatureBadge(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(maxWidth: 160),
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      color: AppColors.navyDeep.withValues(alpha: .76),
      borderRadius: BorderRadius.circular(99),
      border: Border.all(color: AppColors.glassBorder),
    ),
    child: Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AppText.caption.copyWith(fontSize: 9),
    ),
  );
}

class _EmptyIdeas extends StatelessWidget {
  const _EmptyIdeas({required this.savedOnly, required this.onReset});
  final bool savedOnly;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) => GlassCard(
    padding: const EdgeInsets.all(28),
    child: Column(
      children: [
        Icon(
          savedOnly ? Icons.bookmark_border_rounded : Icons.search_off,
          size: 38,
          color: AppColors.sky,
        ),
        const SizedBox(height: 10),
        Text(
          savedOnly ? 'No saved ideas yet' : 'No matching ideas',
          style: AppText.h3,
        ),
        const SizedBox(height: 5),
        Text(
          savedOnly
              ? 'Save an idea with the bookmark button and it will appear here.'
              : 'Try a different phrase or category, or reset the filters.',
          textAlign: TextAlign.center,
          style: AppText.caption,
        ),
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: onReset,
          icon: const Icon(Icons.filter_alt_off_outlined),
          label: const Text('Reset filters'),
        ),
      ],
    ),
  );
}

class _StoryBubble extends StatelessWidget {
  const _StoryBubble({
    required this.label,
    required this.isOwn,
    required this.onTap,
    this.story,
  });

  final String label;
  final bool isOwn;
  final VoidCallback onTap;
  final IdeaLabStory? story;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 76,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Column(
        children: [
          Container(
            width: 68,
            height: 68,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: story == null || !story!.seen
                  ? AppColors.brandGradient
                  : null,
              border: story?.seen == true
                  ? Border.all(color: AppColors.inkFaint, width: 2)
                  : null,
            ),
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.navy,
              ),
              child: story == null
                  ? const Icon(
                      Icons.add_rounded,
                      color: AppColors.sky,
                      size: 32,
                    )
                  : story!.mimeType.startsWith('video/')
                  ? const Icon(
                      Icons.play_circle_outline_rounded,
                      color: Colors.white,
                      size: 30,
                    )
                  : Image.network(
                      story!.url,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.broken_image_outlined),
                    ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.caption.copyWith(fontSize: 10),
          ),
        ],
      ),
    ),
  );
}

class _CommunityPostCard extends StatelessWidget {
  const _CommunityPostCard({
    required this.post,
    required this.saved,
    required this.onTap,
    required this.onToggleSaved,
    required this.onMenu,
  });

  final IdeaLabPost post;
  final bool saved;
  final VoidCallback onTap;
  final VoidCallback onToggleSaved;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.glassFill,
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(17),
      side: const BorderSide(color: AppColors.glassBorder),
    ),
    child: InkWell(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: post.media.isEmpty
                    ? const Center(child: Text('No preview available'))
                    : post.media.first.mimeType.startsWith('video/')
                    ? IdeaCommunityVideoPreview(
                        media: post.media.first,
                        viewCount: null,
                      )
                    : Image.network(
                        post.media.first.url,
                        fit: BoxFit.contain,
                        cacheWidth: 960,
                        loadingBuilder: (context, child, progress) =>
                            progress == null
                            ? child
                            : const Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                        errorBuilder: (_, __, ___) => const Center(
                          child: Icon(Icons.broken_image_outlined, size: 36),
                        ),
                      ),
              ),
              Positioned(
                top: 7,
                right: 7,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _CommunityPostIconButton(
                      tooltip: 'Post options',
                      icon: Icons.more_vert,
                      onPressed: onMenu,
                    ),
                    const SizedBox(width: 6),
                    _CommunityPostIconButton(
                      tooltip: saved ? 'Remove saved post' : 'Save post',
                      icon: saved
                          ? Icons.bookmark_rounded
                          : Icons.bookmark_border_rounded,
                      color: AppColors.sky,
                      onPressed: onToggleSaved,
                    ),
                  ],
                ),
              ),
              if (post.media.length > 1)
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.navyDeep.withValues(alpha: .85),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${post.media.length} images',
                      style: AppText.caption,
                    ),
                  ),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  post.caption,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.h3,
                ),
                const SizedBox(height: 7),
                Text('by ${post.creator}', style: AppText.caption),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 5,
                  children: [
                    _CommunityMetadataPill(post.category),
                    for (final tag in post.tags.take(3))
                      _CommunityMetadataPill('#$tag'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _CommunityPostIconButton extends StatelessWidget {
  const _CommunityPostIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.color = Colors.white,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  final Color color;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.navyDeep.withValues(alpha: .9),
    shape: const CircleBorder(side: BorderSide(color: AppColors.glassBorder)),
    child: IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints.tightFor(width: 38, height: 38),
      icon: Icon(icon, color: color, size: 19),
    ),
  );
}

class _PostMenuTile extends StatelessWidget {
  const _PostMenuTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: ListTile(
      leading: Icon(icon, color: isDestructive ? Colors.redAccent : AppColors.sky),
      title: Text(
        label,
        style: TextStyle(
          color: isDestructive ? Colors.redAccent : AppColors.ink,
          fontWeight: isDestructive ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      onTap: onTap,
    ),
  );
}

class _CommunityMetadataPill extends StatelessWidget {
  const _CommunityMetadataPill(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(maxWidth: 180),
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
    decoration: BoxDecoration(
      color: AppColors.blue.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(99),
      border: Border.all(color: AppColors.glassBorder),
    ),
    child: Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AppText.caption.copyWith(fontSize: 9),
    ),
  );
}
