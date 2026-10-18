-dontwarn javax.annotation.**
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# shared_preferences_android 2.5 uses JNI for both the legacy and DataStore
# registrars. Keeping their names alone does not preserve Kotlin parameter
# types: a renamed Continuation changes getAll's literal JNI descriptor.
# https://developer.android.com/topic/performance/app-optimization/keep-rule-examples
-keep,includedescriptorclasses class io.flutter.plugins.sharedpreferences.** { *; }

# package:jni 1.1's lib/src/kotlin.dart also looks up these Kotlin runtime
# symbols by name. Keep only that coroutine bridge, not all Kotlin/DataStore.
-keep,includedescriptorclasses interface kotlin.coroutines.Continuation { *; }
-keep class kotlin.coroutines.intrinsics.CoroutineSingletons { *; }
-keep class kotlin.coroutines.intrinsics.IntrinsicsKt { *; }
-keep class kotlin.coroutines.intrinsics.IntrinsicsKt__IntrinsicsKt {
    public static java.lang.Object getCOROUTINE_SUSPENDED();
}
-keep class kotlin.Unit {
    public static final kotlin.Unit INSTANCE;
}
-keep class kotlin.Result {
    java.lang.Object value;
}
-keep class kotlin.Result$Failure {
    public <init>(java.lang.Throwable);
    java.lang.Throwable exception;
}

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
