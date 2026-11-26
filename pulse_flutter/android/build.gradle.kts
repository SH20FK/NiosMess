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
// library module's lintVital task, so the tasks themselves are disabled. Our
// own code is still covered by `flutter analyze --fatal-infos`, the app
// module's lint, and tool/verify_android_artifacts.py checks the artifacts.
subprojects {
    tasks.matching { it.name.startsWith("lintVital") }.configureEach {
        enabled = false
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
