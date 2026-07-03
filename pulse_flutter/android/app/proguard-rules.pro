-dontwarn javax.annotation.**
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Play Core / SplitCompat — keep classes referenced by Flutter deferred components
-keep class com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.core.**

# Flutter deferred components and Play Store integration
-keep class io.flutter.embedding.engine.deferredcomponents.** { *; }
-dontwarn io.flutter.embedding.engine.deferredcomponents.**
