allprojects {
    repositories {
        google()
        mavenCentral()
        maven { url = uri(rootProject.file("../app/build/host/outputs/repo")) }
        maven { url = uri("https://storage.googleapis.com/download.flutter.io") }
        maven { url = uri("https://jitpack.io") }
    }
}

val newBuildDir: Directory = rootProject.layout.projectDirectory.dir("../app/build/android-host")
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
