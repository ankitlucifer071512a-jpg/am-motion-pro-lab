# AM Motion Lab app - Phase 0-2 setup

1. Copy `lib/`, `assets/`, `test/` and `pubspec.yaml` into your Flutter project (my_first_app). Replace old lib/main.dart and test/widget_test.dart.
2. Copy website images:
   - image_web/full-logo.png, image_web/icon_logo.png  ->  assets/brand/
   - design/video editing.png      -> assets/images/courses/video-editing.png
   - design/2d animation.png       -> assets/images/courses/2d-animation.png
   - design/graphic design.png     -> assets/images/courses/graphic-designing.png
   - design/motion graphic.png     -> assets/images/courses/motion-graphics.png
   - (3d-animation.png: not on website; app shows a branded placeholder until you add one)
3. android/app/src/main/AndroidManifest.xml: add inside <manifest> (above <application>):
   <uses-permission android:name="android.permission.INTERNET"/>
4. Terminal: flutter pub get   then   flutter run
