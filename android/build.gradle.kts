import org.gradle.api.artifacts.repositories.MavenArtifactRepository

allprojects {
    // Flutter integration_test uses dynamic AndroidX versions. Resolve just
    // these three selectors to our QA versions, including for offline builds.
    configurations.configureEach {
        resolutionStrategy.eachDependency {
            when ("${requested.group}:${requested.name}:${requested.version}") {
                "androidx.test:runner:1.2+" -> useVersion("1.3.0")
                "androidx.test:rules:1.2+" -> useVersion("1.2.0")
                "androidx.test.espresso:espresso-core:3.3+" -> useVersion("3.3.0")
            }
        }
    }
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
