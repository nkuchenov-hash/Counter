import com.android.build.gradle.BaseExtension
import org.jetbrains.kotlin.gradle.dsl.JvmTarget
import org.jetbrains.kotlin.gradle.tasks.KotlinCompile

buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath("com.android.tools.build:gradle:8.11.1")
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:2.2.20")
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

// Align Java + Kotlin bytecode for every Android subproject (e.g. :wear defaults to Java 8; Kotlin may target 21 — AGP rejects the mix).
val sharedJvmVersion = JavaVersion.VERSION_17
subprojects {
    afterEvaluate {
        project.extensions.findByType(BaseExtension::class.java)?.compileOptions?.apply {
            sourceCompatibility = sharedJvmVersion
            targetCompatibility = sharedJvmVersion
        }
        project.tasks.withType(KotlinCompile::class.java).configureEach {
            compilerOptions.jvmTarget.set(JvmTarget.JVM_17)
        }
    }
}

// AGP 8+: Android library modules must declare `namespace`. Legacy Flutter plugins (e.g. :wear) omit it — derive from
// `package=` in src/main/AndroidManifest.xml or from Gradle `group`. Skip :flutter_login_yandex (fixed below).
subprojects {
    afterEvaluate {
        val androidLib =
            project.extensions.findByType(com.android.build.gradle.LibraryExtension::class.java)
                ?: return@afterEvaluate
        val existingNs = androidLib.namespace
        if (existingNs != null && existingNs.isNotBlank()) return@afterEvaluate
        if (project.name == "flutter_login_yandex") return@afterEvaluate

        val srcManifest = project.file("src/main/AndroidManifest.xml")
        if (srcManifest.exists()) {
            val pkg =
                Regex("""package\s*=\s*"([^"]+)""")
                    .find(srcManifest.readText())
                    ?.groupValues
                    ?.getOrNull(1)
                    ?.trim().orEmpty()
            if (pkg.isNotEmpty()) {
                androidLib.namespace = pkg
                return@afterEvaluate
            }
        }
        val g = project.group.toString().trim()
        if (g.isNotEmpty() && g != "unspecified") {
            androidLib.namespace = g
        }
    }
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
