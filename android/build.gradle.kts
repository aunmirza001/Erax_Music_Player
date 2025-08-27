// Top-level build file for the whole project

buildscript {
    repositories {
        google()        // 🔑 Required for Firebase + Google services
        mavenCentral()
    }
    dependencies {
        // Android Gradle plugin
        classpath("com.android.tools.build:gradle:8.1.1")

        // 🔑 Google Services plugin (for Firebase)
        classpath("com.google.gms:google-services:4.4.1")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// ✅ Flutter build output directories
val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

// Make sure `app` is evaluated
subprojects {
    project.evaluationDependsOn(":app")
}

// Clean task
tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
