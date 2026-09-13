-dontwarn javax.annotation.**
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Play Core / SplitCompat — keep classes referenced by Flutter deferred components
-keep class com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.core.**

# Flutter deferred components and Play Store integration
-keep class io.flutter.embedding.engine.deferredcomponents.** { *; }
-dontwarn io.flutter.embedding.engine.deferredcomponents.**

# photo_manager
-keep class top.kikt.photomanager.** { *; }
-dontwarn top.kikt.photomanager.**

# Glide (used by photo_manager)
-keep public class * implements com.bumptech.glide.module.GlideModule
-keep class com.bumptech.glide.** { *; }
-dontwarn com.bumptech.glide.**

# file_picker
-keep class com.mr.flutter.plugin.filepicker.** { *; }
-dontwarn com.mr.flutter.plugin.filepicker.**

# flutter_image_compress
-keep class com.flutter_image_compress.** { *; }
-dontwarn com.flutter_image_compress.**
