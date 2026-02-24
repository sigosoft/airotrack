allprojects {
    repositories {
        google()
        mavenCentral()
        // Mapbox Maps SDK (required for Map Matching + drawing on Mapbox map)
        maven {
            url = uri("https://api.mapbox.com/downloads/v2/releases/maven")
        }
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

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
