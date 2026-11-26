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
// library module's lintVital task, so the tasks themselves are disabled for
// plugin subprojects. `:app` is deliberately excluded: its lint analyses only
// our own Kotlin/Java sources (the crash came from a plugin's Java file), so
// the application keeps its Android lint. If `:app:lintVital*` starts crashing
// on the same bug, extend this filter to `:app` and record it here.
//
// TODO: re-enable lintVital for plugin modules once either an AGP release
// fixes the CommentDetector crash on JDK 17, or the build moves to JDK 21.
subprojects {
    if (path != ":app") {
        tasks.matching { it.name.startsWith("lintVital") }.configureEach {
            enabled = false
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
