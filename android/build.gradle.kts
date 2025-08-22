buildscript {
    repositories {
        google()
        jcenter()
    }
    dependencies {
       classpath("com.google.gms:google-services:4.4.3")
       
    }
}
extra.set("flutter", mapOf(
    "minSdkVersion" to 23,
    "targetSdkVersion" to 36,
    "compileSdkVersion" to 36,
    "ndkVersion" to "27.0.12077973",
    "versionCode" to 1,
    "versionName" to "1.0.0"
))
allprojects {
    repositories {
        google()
        mavenCentral()
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
