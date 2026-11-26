allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

// AGP 9.3.1's release lint crashes while analysing the camera plugin
// (CommentDetector calls java.util.List.removeLast(), a JDK 21 API that the
// JDK 17 Gradle runs on does not provide):
//
//   Execution failed for task ':camera_android_camerax:lintVitalAnalyzeRelease'
//   NoSuchMethodError: 'java.lang.Object java.util.List.removeLast()'
//
// `lint.checkReleaseBuilds = false` does not stop AGP 9 from creating the
// lintVital task, so the tasks themselves are disabled here. `subprojects {}`
// covers `:app` as well, so release lint now runs nowhere — neither for the
// plugins nor for the application. `flutter analyze --fatal-infos` checks Dart
// only and is not a replacement for Android lint.
//
// TODO: re-enable lintVital once either an AGP release fixes the
// CommentDetector crash on JDK 17, or the Android build moves to JDK 21.
subprojects {
    tasks.matching { it.name.startsWith("lintVital") }.configureEach {
        enabled = false
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
