plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

kotlin {
    jvmToolchain(17)
}

val lifeOsKeystorePath = System.getenv("LIFE_OS_KEYSTORE_PATH")
val lifeOsKeystorePassword = System.getenv("ANDROID_KEYSTORE_PASSWORD")
val lifeOsKeyAlias = System.getenv("ANDROID_KEY_ALIAS")
val lifeOsKeyPassword = System.getenv("ANDROID_KEY_PASSWORD")
val hasLifeOsReleaseSigning =
    !lifeOsKeystorePath.isNullOrBlank() &&
    !lifeOsKeystorePassword.isNullOrBlank() &&
    !lifeOsKeyAlias.isNullOrBlank() &&
    !lifeOsKeyPassword.isNullOrBlank() &&
    file(lifeOsKeystorePath).exists()

// Production releases must never silently fall back to a fresh debug
// certificate: Android then rejects installation over the existing app.
// Unsigned-by-production release compilation is permitted ONLY in PR CI;
// those artifacts must never be distributed as installable updates.
val allowDebugSignedReleaseCheck =
    System.getenv("LIFE_OS_ALLOW_DEBUG_RELEASE_FOR_CI") == "true"
val releaseTaskRequested = gradle.startParameter.taskNames.any {
    it.contains("Release", ignoreCase = true)
}
if (releaseTaskRequested && !hasLifeOsReleaseSigning && !allowDebugSignedReleaseCheck) {
    throw org.gradle.api.GradleException(
        "LIFE OS permanent Android signing v2 is unavailable. Refusing to build a debug-signed release APK. " +
        "Restore the encrypted signing identity before publishing."
    )
}


android {
    signingConfigs {
        if (hasLifeOsReleaseSigning) {
            create("lifeOsRelease") {
                storeFile = file(lifeOsKeystorePath!!)
                storePassword = lifeOsKeystorePassword
                keyAlias = lifeOsKeyAlias
                keyPassword = lifeOsKeyPassword
            }
        }
    }

    namespace = "com.example.counter"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // Must match Google Cloud Console → Android OAuth client (package name + SHA-1).
        applicationId = "com.example.counter"
        // Health integration requires API 26; Wear OS 3+ devices remain compatible.
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
        // BUILD_STABILITY (§10): Satisfy manifest placeholders required by flutter_login_yandex. Replace with your Yandex OAuth client ID from Yandex Developer Console.
        manifestPlaceholders["YANDEX_CLIENT_ID"] = "your_yandex_client_id_here"
    }

    buildTypes {
        release {
            // The canonical main CI restores permanent signing identity v2.
            // A debug fallback is allowed only for explicitly flagged PR compilation
            // checks and their APKs are never uploaded or published.
            signingConfig = if (hasLifeOsReleaseSigning) {
                signingConfigs.getByName("lifeOsRelease")
            } else {
                signingConfigs.getByName("debug")
            }
            isMinifyEnabled = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    implementation("com.google.android.gms:play-services-wearable:18.1.0")
    implementation("com.google.android.gms:play-services-location:21.3.0")
    implementation("androidx.work:work-runtime-ktx:2.9.1")
}
