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
// Release lint for plugin library modules is therefore switched off. Our own
// code is still covered by `flutter analyze --fatal-infos` and by the app
// module's lint; the artifact checks live in tool/verify_android_artifacts.py.
subprojects {
    plugins.withId("com.android.library") {
        extensions.configure<com.android.build.api.dsl.LibraryExtension> {
            lint.checkReleaseBuilds = false
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
