import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import 'idea_local_video_controller_stub.dart'
    if (dart.library.io) 'idea_local_video_controller_io.dart'
    if (dart.library.html) 'idea_local_video_controller_web.dart'
    as platform;

VideoPlayerController localVideoController(XFile file) =>
    platform.localVideoController(file);
