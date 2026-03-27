buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath("com.android.tools.build:gradle:8.11.1")
    }
}

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
// BUILD_STABILITY: Inject namespace and strip 'package' from manifest for flutter_login_yandex only (no Pub Cache edits).
subprojects {
    afterEvaluate {
        if (project.name == "flutter_login_yandex") {
            val android = project.extensions.findByType(com.android.build.gradle.LibraryExtension::class.java) ?: return@afterEvaluate
            if (android.namespace == null || android.namespace!!.isEmpty()) {
                android.namespace = "com.yandex.auth.flutter"
            }
            val srcManifest = project.file("src/main/AndroidManifest.xml")
            if (!srcManifest.exists()) return@afterEvaluate
            val outFile = project.layout.buildDirectory.file("stripped_manifest/AndroidManifest.xml").get().asFile
            val stripTask = project.tasks.register("stripPackageFromManifest") {
                inputs.file(srcManifest)
                outputs.file(outFile)
                doLast {
                    val text = srcManifest.readText()
                    val stripped = text.replace(Regex("""\s+package="[^"]*""""), " ")
                    outFile.parentFile.mkdirs()
                    outFile.writeText(stripped)
                }
            }
            android.sourceSets.getByName("main").manifest.srcFile(outFile)
            project.tasks.matching { it.name.startsWith("process") && it.name.contains("LibraryManifest") }.configureEach {
                dependsOn(stripTask.get())
            }
        }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
