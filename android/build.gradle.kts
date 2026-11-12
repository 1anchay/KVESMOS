import org.gradle.api.artifacts.repositories.MavenArtifactRepository

allprojects {
    repositories {
        google()
        mavenCentral()
        // Flutter's Maven host contains io.flutter artifacts, not AndroidX.
        // Avoid querying this host for dynamic androidx.test versions:
        // it may be unreachable while Google's Android Maven is accessible.
        configureEach {
            if (this is MavenArtifactRepository &&
                url.toString().contains("download.flutter.io")) {
                content {
                    includeGroup("io.flutter")
                }
            }
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
