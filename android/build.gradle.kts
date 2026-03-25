allprojects {
    repositories {
        google()
        mavenCentral()
        maven { url = uri("https://github.com/arthenica/ffmpeg-kit/raw/main/prebuilt/bundle-android-aar/ffmpeg-kit-min") }
        maven { url = uri("https://raw.githubusercontent.com/arthenica/ffmpeg-kit/main/prebuilt/maven") }
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
